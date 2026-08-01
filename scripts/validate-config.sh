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

# --- 2. Бюджет безусловных инструкций -------------------------------------------------
# CLAUDE.md + rules/*.md без frontmatter `paths:` грузятся в каждую сессию и наследуются
# каждым субагентом. Гейт ловит обратное разрастание; при срыве печатает разбивку по файлам.
UNCOND_BUDGET=${UNCOND_BUDGET:-100000}
if [ -f CLAUDE.md ] && [ -d rules ]; then
  total=0; breakdown=""
  for f in CLAUDE.md rules/*.md; do
    head -12 "$f" | grep -q '^paths:' && continue
    sz=$(wc -c < "$f")
    total=$((total + sz))
    breakdown="${breakdown}\n  $(printf '%7d' "$sz")  $f"
  done
  if [ "$total" -gt "$UNCOND_BUDGET" ]; then
    fail "unconditional instructions ${total}b exceed budget ${UNCOND_BUDGET}b:$(printf "$breakdown")"
  else
    ok "unconditional instructions ${total}b within budget ${UNCOND_BUDGET}b"
  fi
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

# --- 7. Skill frontmatter name matches its directory -------------------------------------
badskill=""
for f in skills/*/SKILL.md; do
  [ -f "$f" ] || continue
  dir=$(basename "$(dirname "$f")")
  name=$(awk -F': *' '/^name:/{print $2; exit}' "$f")
  [ "$name" = "$dir" ] || badskill="$badskill $dir(name:$name)"
done
if [ -n "$badskill" ]; then
  fail "skill frontmatter name != directory:$badskill"
else
  ok "skill names match directories"
fi

# --- 8. Agent files have frontmatter with name ------------------------------------------
badagent=""
for f in agents/*.md; do
  [ -f "$f" ] || continue
  head -1 "$f" | grep -q '^---$' && grep -q '^name:' "$f" || badagent="$badagent $(basename "$f")"
done
if [ -n "$badagent" ]; then
  fail "agent files missing frontmatter/name:$badagent"
else
  ok "agent frontmatter present"
fi

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

# --- 10. ~/.claude/** pointers in markdown resolve ---------------------------------------
# Skills and agents reach into references/** by absolute path — that is the one channel that
# actually delivers text, since references/ never loads on its own. A file moving between
# rules/ and references/ silently breaks the pointer: skills/acceptance pointed at
# rules/context-resilience.md for weeks after that file moved. Prose placeholders (foo.md,
# trailing "...") and glob patterns are exempt.
PTR_OUT="$(mktemp)"
PTR_PY="$(mktemp)"
# Script goes to a file, not a heredoc: a heredoc on the xargs end of a pipeline steals
# stdin from the pipe, so xargs would consume this source text as its file list and the
# check would pass while inspecting nothing.
cat > "$PTR_PY" <<'PYEOF'
import os, re, sys
pat = re.compile(r"(?:\$HOME/\.claude|~/\.claude)/([^\s\"'`;|&)\]}]+)")
PLACEHOLDERS = ("foo", "bar", "baz")
bad = []
for f in sys.argv[1:]:
    try:
        lines = open(f, encoding="utf-8").readlines()
    except OSError:
        continue
    for i, line in enumerate(lines, 1):
        if "validate-config: allow" in line:
            continue
        for m in pat.finditer(line):
            # Strip trailing prose punctuation, then a file:line suffix ("task-types.md:9").
            p = re.sub(r":\d+$", "", m.group(1).rstrip(".,:;)"))
            if not p or p.endswith("/") or "..." in p:
                continue
            if any(c in p for c in "*<>{}$"):
                continue
            if os.path.basename(p).split(".")[0] in PLACEHOLDERS:
                continue
            if not os.path.exists(p):
                bad.append(f"{f}:{i}->{p}")
print(" ".join(bad))
PYEOF
git ls-files -z -- '*.md' | xargs -0 python3 "$PTR_PY" > "$PTR_OUT"
badptr=$(cat "$PTR_OUT"); rm -f "$PTR_OUT" "$PTR_PY"
if [ -n "$badptr" ]; then
  fail "markdown points at non-existent ~/.claude paths:"
  printf '%s\n' "$badptr" | tr ' ' '\n' | sed 's/^/    /'
else
  ok "all ~/.claude paths in markdown resolve"
fi

echo
if [ "$FAIL" -ne 0 ]; then
  echo "validate-config: FAIL"
  exit 1
fi
echo "validate-config: OK"
