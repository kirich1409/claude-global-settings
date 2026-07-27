#!/bin/bash
# validate-config — structural lint for the ~/.claude config repo.
#
# Turns the recurring "full audit" findings into a per-PR gate: instead of a periodic
# multi-agent sweep rediscovering the same drift (hardcoded paths, stale CLAUDE.md index,
# broken [[links]], invalid JSON, missing hook files, broken shell syntax), every PR runs
# this script in CI and fails fast on the categories that have actually bitten before.
#
# Usage: scripts/validate-config.sh   (run from anywhere inside the repo)
# Exit:  0 = clean, 1 = findings printed to stdout.
#
# Suppressing a finding on a specific line: append a `validate-config: allow` comment.

set -uo pipefail

REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null)" || { echo "not in a git repo" >&2; exit 2; }
cd "$REPO_ROOT" || exit 2

FAIL=0
fail() { printf '✗ %s\n' "$*"; FAIL=1; }
ok()   { printf '✓ %s\n' "$*"; }

# Tracked files once; every check works off this list so untracked local state
# (memory, .remember, projects, swarm-report) is never scanned.
TRACKED_LIST="$(mktemp)"
trap 'rm -f "$TRACKED_LIST"' EXIT
git ls-files > "$TRACKED_LIST"

# --- 1. Hardcoded absolute home paths -------------------------------------------------
# Configs and hooks must use $HOME; machine-specific /Users/<name> paths break the
# multi-machine sync model. Pattern is split so this script does not flag itself;
# `/Users/<` placeholders in docs ("never hardcode /Users/<username>") are exempt.
PAT='/Us''ers/'
hits=$(git ls-files -z | xargs -0 grep -InI -e "$PAT" -- 2>/dev/null \
  | grep -v -e "${PAT}<" -e 'validate-config: allow' || true)
if [ -n "$hits" ]; then
  # ${PAT} in the messages (not a literal) so this script never flags itself once tracked.
  fail "hardcoded ${PAT} paths in tracked files (use \$HOME):"
  printf '%s\n' "$hits" | sed 's/^/    /'
else
  ok "no hardcoded ${PAT} paths"
fi

# --- 2. CLAUDE.md rules index <-> rules/*.md ------------------------------------------
# Every rules file must be listed in the CLAUDE.md index, and every index entry must
# have a file — both directions, so the index never silently drifts.
if [ -f CLAUDE.md ] && [ -d rules ]; then
  indexed=$(grep -oE '\*\*[a-z0-9-]+\.md\*\*' CLAUDE.md | tr -d '*' | sort -u)
  actual=$(cd rules && ls -1 *.md 2>/dev/null | sort -u)
  missing_from_index=$(comm -13 <(printf '%s\n' "$indexed") <(printf '%s\n' "$actual"))
  missing_files=$(comm -23 <(printf '%s\n' "$indexed") <(printf '%s\n' "$actual"))
  [ -n "$missing_from_index" ] && fail "rules files absent from CLAUDE.md index: $(echo $missing_from_index)"
  [ -n "$missing_files" ] && fail "CLAUDE.md index entries without a rules file: $(echo $missing_files)"
  [ -z "$missing_from_index" ] && [ -z "$missing_files" ] && ok "CLAUDE.md index matches rules/"
fi

# --- 3. [[wiki-links]] in CLAUDE.md + rules resolve to rules files ---------------------
badlinks=""
for f in CLAUDE.md rules/*.md; do
  [ -f "$f" ] || continue
  for link in $(grep -oE '\[\[[a-z0-9-]+\]\]' "$f" | tr -d '[]' | sort -u); do
    [ -f "rules/$link.md" ] || badlinks="$badlinks ${f}:[[${link}]]"
  done
done
if [ -n "$badlinks" ]; then
  fail "broken [[links]] (no rules/<name>.md):$badlinks"
else
  ok "all [[links]] resolve"
fi

# --- 4. Tracked JSON parses -------------------------------------------------------------
badjson=""
while IFS= read -r f; do
  python3 -m json.tool "$f" >/dev/null 2>&1 || badjson="$badjson $f"
done < <(grep -E '\.json$' "$TRACKED_LIST")
if [ -n "$badjson" ]; then
  fail "invalid JSON:$badjson"
else
  ok "all tracked JSON valid"
fi

# --- 5. Hook files referenced in settings.json exist ------------------------------------
if [ -f settings.json ]; then
  # Heredoc stays at top level (not inside $()): bash 3.2 on macOS mis-parses quotes
  # inside command-substituted heredocs.
  HOOKS_OUT="$(mktemp)"
  python3 - > "$HOOKS_OUT" <<'PYEOF'
import json, os, re
with open("settings.json") as fh:
    cfg = json.load(fh)
missing = []
def walk(node):
    if isinstance(node, dict):
        cmd = node.get("command")
        if isinstance(cmd, str):
            # Pull every path-looking token pointing inside repo hooks/ or scripts/.
            for tok in re.findall(r'(?:\$HOME/\.claude|~/\.claude)(/[^\s"\';|&]+)', cmd):
                rel = tok.lstrip("/")
                if rel.startswith(("hooks/", "scripts/")) and not os.path.exists(rel):
                    missing.append(rel)
        for v in node.values():
            walk(v)
    elif isinstance(node, list):
        for v in node:
            walk(v)
walk(cfg.get("hooks", {}))
print(" ".join(sorted(set(missing))))
PYEOF
  missing_hooks=$(cat "$HOOKS_OUT"); rm -f "$HOOKS_OUT"
  if [ -n "$missing_hooks" ]; then
    fail "settings.json references missing hook/script files: $missing_hooks"
  else
    ok "all hooks referenced in settings.json exist"
  fi
fi

# --- 6. Shell syntax for all tracked .sh -------------------------------------------------
badsh=""
while IFS= read -r f; do
  bash -n "$f" 2>/dev/null || badsh="$badsh $f"
done < <(grep -E '\.sh$' "$TRACKED_LIST")
if [ -n "$badsh" ]; then
  fail "bash -n syntax errors:$badsh"
else
  ok "all tracked .sh pass bash -n"
fi

# --- 7-8. Agent and skill frontmatter actually parses as YAML ----------------------------
# grep for "^name:" only proves the line exists. A description holding an unescaped quote
# closes its scalar early and makes the whole block unparseable — the agent then silently
# vanishes from the session's roster while a presence check still reports OK. Parse it.
FM_OUT="$(mktemp)"
python3 - > "$FM_OUT" <<'PYEOF'
import glob, os, sys
try:
    import yaml
except ImportError:
    print("FATAL PyYAML missing — install it (pip install pyyaml) so frontmatter can be parsed")
    sys.exit(0)

def frontmatter(path):
    text = open(path, encoding="utf-8").read()
    if not text.startswith("---\n"):
        raise ValueError("no frontmatter: file does not start with ---")
    parts = text[4:].split("\n---\n", 1)
    if len(parts) != 2:
        raise ValueError("frontmatter is not closed by ---")
    data = yaml.safe_load(parts[0])
    if not isinstance(data, dict):
        raise ValueError("frontmatter is not a mapping")
    return data

for path in sorted(glob.glob("agents/*.md")) + sorted(glob.glob("skills/*/SKILL.md")):
    label = path
    try:
        fm = frontmatter(path)
    except Exception as exc:
        first = str(exc).splitlines()[0]
        print(f"BAD {label}: {first}")
        continue
    for field in ("name", "description"):
        if not str(fm.get(field) or "").strip():
            print(f"BAD {label}: {field} is missing or empty")
    if path.startswith("skills/"):
        directory = os.path.basename(os.path.dirname(path))
        if str(fm.get("name") or "").strip() != directory:
            print(f"BAD {label}: name '{fm.get('name')}' != directory '{directory}'")
PYEOF
if grep -q '^FATAL' "$FM_OUT"; then
  fail "$(sed -n 's/^FATAL //p' "$FM_OUT")"
elif [ -s "$FM_OUT" ]; then
  fail "agent/skill frontmatter problems:"
  sed 's/^BAD /    /' "$FM_OUT"
else
  ok "agent and skill frontmatter parses as YAML"
fi
rm -f "$FM_OUT"

# --- 9. Permission rules semantics in settings.json --------------------------------------
# Write(<path>) rules are silently ignored by file permission checks — only Edit(<path>)
# covers file-editing tools (Write/Edit/NotebookEdit). A Write() deny rule therefore looks
# like protection while protecting nothing (the exact incident this check exists for).
if [ -f settings.json ]; then
  PERM_OUT="$(mktemp)"
  python3 - > "$PERM_OUT" <<'PYEOF'
import json
cfg = json.load(open("settings.json"))
perms = cfg.get("permissions") or {}
bad = []
for key in ("allow", "deny", "ask"):
    for rule in perms.get(key) or []:
        # Bare "Write" (tool-level allow) is valid; "Write(<anything>)" is dead config.
        if rule.startswith("Write("):
            bad.append(f"{key}:{rule}")
print(" ".join(bad))
PYEOF
  badperm=$(cat "$PERM_OUT"); rm -f "$PERM_OUT"
  if [ -n "$badperm" ]; then
    fail "Write(<path>) permission rules are ignored by file checks — use Edit(<path>): $badperm"
  else
    ok "no Write(<path>) permission rules"
  fi
fi

# --- 10. Backticked <name>.md references in agents/ + skills/ resolve to a real file ---------
# Rules moved into skills leave prose pointers like `qa-and-testing.md` behind. The [[links]]
# check only covers wiki-links, so plain filename mentions rotted silently until a /doctor run
# found ~10 of them. This resolves every backticked *.md mention against the repo.
REF_OUT="$(mktemp)"
python3 - > "$REF_OUT" <<'PYEOF'
import os, re, subprocess
tracked = set(subprocess.run(["git","ls-files"],capture_output=True,text=True).stdout.split())
basenames = {os.path.basename(f) for f in tracked}
# Names that legitimately refer to files outside this repo or to per-project artifacts.
EXTERNAL = {
    "CLAUDE.md","CLAUDE.local.md","AGENTS.md","README.md","SKILL.md","MEMORY.md",
    "package.json","tests.json","progress.md","tasks.md",
    # Per-project artifacts produced at runtime, not files tracked here.
    "debug.md","coverage-audit.md","CHANGELOG.md","RELEASE_NOTES.md","baseline.md",
    "e2e-scenario.md","state.md","report.md",
}
DATED = re.compile(r"^\d{4}-\d{2}-\d{2}-")
bad = []
for f in sorted(tracked):
    if not (f.startswith("agents/") or f.startswith("skills/")):
        continue
    if not f.endswith(".md"):
        continue
    for n, line in enumerate(open(f, encoding="utf-8", errors="replace"), 1):
        for ref in re.findall(r"`((?:[A-Za-z0-9_.-]+/)*[A-Za-z0-9_.-]+\.md)`", line):
            base = os.path.basename(ref)
            if "<" in ref or ref.startswith(".") or DATED.match(base):
                continue
            if base in EXTERNAL:
                continue
            # Paths under these prefixes are produced per project at runtime, not tracked here.
            if ref.split("/")[0] in ("docs", "swarm-report"):
                continue
            if "/" in ref:
                # Try every ancestor of the referencing file as a base, then the repo root.
                # This accepts both "references/x.md" from a SKILL.md and the same sibling
                # form written from inside references/ itself.
                base_dir = os.path.dirname(f)
                found = ref in tracked
                while base_dir and not found:
                    if os.path.normpath(os.path.join(base_dir, ref)) in tracked:
                        found = True
                    base_dir = os.path.dirname(base_dir)
                if found:
                    continue
            elif ref in basenames:
                continue
            bad.append(f"{f}:{n}:{ref}")
print(" ".join(bad))
PYEOF
badrefs=$(cat "$REF_OUT"); rm -f "$REF_OUT"
if [ -n "$badrefs" ]; then
  fail "backticked .md references with no matching file (moved or deleted?):$badrefs"
else
  ok "all backticked .md references resolve"
fi

echo
if [ "$FAIL" -ne 0 ]; then
  echo "validate-config: FAIL"
  exit 1
fi
echo "validate-config: OK"
