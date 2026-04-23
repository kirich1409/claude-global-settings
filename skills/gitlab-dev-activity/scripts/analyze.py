#!/usr/bin/env python3
"""
GitLab Developer Activity Analyzer
Usage: python3 analyze.py --username USERNAME [--compare USERNAME2] [--days 90] [--json]
"""

import argparse
import json
import subprocess
import sys
from datetime import date, timedelta, datetime
from collections import Counter
from urllib.parse import quote


# ── helpers ──────────────────────────────────────────────────────────────────

def run(cmd, check=False):
    r = subprocess.run(cmd, shell=True, capture_output=True, text=True)
    if check and r.returncode != 0:
        print(f"[WARN] {cmd[:80]}: {r.stderr[:120]}", file=sys.stderr)
    return r.stdout.strip()


def glab(path, paginate=False):
    if not paginate:
        out = run(f"glab api '{path}'")
        try:
            data = json.loads(out)
            if isinstance(data, dict) and 'message' in data:
                print(f"[WARN] API error for {path[:60]}: {data['message']}", file=sys.stderr)
                return []
            return data
        except Exception:
            return []
    results = []
    page = 1
    while True:
        sep = '&' if '?' in path else '?'
        out = run(f"glab api '{path}{sep}per_page=100&page={page}'")
        try:
            data = json.loads(out)
        except Exception:
            break
        if not data:
            break
        results.extend(data)
        if len(data) < 100:
            break
        page += 1
    return results


# ── project detection ─────────────────────────────────────────────────────────

def detect_project():
    remote = run("git remote get-url origin")
    if not remote:
        return None, None
    remote = remote.rstrip('/').removesuffix('.git')
    if remote.startswith(('https://', 'http://')):
        parts = remote.split('/', 3)
        path = parts[3] if len(parts) > 3 else ''
    elif '@' in remote:
        path = remote.split(':', 1)[1]
    else:
        path = '/'.join(remote.split('/')[1:])
    return path, quote(path, safe='')


# ── data collection ───────────────────────────────────────────────────────────

def get_user(username):
    data = glab(f'/users?username={username}')
    if not data:
        sys.exit(f"[ERROR] User '{username}' not found")
    return data[0]['id'], data[0]['name']


def get_events(uid, since):
    """Fetch all events once; callers filter by action_name."""
    return glab(f'/users/{uid}/events?after={since}', paginate=True)


def get_mr_review_activity(encoded, reviewer_mrs, username):
    """Get review activity from MR API — no events retention limit.

    Replaces both split_events() (reviewer part) and get_reviewer_discussion_quality().
    Processes ALL reviewer_mrs for accurate ghost rate and approval stats.
    Uses MR approvals endpoint + notes for approval dates, discussions for comments.
    """
    approved_map = {}   # iid → YYYY-MM-DD
    commented_iids = set()
    with_inline = 0
    total_unresolved = 0
    mrs_with_comments = 0

    sorted_mrs = sorted(reviewer_mrs, key=lambda m: m['iid'], reverse=True)

    for mr in sorted_mrs:
        iid = mr['iid']

        # Approvals via dedicated endpoint (accurate, no retention limit)
        approvals = glab(f'/projects/{encoded}/merge_requests/{iid}/approvals')
        user_approved = False
        if isinstance(approvals, dict):
            for entry in approvals.get('approved_by', []):
                if entry.get('user', {}).get('username') == username:
                    user_approved = True
                    approved_map[iid] = mr.get('updated_at', '')[:10]
                    break

        # Discussions: comments + inline + unresolved
        discussions = glab(f'/projects/{encoded}/merge_requests/{iid}/discussions?per_page=100')
        has_comment = False
        for disc in discussions:
            for note in disc.get('notes', []):
                if note.get('system'):
                    # Grab accurate approval date from system note
                    if (user_approved and iid in approved_map and
                            note.get('author', {}).get('username') == username and
                            note.get('body', '') == 'approved this merge request'):
                        approved_map[iid] = note['created_at'][:10]
                    continue
                if note.get('author', {}).get('username') != username:
                    continue
                has_comment = True
                commented_iids.add(iid)
                if note.get('position'):
                    with_inline += 1
        if has_comment:
            mrs_with_comments += 1
        for disc in discussions:
            notes = disc.get('notes', [])
            if notes and notes[0].get('resolvable') and not notes[0].get('resolved'):
                total_unresolved += 1

    return {
        'approved_map': approved_map,
        'commented_iids': commented_iids,
        'with_comments': mrs_with_comments,
        'with_inline': with_inline,
        'unresolved_threads': total_unresolved,
        'sample_size': len(sorted_mrs),
    }


def get_authored_mr_feedback(encoded, author_mrs, username, sample=10):
    """External review quality on the user's authored MRs via Discussions API.

    Returns feedback notes count, pickup times, and rework indicators.
    - Pickup Time: time from MR open to first non-author non-system comment
    - Rework commits: commits added after first review comment (proxy for quality)
    """
    recent = sorted(author_mrs, key=lambda m: m['iid'], reverse=True)[:sample]
    total_notes = 0
    pickup_hours = []
    for mr in recent:
        created = datetime.fromisoformat(mr['created_at'].replace('Z', '+00:00'))
        discussions = glab(f'/projects/{encoded}/merge_requests/{mr["iid"]}/discussions?per_page=100')
        first_review_ts = None
        mr_notes = 0
        for disc in discussions:
            for note in disc.get('notes', []):
                if note.get('system'):
                    continue
                if note.get('author', {}).get('username') == username:
                    continue
                mr_notes += 1
                ts = note.get('created_at', '')
                if ts and (first_review_ts is None or ts < first_review_ts):
                    first_review_ts = ts
        total_notes += mr_notes
        if first_review_ts:
            first_dt = datetime.fromisoformat(first_review_ts.replace('Z', '+00:00'))
            pickup_h = (first_dt - created).total_seconds() / 3600
            if pickup_h >= 0:
                pickup_hours.append(pickup_h)
    count = len(recent)
    avg_notes = round(total_notes / count, 1) if count else 0.0
    avg_pickup = round(sum(pickup_hours) / len(pickup_hours), 1) if pickup_hours else None
    return total_notes, count, avg_notes, avg_pickup


def get_authored_mr_extended_stats(author_mrs, today_str, encoded=None):
    """Extract free stats from already-fetched author MRs (no extra API calls).

    - PR Size: avg and max lines changed (changes_count field)
    - Merges without review: merged with approved_by == []
    - Avg commits per MR
    - Stale open MRs: open but no activity for >7 days
    """
    # If changes_count missing from list (some GitLab versions), fetch details for sample
    sample_mrs = sorted(author_mrs, key=lambda m: m['iid'], reverse=True)[:10]
    if encoded and sample_mrs and all(m.get('changes_count') is None for m in sample_mrs):
        detail_map = {}
        for m in sample_mrs:
            detail = glab(f'/projects/{encoded}/merge_requests/{m["iid"]}')
            if detail and isinstance(detail, dict):
                detail_map[m['iid']] = detail.get('changes_count')
        for m in author_mrs:
            if m['iid'] in detail_map and detail_map[m['iid']] is not None:
                m['changes_count'] = detail_map[m['iid']]

    sizes = []
    commits_per_mr = []
    merges_without_review = 0
    stale_open = 0
    today = datetime.fromisoformat(today_str)
    for m in author_mrs:
        # PR size
        size = m.get('changes_count') or 0
        try:
            size = int(size)
        except (ValueError, TypeError):
            size = 0
        if size > 0:
            sizes.append(size)
        # commits per MR
        cc = m.get('commits_count') or 0
        if cc > 0:
            commits_per_mr.append(cc)
        # merge without review
        if m.get('state') == 'merged' and not m.get('approved_by'):
            merges_without_review += 1
        # stale open
        if m.get('state') == 'opened':
            updated = m.get('updated_at', '')
            if updated:
                try:
                    upd_dt = datetime.fromisoformat(updated.replace('Z', '+00:00')).replace(tzinfo=None)
                    if (today - upd_dt).days > 7:
                        stale_open += 1
                except Exception:
                    pass
    def pct(lst, p):
        if not lst:
            return 0
        s = sorted(lst)
        idx = int(len(s) * p / 100)
        return s[min(idx, len(s) - 1)]

    return {
        'avg_pr_size': round(sum(sizes) / len(sizes)) if sizes else 0,
        'p50_pr_size': pct(sizes, 50),
        'p75_pr_size': pct(sizes, 75),
        'p90_pr_size': pct(sizes, 90),
        'max_pr_size': max(sizes) if sizes else 0,
        'merges_without_review': merges_without_review,
        'avg_commits_per_mr': round(sum(commits_per_mr) / len(commits_per_mr), 1) if commits_per_mr else 0.0,
        'stale_open': stale_open,
    }


def get_cross_project_activity(all_events, current_encoded):
    """Group events by project_id and resolve project names.

    Returns a list of projects sorted by event count (descending),
    with the current project flagged. Uses only already-fetched events —
    no extra paginated calls. Only a small batch of project-name lookups needed.
    """
    from collections import defaultdict
    by_project: dict = defaultdict(list)
    for e in all_events:
        pid = e.get('project_id')
        if pid:
            by_project[pid].append(e)

    if not by_project:
        return []

    # Resolve names for top-10 most active projects
    top_pids = sorted(by_project, key=lambda p: -len(by_project[p]))[:10]
    result = []
    for pid in top_pids:
        info = glab(f'/projects/{pid}')
        if not info or isinstance(info, list):
            continue
        events = by_project[pid]
        actions = Counter(e.get('action_name', '?') for e in events)
        path = info.get('path_with_namespace', str(pid))
        result.append({
            'id': pid,
            'name': info.get('name_with_namespace', str(pid)),
            'path': path,
            'url': info.get('web_url', ''),
            'total': len(events),
            'approvals': actions.get('approved', 0),
            'pushes': actions.get('pushed to', 0) + actions.get('pushed new', 0),
            'comments': actions.get('commented on', 0),
            'merges': actions.get('accepted', 0),
            'is_current': current_encoded in quote(path, safe=''),
        })

    result.sort(key=lambda p: -p['total'])
    return result


def get_git_stats(emails, since, period_days):
    if not emails:
        return {'commits': 0, 'added': 0, 'deleted': 0, 'file_changes': 0,
                'monthly': {}, 'by_weekday': {}, 'by_hour': {},
                'off_hours': 0, 'weekend': 0, 'avg_per_month': 0.0}

    # Shell-safe: escape single quotes in each email
    def safe(e):
        return e.replace("'", r"'\''")

    author_args = ' '.join(f"--author='{safe(e)}'" for e in emails)

    commits = int(run(f"git log --since='{since}' {author_args} --oneline 2>/dev/null | wc -l") or 0)

    numstat = run(f"git log --since='{since}' {author_args} --pretty=tformat: --numstat 2>/dev/null")
    added = deleted = file_changes = 0
    for line in numstat.splitlines():
        p = line.split('\t')
        if len(p) == 3:
            try:
                added += int(p[0]); deleted += int(p[1]); file_changes += 1
            except ValueError:
                pass

    raw = run(f"git log --since='{since}' {author_args} --format='%ad' --date=format:'%Y-%m' 2>/dev/null | sort | uniq -c")
    monthly = {}
    for line in raw.splitlines():
        p = line.strip().split()
        if len(p) == 2:
            monthly[p[1]] = int(p[0])

    # Work-hour analysis using developer's local clock (git stores timezone offset)
    ts_raw = run(f"git log --since='{since}' {author_args} --format='%aI' 2>/dev/null")
    by_weekday: Counter = Counter()
    by_hour: Counter = Counter()
    off_hours = 0
    weekend = 0
    for ts in ts_raw.splitlines():
        ts = ts.strip()
        if not ts:
            continue
        try:
            # fromisoformat preserves original timezone offset — use local hour/weekday
            dt = datetime.fromisoformat(ts)
            wd = dt.weekday()   # 0=Mon … 6=Sun
            h = dt.hour         # hour in developer's local time
            by_weekday[wd] += 1
            by_hour[h] += 1
            if wd >= 5:
                weekend += 1
            elif h < 9 or h >= 18:
                off_hours += 1
        except Exception:
            pass

    avg_per_month = round(commits / (period_days / 30), 1) if period_days else 0.0

    return {
        'commits': commits, 'added': added, 'deleted': deleted, 'file_changes': file_changes,
        'monthly': monthly,
        'by_weekday': {str(k): v for k, v in sorted(by_weekday.items())},
        'by_hour': {str(k): v for k, v in sorted(by_hour.items())},
        'off_hours': off_hours,
        'weekend': weekend,
        'avg_per_month': avg_per_month,
    }


AI_PATTERNS = {
    'claude':  r'(?i)(co-authored-by.*claude|co-authored-by.*anthropic|generated with.*claude|claude\s+code)',
    'copilot': r'(?i)(co-authored-by.*copilot|github\s+copilot)',
    'cursor':  r'(?i)(cursor\s+ai|generated\s+by\s+cursor)',
    'other':   r'(?i)(co-authored-by.*(gpt|openai|gemini|ai\b))',
}


def get_ai_commit_stats(emails, since):
    """Count commits where AI tools are credited as co-authors or mentioned in body."""
    import re
    if not emails:
        return {'total': 0, 'by_tool': {}, 'pct': 0.0, 'sample': []}

    def safe(e):
        return e.replace("'", r"'\''")

    author_args = ' '.join(f"--author='{safe(e)}'" for e in emails)
    # Fetch full commit message (subject + body) for each commit hash
    raw = run(
        f"git log --since='{since}' {author_args} --format='==COMMIT==%H%n%B' 2>/dev/null"
    )

    by_tool: Counter = Counter()
    ai_hashes: set = set()
    sample: list = []

    current_hash = None
    current_body: list = []

    def flush(h, body):
        nonlocal by_tool, ai_hashes, sample
        if not h:
            return
        text = '\n'.join(body)
        matched = []
        for tool, pattern in AI_PATTERNS.items():
            if re.search(pattern, text):
                by_tool[tool] += 1
                matched.append(tool)
        if matched:
            ai_hashes.add(h)
            if len(sample) < 5:
                # grab first line as subject
                subject = next((l for l in body if l.strip()), h[:8])
                sample.append({'hash': h[:8], 'subject': subject[:72], 'tools': matched})

    for line in raw.splitlines():
        if line.startswith('==COMMIT=='):
            flush(current_hash, current_body)
            current_hash = line[len('==COMMIT=='):]
            current_body = []
        else:
            current_body.append(line)
    flush(current_hash, current_body)

    total_ai = len(ai_hashes)
    total_commits_raw = run(f"git log --since='{since}' {author_args} --oneline 2>/dev/null | wc -l")
    total = int(total_commits_raw.strip() or 0)
    pct = round(total_ai / total * 100, 1) if total else 0.0

    return {'total': total_ai, 'by_tool': dict(by_tool), 'pct': pct, 'sample': sample}


def get_ai_mr_hints(author_mrs):
    """Check MR descriptions for AI-tool mentions."""
    import re
    hits = []
    for m in author_mrs:
        desc = (m.get('description') or '') + ' ' + (m.get('title') or '')
        matched = []
        for tool, pattern in AI_PATTERNS.items():
            if re.search(pattern, desc):
                matched.append(tool)
        if matched:
            hits.append({'iid': m['iid'], 'title': m['title'][:60], 'tools': matched})
    return hits


def calc_mr_lifetime(mrs):
    deltas = []
    for m in mrs:
        if m.get('state') == 'merged' and m.get('merged_at'):
            try:
                c = datetime.fromisoformat(m['created_at'].replace('Z', '+00:00'))
                mg = datetime.fromisoformat(m['merged_at'].replace('Z', '+00:00'))
                deltas.append((mg - c).total_seconds() / 3600)
            except Exception:
                pass
    if not deltas:
        return None, None
    s = sorted(deltas)
    return round(sum(s) / len(s), 1), round(s[len(s) // 2], 1)


def calc_time_to_approve(approved_map, encoded):
    sample = list(approved_map.items())[:20]
    if not sample:
        return None, None, None
    iid_str = '&iids[]='.join(str(i) for i, _ in sample)
    mrs = glab(f'/projects/{encoded}/merge_requests?iids[]={iid_str}&per_page=100')
    created = {m['iid']: m['created_at'][:10] for m in mrs}
    deltas = []
    for iid, appr_date in sample:
        if iid in created:
            c = date.fromisoformat(created[iid])
            a = date.fromisoformat(appr_date)
            deltas.append((a - c).days)
    if not deltas:
        return None, None, None
    s = sorted(deltas)
    return round(sum(s) / len(s), 1), s[len(s) // 2], max(s)


def _all_git_authors(since):
    """Return all (email, author_name) pairs from git log."""
    raw = run(f"git log --since='{since}' --format='%ae %an' 2>/dev/null | sort -u")
    result = []
    for line in raw.splitlines():
        parts = line.split(' ', 1)
        if len(parts) == 2 and '@' in parts[0]:
            result.append((parts[0].strip(), parts[1].strip()))
    return result


def find_git_email(username, name, since, explicit=None):
    """Find git emails for a user.

    Returns a dict:
      {
        'emails': [...],          # emails to use for git stats
        'matched': [(email, name), ...],  # auto-matched entries
        'candidates': [(email, name), ...],  # all git authors (for manual picking)
        'source': 'explicit' | 'auto' | 'none'
      }
    """
    all_authors = _all_git_authors(since)
    author_map = {e: n for e, n in all_authors}

    if explicit:
        matched = [(e, author_map.get(e, '?')) for e in explicit]
        return {'emails': explicit, 'matched': matched, 'candidates': all_authors, 'source': 'explicit'}

    found_emails: set = set()

    def search(pattern: str) -> None:
        safe = pattern.replace("'", r"'\''")
        out = run(f"git log --since='{since}' --format='%ae %an' 2>/dev/null | sort -u | grep -i '{safe}'")
        for line in out.splitlines():
            email = line.split(' ', 1)[0].strip()
            if email and '@' in email:
                found_emails.add(email)

    search(username.replace('_', '.').split('@')[0])
    if name:
        search(name)
    if not found_emails and name:
        parts = name.split()
        last = parts[-1] if len(parts) > 1 else ''
        if len(last) > 4:
            search(last)

    matched = [(e, author_map.get(e, '?')) for e in found_emails]
    source = 'auto' if found_emails else 'none'
    return {'emails': list(found_emails), 'matched': matched, 'candidates': all_authors, 'source': source}


def confirm_git_emails(username, name, result, no_confirm=False):
    """Interactive confirmation of git email mapping.

    Shows matched emails + git author names, asks user to confirm or correct.
    Returns final list of emails to use.

    Skipped (returns immediately) when:
    - source == 'explicit': user already specified --git-email
    - no_confirm == True: --no-confirm flag
    - not a TTY: non-interactive mode (CI, pipe)
    """
    import sys, os
    if result['source'] == 'explicit' or no_confirm or not sys.stderr.isatty():
        return result['emails']

    print(f"\n{'─'*60}", file=sys.stderr)
    print(f"Git авторы для @{username} ({name}):", file=sys.stderr)

    if result['matched']:
        print(f"  Найдено автоматически:", file=sys.stderr)
        for i, (email, aname) in enumerate(result['matched'], 1):
            print(f"  {i}. {email}  ({aname})", file=sys.stderr)
    else:
        print(f"  Автоматически не найдено.", file=sys.stderr)

    # Show nearby candidates (fuzzy: share any word with username or name)
    keywords = set(username.replace('_', '.').lower().split('.'))
    if name:
        keywords.update(p.lower() for p in name.split() if len(p) > 3)
    nearby = [
        (e, n) for e, n in result['candidates']
        if any(k in e.lower() or k in n.lower() for k in keywords)
        and e not in {m[0] for m in result['matched']}
    ][:5]
    if nearby:
        print(f"  Похожие кандидаты:", file=sys.stderr)
        for e, n in nearby:
            print(f"  • {e}  ({n})", file=sys.stderr)

    if result['matched']:
        print(f"\n  [Enter] использовать найденное  |  [e] ввести email вручную  |  [s] пропустить git stats",
              file=sys.stderr)
    else:
        print(f"\n  [e] ввести email вручную  |  [Enter] пропустить git stats", file=sys.stderr)

    try:
        choice = input('  > ').strip().lower()
    except (EOFError, KeyboardInterrupt):
        print('', file=sys.stderr)
        return result['emails']

    if choice == 'e':
        print(f"\n  Все git авторы в репо:", file=sys.stderr)
        for i, (e, n) in enumerate(result['candidates'][:20], 1):
            print(f"  {i:2}. {e}  ({n})", file=sys.stderr)
        try:
            raw = input('  Введи emails через запятую: ').strip()
        except (EOFError, KeyboardInterrupt):
            return result['emails']
        emails = [x.strip() for x in raw.split(',') if x.strip()]
        print(f"  Использую: {', '.join(emails)}", file=sys.stderr)
        return emails
    elif choice == 's':
        return []
    else:
        return result['emails']


def detect_inactive_months(events_by_month, git_monthly, since_str, today_str):
    """Find calendar months with zero GitLab events AND zero git commits."""
    since_d = date.fromisoformat(since_str)
    today_d = date.fromisoformat(today_str)
    active = set(events_by_month.keys()) | set(git_monthly.keys())
    inactive = []
    d = since_d.replace(day=1)
    while d <= today_d:
        ym = d.strftime('%Y-%m')
        if ym not in active:
            inactive.append(ym)
        # advance to first day of next month
        if d.month == 12:
            d = d.replace(year=d.year + 1, month=1)
        else:
            d = d.replace(month=d.month + 1)
    return inactive


def get_dora_metrics(encoded, since):
    """Fetch DORA metrics (requires GitLab Ultimate). Graceful fallback on 403/404.

    Returns dict with available metrics, or empty dict if not accessible.
    """
    result = {}
    for metric in ('lead_time_for_changes', 'deployment_frequency'):
        out = run(f"glab api '/projects/{encoded}/dora/metrics?metric={metric}&start_date={since}&interval=all'")
        try:
            data = json.loads(out)
            if isinstance(data, list) and data:
                # API returns [{"date": ..., "value": N}] for interval=all → single entry
                val = data[0].get('value')
                if val is not None:
                    result[metric] = val
            elif isinstance(data, dict) and 'message' in data:
                # 403 Forbidden or similar — not available on this plan
                print(f"[INFO] DORA {metric}: {data['message']}", file=sys.stderr)
        except Exception:
            pass
    return result


# ── main collector ────────────────────────────────────────────────────────────

def collect(username, encoded, since, today_str, period_days, explicit_emails=None):
    print(f"[+] @{username} ...", file=sys.stderr)
    uid, name = get_user(username)

    # Fetch events for general activity counts (pushes, merges, etc.)
    # Note: events API retention is ~30 days on this server — not used for review data
    all_events = get_events(uid, since)
    action_counts = Counter(e.get('action_name', '?') for e in all_events)
    monthly_events = Counter(e['created_at'][:7] for e in all_events)

    reviewer_mrs = glab(
        f'/projects/{encoded}/merge_requests?reviewer_username={username}&state=all&created_after={since}',
        paginate=True
    )
    reviewer_iids = {m['iid'] for m in reviewer_mrs}
    reviewer_states = Counter(m['state'] for m in reviewer_mrs)

    # MR-based review activity — approvals and comments from MR API (no retention limit)
    mr_review = get_mr_review_activity(encoded, reviewer_mrs, username)
    approved_map = mr_review['approved_map']
    commented_iids = mr_review['commented_iids']
    monthly_approvals = Counter(v[:7] for v in approved_map.values() if v)
    review_quality = {
        'with_comments': mr_review['with_comments'],
        'with_inline': mr_review['with_inline'],
        'unresolved_threads': mr_review['unresolved_threads'],
        'sample_size': mr_review['sample_size'],
    }

    active_iids = set(approved_map.keys()) | commented_iids
    ghost_count = len(reviewer_iids - active_iids)
    ghost_rate = round(ghost_count / len(reviewer_iids) * 100, 1) if reviewer_iids else 0.0
    approval_rate = round(len(approved_map) / len(reviewer_iids) * 100, 1) if reviewer_iids else 0.0

    author_mrs = glab(
        f'/projects/{encoded}/merge_requests?author_username={username}&state=all&created_after={since}&with_changes_count=true',
        paginate=True
    )
    author_states = Counter(m['state'] for m in author_mrs)
    avg_lt, med_lt = calc_mr_lifetime(author_mrs)
    avg_tta, med_tta, max_tta = calc_time_to_approve(approved_map, encoded)

    # Extended author stats: free from MR data, with fallback detail fetch for PR size
    mr_ext = get_authored_mr_extended_stats(author_mrs, today_str, encoded=encoded)

    email_result = find_git_email(username, name, since, explicit=explicit_emails)
    emails = confirm_git_emails(username, name, email_result,
                                no_confirm=getattr(collect, '_no_confirm', False))
    if emails:
        print(f"[+] Git emails: {', '.join(emails)}", file=sys.stderr)
    else:
        print(f"[WARN] Git stats пропущены для @{username}", file=sys.stderr)
    git = get_git_stats(emails, since, period_days)
    ai_commits = get_ai_commit_stats(emails, since)
    ai_mr_hints = get_ai_mr_hints(author_mrs)

    # Authored MR feedback + pickup time via discussions
    feedback_total, feedback_count, feedback_avg, avg_pickup = get_authored_mr_feedback(
        encoded, author_mrs, username
    )
    merges_performed = action_counts.get('accepted', 0)
    unapprovals = action_counts.get('unapproved', 0)

    pipelines_raw = glab(f'/projects/{encoded}/pipelines?username={username}&per_page=100')
    pipeline_states = Counter(p.get('status', '?') for p in pipelines_raw)

    inactive = detect_inactive_months(monthly_events, git['monthly'], since, today_str)
    cross_projects = get_cross_project_activity(all_events, encoded)
    dora = get_dora_metrics(encoded, since)

    return {
        'username': username, 'name': name, 'uid': uid,
        'events': {
            'total': len(all_events),
            'by_action': dict(action_counts),
            'by_month': dict(sorted(monthly_events.items())),
        },
        'approvals': {
            'total': len(approved_map),
            'by_month': dict(sorted(monthly_approvals.items())),
            'avg_days': avg_tta, 'median_days': med_tta, 'max_days': max_tta,
        },
        'review': {
            'reviewer_total': len(reviewer_mrs),
            'states': dict(reviewer_states),
            'ghost_count': ghost_count,
            'ghost_rate': ghost_rate,
            'approval_rate': approval_rate,
            **review_quality,  # with_comments, with_inline, unresolved_threads, sample_size
        },
        'author': {
            'total': len(author_mrs),
            'states': dict(author_states),
            'avg_lifetime_h': avg_lt,
            'median_lifetime_h': med_lt,
            'feedback_notes': feedback_total,
            'feedback_mr_sample': feedback_count,
            'feedback_avg_per_mr': feedback_avg,
            'avg_pickup_h': avg_pickup,
            **mr_ext,  # avg_pr_size, max_pr_size, merges_without_review, avg_commits_per_mr, stale_open
        },
        'merger': {
            'merges_performed': merges_performed,
            'unapprovals': unapprovals,
        },
        'git': {**git, 'emails': emails},
        'pipelines': {
            'total': len(pipelines_raw),
            'by_status': dict(pipeline_states),
            'success_rate': round(pipeline_states.get('success', 0) / len(pipelines_raw) * 100, 1) if pipelines_raw else None,
        },
        'dora': dora,
        'inactive_months': inactive,
        'cross_projects': cross_projects,
        'ai_assist': {**ai_commits, 'mr_hints': ai_mr_hints},
    }


# ── report rendering ──────────────────────────────────────────────────────────

WEEKDAY_NAMES = ['Пн', 'Вт', 'Ср', 'Чт', 'Пт', 'Сб', 'Вс']


def signals(d):
    out = []
    gr = d['review']['ghost_rate']
    ar = d['review']['approval_rate']
    commits = d['git']['commits']
    avg_tta = d['approvals']['avg_days']
    comments_ev = d['review'].get('with_comments', 0)
    off = d['git']['off_hours']
    wknd = d['git']['weekend']

    if gr > 70:
        out.append(('🔴', f"Ghost reviewer rate {gr:.0f}% — на большинстве назначений не появился"))
    elif gr > 40:
        out.append(('🟡', f"Ghost reviewer rate {gr:.0f}% — значительная часть назначений игнорируется"))
    else:
        out.append(('🟢', f"Ghost reviewer rate {gr:.0f}% — реагирует на большинство назначений"))

    if ar < 20:
        out.append(('🔴', f"Approval rate {ar:.0f}% — утверждает лишь малую долю MRs"))
    elif ar > 50:
        out.append(('🟢', f"Approval rate {ar:.0f}% — высокая вовлечённость в review"))

    if comments_ev == 0:
        out.append(('🔴', "0 комментариев — не оставляет обратной связи на review"))

    if commits < 3:
        out.append(('🔴', f"Только {commits} коммитов за период"))

    if avg_tta is not None:
        if avg_tta < 1:
            out.append(('🟢', f"Time-to-approve avg {avg_tta} дн — быстрая реакция"))
        elif avg_tta > 3:
            out.append(('🟡', f"Time-to-approve avg {avg_tta} дн — медленная реакция"))

    if commits > 0:
        off_pct = round(off / commits * 100)
        wknd_pct = round(wknd / commits * 100)
        if wknd > 0:
            out.append(('⏰', f"{wknd} коммитов в выходные ({wknd_pct}% от всех)"))
        if off > 0:
            out.append(('⏰', f"{off} коммитов вне рабочих часов до 9:00 / после 18:00 ({off_pct}%)"))

    if d['inactive_months']:
        out.append(('⚪', f"Месяцы без активности: {', '.join(d['inactive_months'])}"))

    return out


def _st(icon, label=''):
    """Format status cell."""
    return f"{icon} {label}".strip()


def generate_analysis(d):
    """Generate a plain-text summary paragraph in Russian."""
    g = d['git']
    r = d['review']
    ap = d['approvals']
    ev = d['events']
    ai = d.get('ai_assist', {})

    parts_bad = []
    parts_ok = []
    parts_attn = []

    # Code contribution
    if g['commits'] < 3:
        parts_bad.append(f"крайне низкий вклад в код — всего {g['commits']} коммитов за период")
    elif g['commits'] < 10:
        parts_attn.append(f"невысокий вклад в код ({g['commits']} коммитов, {g['avg_per_month']}/мес)")
    else:
        parts_ok.append(f"стабильный вклад в код ({g['commits']} коммитов, {g['avg_per_month']}/мес)")

    # Ghost review
    gr = r['ghost_rate']
    if gr > 70:
        parts_bad.append(
            f"игнорирует review-назначения: {gr:.0f}% из {r['reviewer_total']} MRs остались без реакции"
        )
    elif gr > 40:
        parts_attn.append(f"пропускает около {gr:.0f}% review-назначений")
    else:
        parts_ok.append(f"обрабатывает большинство review-назначений (ghost rate {gr:.0f}%)")

    # Approval rate
    ar = r['approval_rate']
    if ar < 20 and r['reviewer_total'] > 10:
        parts_bad.append(f"утверждает лишь {ar:.0f}% MRs из тех, где назначен reviewer")
    elif ar > 50:
        parts_ok.append(f"высокий approval rate ({ar:.0f}%)")

    # Comments
    if r.get('with_comments', 0) == 0 and r.get('reviewer_total', 0) > 0:
        parts_bad.append("не оставляет комментариев на code review — обратная связь отсутствует")

    # Time-to-approve
    avg_tta = ap.get('avg_days')
    if avg_tta is not None:
        if avg_tta < 1:
            parts_ok.append(f"быстро отвечает на review-запросы (avg {avg_tta} дн)")
        elif avg_tta > 3:
            parts_attn.append(f"медленная реакция на review ({avg_tta} дн в среднем)")

    # Inactive months
    if d['inactive_months']:
        parts_attn.append(
            f"месяцы без активности: {', '.join(d['inactive_months'])} — "
            "нужно проверить, были ли это отпуск или простой"
        )

    # AI usage
    ai_total = ai.get('total', 0)
    if ai_total > 0:
        tools = ', '.join(ai.get('by_tool', {}).keys())
        parts_ok.append(f"активно использует AI-инструменты ({tools}): {ai_total} коммитов с соавторством")

    # Build the text
    sentences = []
    if parts_bad:
        sentences.append("**Проблемы:** " + "; ".join(parts_bad) + ".")
    if parts_attn:
        sentences.append("**Обратить внимание:** " + "; ".join(parts_attn) + ".")
    if parts_ok:
        sentences.append("**Сильные стороны:** " + "; ".join(parts_ok) + ".")

    if not sentences:
        sentences.append("Данных недостаточно для однозначного вывода.")

    return '\n\n'.join(sentences)


def render_one(d, since, today, days, project):
    u = d['username']
    g = d['git']
    a = d['author']
    ap = d['approvals']
    r = d['review']
    ev = d['events']
    pp = d['pipelines']
    ai = d.get('ai_assist', {})
    monthly_c = g.get('monthly', {})

    # ── status helpers ────────────────────────────────────────────────────────
    def commit_st():
        c = g['commits']
        if c < 3:   return _st('🔴', 'Очень мало')
        if c < 10:  return _st('🟡', 'Мало')
        return _st('🟢', 'Норма')

    def ghost_st():
        gr = r['ghost_rate']
        if gr > 70: return _st('🔴', 'Критично')
        if gr > 40: return _st('🟡', 'Требует внимания')
        return _st('🟢', 'Хорошо')

    def approval_st():
        ar = r['approval_rate']
        if ar < 20: return _st('🔴', 'Очень низкий')
        if ar > 50: return _st('🟢', 'Высокий')
        return _st('🟡', 'Средний')

    def tta_st():
        t = ap.get('avg_days')
        if t is None: return _st('⚪', 'Нет данных')
        if t < 1:  return _st('🟢', 'Быстро')
        if t > 3:  return _st('🟡', 'Медленно')
        return _st('🟢', 'Норма')

    def comment_st():
        c = r.get('with_comments', 0)
        total = r.get('reviewer_total', 0)
        if c == 0 and total > 0: return _st('🔴', 'Нет')
        if c < 3: return _st('🟡', 'Мало')
        return _st('🟢', f'{c} MRs с комментариями')

    def pipeline_st():
        sr = pp.get('success_rate')
        if sr is None: return _st('⚪', 'Нет данных')
        if sr < 60: return _st('🔴', f'{sr}%')
        if sr < 85: return _st('🟡', f'{sr}%')
        return _st('🟢', f'{sr}%')

    def inactive_st():
        if d['inactive_months']: return _st('🟡', ', '.join(d['inactive_months']))
        return _st('🟢', 'Нет')

    def ai_st():
        total = ai.get('total', 0)
        if total == 0: return _st('⚪', 'Не обнаружено')
        tools = '/'.join(ai.get('by_tool', {}).keys())
        return _st('🟢', f"{total} коммитов ({tools})")

    # ── report ────────────────────────────────────────────────────────────────
    git_emails = g.get('emails', [])
    emails_str = ', '.join(git_emails) if git_emails else '_не найдены_'
    tta_str = (f"{ap['avg_days']} дн (med {ap['median_days']}, max {ap['max_days']})"
               if ap.get('avg_days') is not None else '—')
    merged_pct = round(a['states'].get('merged', 0) / a['total'] * 100) if a['total'] else 0

    mrgr = d.get('merger', {})
    merges_done = mrgr.get('merges_performed', 0)
    fb_avg = a.get('feedback_avg_per_mr', 0.0)
    fb_sample = a.get('feedback_mr_sample', 0)

    cross = d.get('cross_projects', [])

    L = [
        f"# Отчёт: @{u} ({d['name']})",
        f"**Период:** {since} — {today} ({days} дней)",
        "",
    ]

    # Cross-project footprint
    if cross:
        total_projects = len(cross)
        total_all_events = sum(p['total'] for p in cross)
        L += [
            "## Активность в GitLab (все проекты)",
            "",
            f"_Всего активных проектов: {total_projects} | Всего событий: {total_all_events}_",
            "",
            "| Проект | События | Pushes | Approvals | Комментарии | Мержи |",
            "|---|---|---|---|---|---|",
        ]
        for p in cross:
            marker = " ⭐" if p['is_current'] else ""
            name = p['name'] + marker
            L.append(
                f"| {name} | {p['total']} | {p['pushes']} | {p['approvals']} | {p['comments']} | {p['merges']} |"
            )
        L += [
            "",
            f"> ⭐ — текущий проект (`{project}`). Детальный анализ ниже.",
            "> Git commit stats — только текущий репозиторий.",
            "",
        ]

    L += [
        f"## Анализ: {project}",
        "",
        "## Сводная таблица",
        "",
        "| Роль | Метрика | Значение | Статус |",
        "|---|---|---|---|",
        # Author
        f"| Автор | Коммитов | {g['commits']} (avg {g['avg_per_month']}/мес) | {commit_st()} |",
        f"| Автор | Строк добавлено / удалено | +{g['added']:,} / -{g['deleted']:,} | — |",
        f"| Автор | MRs создано / merged | {a['total']} / {a['states'].get('merged',0)} ({merged_pct}%) | — |",
        f"| Автор | PR Size (avg/p50/p75/p90) | {a.get('avg_pr_size',0)} / {a.get('p50_pr_size',0)} / {a.get('p75_pr_size',0)} / {a.get('p90_pr_size',0)} строк | {'🔴 p90 >400' if a.get('p90_pr_size',0) > 400 else '🟡 p75 >200' if a.get('p75_pr_size',0) > 200 else '🟢 Норма' if a.get('avg_pr_size',0) > 0 else '⚪ Нет данных'} |",
        f"| Автор | Merges without review | {a.get('merges_without_review',0)} | {'🔴 Критично' if a.get('merges_without_review',0) > 0 else '🟢 Нет'} |",
        f"| Автор | Avg commits per MR | {a.get('avg_commits_per_mr',0)} | — |",
        f"| Автор | Stale open MRs (>7 дней) | {a.get('stale_open',0)} | {'🟡 Требует внимания' if a.get('stale_open',0) > 0 else '🟢 Нет'} |",
        f"| Автор | Получено комментариев на MRs | avg {fb_avg}/MR (выборка {fb_sample} MRs) | — |",
        f"| Автор | Pickup Time (до первого review) | {str(a['avg_pickup_h']) + ' ч' if a.get('avg_pickup_h') else '—'} | — |",
        # Reviewer
        f"| Reviewer | Назначений | {r['reviewer_total']} MRs | — |",
        f"| Reviewer | Ghost rate | {r['ghost_rate']}% ({r['ghost_count']} MRs без реакции) | {ghost_st()} |",
        f"| Reviewer | Approvals выдано | {ap['total']} ({r['approval_rate']}%) | {approval_st()} |",
        f"| Reviewer | Time-to-approve | {tta_str} | {tta_st()} |",
        f"| Reviewer | Комментарии (обычные) | {r.get('with_comments',0)}/{r.get('sample_size',0)} MRs из выборки | {comment_st()} |",
        f"| Reviewer | Inline code comments | {r.get('with_inline',0)} (на строки кода) | {'🟢 Есть' if r.get('with_inline',0) > 0 else '🔴 Нет'} |",
        f"| Reviewer | Unresolved threads в sample | {r.get('unresolved_threads',0)} | — |",
        # Merger
        f"| Мержер | MRs смержено | {merges_done} | {'🟢 Активно' if merges_done > 5 else '🟡 Мало' if merges_done > 0 else '⚪ Нет'} |",
        f"| Мержер | Unapprovals | {d.get('merger',{}).get('unapprovals',0)} | {'🟡 Нестабильные решения' if d.get('merger',{}).get('unapprovals',0) > 0 else '🟢 Нет'} |",
        # DORA
    ] + (
        [f"| DORA | Lead Time for Changes | {round(d.get('dora',{}).get('lead_time_for_changes',0)/3600, 1)} ч | — |"]
        if d.get('dora', {}).get('lead_time_for_changes') else []
    ) + (
        [f"| DORA | Deployment Frequency | {d.get('dora',{}).get('deployment_frequency',0)}/день | — |"]
        if d.get('dora', {}).get('deployment_frequency') is not None else []
    ) + [
        # Other
        f"| — | AI-ассистент | {ai_st()} | — |",
        f"| — | Пайплайны (success) | {pp['total']} всего | {pipeline_st()} |",
        f"| — | Месяцы без активности | {inactive_st()} | — |",
        f"| — | Всего событий | {ev['total']} | — |",
        "",
        "## Анализ",
        "",
        generate_analysis(d),
        "",
    ]

    # ── details ───────────────────────────────────────────────────────────────
    L += ["---", "", "## Детали", ""]

    # Code
    L += ["### Код", ""]
    if a['avg_lifetime_h']:
        L.append(f"- MR lifetime: avg {a['avg_lifetime_h']}ч, median {a['median_lifetime_h']}ч")
    if monthly_c:
        L += ["", "| Месяц | Коммиты |", "|---|---|"]
        L += [f"| {m} | {c} |" for m, c in sorted(monthly_c.items())]
    L.append("")

    # AI
    ai_total = ai.get('total', 0)
    ai_sample = ai.get('sample', [])
    ai_mr_hints = ai.get('mr_hints', [])
    if ai_total > 0 or ai_mr_hints:
        L += ["### AI-соавторство", ""]
        tools_str = ', '.join(f"{t}: {c}" for t, c in ai.get('by_tool', {}).items())
        L.append(f"Коммитов с AI: {ai_total} ({ai.get('pct', 0)}%) — {tools_str}")
        for s in ai_sample:
            L.append(f"- `{s['hash']}` {s['subject']} _[{', '.join(s['tools'])}]_")
        for h in ai_mr_hints[:3]:
            L.append(f"- MR#{h['iid']}: {h['title']} _[{', '.join(h['tools'])}]_")
        L.append("")

    # Review
    L += ["### Review", ""]
    if ap['by_month']:
        L += ["| Месяц | Approvals |", "|---|---|"]
        L += [f"| {m} | {c} |" for m, c in sorted(ap['by_month'].items())]
        L.append("")

    # Monthly activity
    all_months = sorted(set(list(ev['by_month']) + list(monthly_c) + list(ap['by_month'])))
    if all_months:
        L += ["### Активность по месяцам", ""]
        L += ["| Месяц | События | Approvals | Коммиты |", "|---|---|---|---|"]
        L += [f"| {m} | {ev['by_month'].get(m,0)} | {ap['by_month'].get(m,0)} | {monthly_c.get(m,0)} |"
              for m in all_months]
        L.append("")

    # Work hours
    by_wd = {int(k): v for k, v in g.get('by_weekday', {}).items()}
    if by_wd:
        L += ["### Рабочий ритм", ""]
        L += ["| День | Коммитов |", "|---|---|"]
        L += [f"| {WEEKDAY_NAMES[wd]} | {cnt} |" for wd, cnt in sorted(by_wd.items())]
        if g['commits']:
            L.append(f"\nВне рабочих часов: {g['off_hours']} ({round(g['off_hours']/g['commits']*100)}%) | "
                     f"Выходные: {g['weekend']} ({round(g['weekend']/g['commits']*100)}%)")
        L.append("")

    # Pipelines
    if pp['total'] > 0:
        s = pp['by_status'].get('success', 0)
        f = pp['by_status'].get('failed', 0)
        L += ["### Пайплайны", ""]
        L += ["| Всего | Success | Failed | Success rate |", "|---|---|---|---|"]
        L.append(f"| {pp['total']} | {s} | {f} | {pp['success_rate']}% |")
        L.append("")

    return '\n'.join(L)


def render_compare(d1, d2, since, today, days, project):
    u1, u2 = d1['username'], d2['username']

    def row(label, v1, v2):
        return f"| {label} | {v1} | {v2} |"

    L = [
        f"# Сравнение: @{u1} vs @{u2}",
        f"**Период:** {since} — {today} ({days} дней)  ",
        f"**Проект:** {project}", "",
        "## Сводная таблица", "",
        f"| Метрика | @{u1} | @{u2} |", "|---|---|---|",
        row("Коммитов", d1['git']['commits'], d2['git']['commits']),
        row("Avg коммитов/мес", d1['git']['avg_per_month'], d2['git']['avg_per_month']),
        row("Строк добавлено", f"+{d1['git']['added']:,}", f"+{d2['git']['added']:,}"),
        row("Строк удалено",   f"-{d1['git']['deleted']:,}", f"-{d2['git']['deleted']:,}"),
        row("MRs как автор",  d1['author']['total'], d2['author']['total']),
        row("MRs merged",     d1['author']['states'].get('merged',0), d2['author']['states'].get('merged',0)),
        row("Reviewer назначений", d1['review']['reviewer_total'], d2['review']['reviewer_total']),
        row("Ghost rate",     f"{d1['review']['ghost_rate']}%", f"{d2['review']['ghost_rate']}%"),
        row("Approvals",      d1['approvals']['total'], d2['approvals']['total']),
        row("Approval rate",  f"{d1['review']['approval_rate']}%", f"{d2['review']['approval_rate']}%"),
        row("Всего событий",  d1['events']['total'], d2['events']['total']),
        "",
        "## Сигналы", "",
    ]
    for icon, text in signals(d1):
        L.append(f"**@{u1}** {icon} {text}  ")
    for icon, text in signals(d2):
        L.append(f"**@{u2}** {icon} {text}  ")
    L.append("")
    return '\n'.join(L)


# ── entry point ───────────────────────────────────────────────────────────────

def main():
    p = argparse.ArgumentParser(description='GitLab Developer Activity Analyzer')
    p.add_argument('--username', required=True)
    p.add_argument('--compare', default=None)
    p.add_argument('--days', type=int, default=90)
    p.add_argument('--git-email', default=None,
                   help='Comma-separated git emails for --username (skip auto-detection)')
    p.add_argument('--compare-git-email', default=None,
                   help='Comma-separated git emails for --compare user')
    p.add_argument('--no-confirm', action='store_true',
                   help='Skip interactive git email confirmation (for CI/scripting)')
    p.add_argument('--json', dest='as_json', action='store_true')
    args = p.parse_args()

    explicit = [e.strip() for e in args.git_email.split(',')] if args.git_email else None
    explicit_compare = [e.strip() for e in args.compare_git_email.split(',')] if args.compare_git_email else None
    collect._no_confirm = args.no_confirm

    today = date.today().isoformat()
    since = (date.today() - timedelta(days=args.days)).isoformat()
    project, encoded = detect_project()

    if not encoded:
        sys.exit("[ERROR] Cannot detect GitLab project from git remote")

    print(f"[+] Project: {project}", file=sys.stderr)
    print(f"[+] Period:  {since} → {today} ({args.days} days)", file=sys.stderr)

    d1 = collect(args.username, encoded, since, today, args.days, explicit_emails=explicit)
    d2 = collect(args.compare, encoded, since, today, args.days, explicit_emails=explicit_compare) if args.compare else None

    if args.as_json:
        out = {'user': d1}
        if d2:
            out['compare'] = d2
        print(json.dumps(out, ensure_ascii=False, indent=2))
        return

    if d2:
        print(render_compare(d1, d2, since, today, args.days, project))
        print("\n---\n")
        print(render_one(d1, since, today, args.days, project))
        print("\n---\n")
        print(render_one(d2, since, today, args.days, project))
    else:
        print(render_one(d1, since, today, args.days, project))


if __name__ == '__main__':
    main()
