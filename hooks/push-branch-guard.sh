#!/bin/bash
# Push guard: блокирует `git push` в защищённые ветки (main/master/develop).
# Deny, если:
#   - в команде явный refspec/цель на защищённую ветку (`git push origin main`,
#     `HEAD:main`, `:main`);
#   - «голый» `git push` (без refspec), когда текущая ветка репо (cwd payload)
#     — защищённая.
# Push feature/fix/chore-веток, `--delete` не-защищённых и `--force-with-lease`
# на не-защищённые не трогает.

INPUT=$(cat)

if ! command -v python3 >/dev/null 2>&1; then
    echo "WARN: python3 not found — push-branch-guard cannot parse tool input, skipping check" >&2
    exit 0
fi

# Payload передаётся через env: heredoc занимает stdin python3 под сам скрипт
PUSH_GUARD_INPUT="$INPUT" python3 - <<'PYEOF'
import json, os, re, subprocess, sys

try:
    payload = json.loads(os.environ.get("PUSH_GUARD_INPUT") or "{}")
except Exception:
    sys.exit(0)

tool_input = payload.get("tool_input") or {}
cmd = tool_input.get("command") or ""
cwd = payload.get("cwd") or "."

PROTECTED = {"main", "master", "develop"}

# Интересуют только команды, реально вызывающие `git push` (в т.ч. `git -C <dir> push`)
m = re.search(r"\bgit\s+(?:-C\s+\S+\s+)?push\b([^|;&]*)", cmd)
if not m:
    sys.exit(0)

def deny(reason):
    sys.stderr.write(
        "PUSH-GUARD: git push в защищённую ветку (main/master/develop) запрещён правилами — работай через PR.\n"
        "Причина: " + reason + "\n"
        "Команда: " + cmd + "\n"
    )
    sys.exit(2)

# Токены после `push` до ближайшего shell-оператора; опции (-*) отбрасываем.
# Первый позиционный токен — remote, остальные — refspecs.
positional = [t for t in m.group(1).split() if not t.startswith("-")]
refspecs = positional[1:]

if refspecs:
    for spec in refspecs:
        # dst refspec'а: `main` → main, `HEAD:main` → main, `:main` → main (delete)
        dst = spec.lstrip("+")
        if ":" in dst:
            dst = dst.split(":", 1)[1]
        dst = re.sub(r"^refs/heads/", "", dst)
        if dst in PROTECTED:
            deny("явная цель push — защищённая ветка '%s' (refspec '%s')" % (dst, spec))
    sys.exit(0)

# «Голый» push (без refspec) — цель определяется текущей веткой репо
try:
    branch = subprocess.run(
        ["git", "-C", cwd, "rev-parse", "--abbrev-ref", "HEAD"],
        capture_output=True, text=True, timeout=5,
    ).stdout.strip()
except Exception:
    sys.exit(0)  # fail-open: не git-репо / git недоступен

if branch in PROTECTED:
    deny("«голый» git push при текущей ветке '%s'" % branch)

sys.exit(0)
PYEOF
