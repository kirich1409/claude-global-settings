#!/bin/bash
# Destructive-command guard (PreToolUse: Bash) — блокирует катастрофические команды.
#
# Зачем: deny-паттерны вида `Bash(rm -rf /)` — это строковые шаблоны; их обходит
# перестановка флагов (`rm -r -f /`), длинные формы (`--recursive`), абсолютный путь
# (`/bin/rm`) и цепочки (`cd / && rm -rf .`). Официальная позиция документации:
# Bash-паттерны permissions — не security-граница, реальную защиту дают hooks.
# Guard токенизирует команду (shlex) и режет только катастрофу: рекурсивное удаление
# корня/системных путей/домашней директории целиком, затирание блочных устройств,
# форматирование ФС, рекурсивный chmod по корню, fork-bomb, pipe скачанного кода
# в shell, force-push без --force-with-lease/--force-if-includes.
#
# Рутинные удаления (build/, node_modules/, файлы проекта) guard НЕ трогает —
# их оценивает auto-mode классификатор или явные правила.
#
# Fail-open по инфраструктуре (нет python3 → пропустить), fail-closed по совпадению.
# Ложное срабатывание → пользователь выполняет команду сам (! prefix) или правит guard.

INPUT=$(cat)

if ! command -v python3 >/dev/null 2>&1; then
    echo "WARN: python3 not found — destructive-guard cannot parse tool input, skipping check" >&2
    exit 0
fi

# Payload через env: heredoc занимает stdin python3 под сам скрипт (как в secret-read-guard).
DESTRUCTIVE_GUARD_INPUT="$INPUT" python3 - <<'PYEOF'
import json, os, re, shlex, sys

try:
    payload = json.loads(os.environ.get("DESTRUCTIVE_GUARD_INPUT") or "{}")
except Exception:
    sys.exit(0)

cmd = (payload.get("tool_input") or {}).get("command") or ""
if not cmd:
    sys.exit(0)

def deny(label):
    sys.stderr.write(
        "DESTRUCTIVE-GUARD: команда попадает под катастрофический паттерн (%s) — заблокировано.\n"
        "Это hard-граница: найди безопасную альтернативу или объясни пользователю, "
        "чтобы он выполнил команду сам (! prefix).\n"
        "Команда: %s\n" % (label, cmd)
    )
    sys.exit(2)

# --- Простые regex-паттерны по всей команде --------------------------------------------
REGEX_PATTERNS = [
    (r'\bdd\b[^|;&]*\bof=/dev/(?:sd|hd|nvme|disk|vd|xvd|mmcblk|loop|md|dm-)', "dd поверх блочного устройства"),
    (r'\bmkfs(\.\w+)?\s', "форматирование файловой системы"),
    (r'\bshred\b[^|;&]*/dev/', "shred по устройству"),
    (r'\bchmod\s+-[a-zA-Z]*R[a-zA-Z]*\s+\S+\s+/(?:\s|$)', "рекурсивный chmod по корню"),
    (r':\(\)\s*\{\s*:\|:', "fork bomb"),
    (r'\b(?:curl|wget)\b[^|;&]*\|\s*(?:sudo\s+)?(?:ba|z|da)?sh\b', "pipe скачанного кода в shell"),
]
for pattern, label in REGEX_PATTERNS:
    if re.search(pattern, cmd):
        deny(label)

# --- Токенный анализ по сегментам (split на shell-операторы) ---------------------------
# shlex снимает кавычки: `echo "rm -rf /"` даёт echo один аргумент-строку — не FP.
SEGMENTS = re.split(r'&&|\|\||[|;&]', cmd)

# Пути, рекурсивное удаление которых — катастрофа. Точные формы (кавычки уже сняты shlex).
CRITICAL_EXACT = {
    "/", "/*",
    "~", "~/", "~/*",
    "$HOME", "$HOME/", "$HOME/*", "${HOME}", "${HOME}/", "${HOME}/*",
    ".", "..", "./", "../", "../*",
}
SYSTEM_PREFIXES = (
    "/bin", "/sbin", "/usr", "/etc", "/var", "/opt", "/boot", "/lib", "/lib64",
    "/srv", "/root", "/System", "/Library", "/Applications", "/Volumes", "/private",
)

def is_critical_target(t):
    if t in CRITICAL_EXACT:
        return True
    if t.startswith(SYSTEM_PREFIXES):
        # /usr, /usr/*, /etc/nginx — системные пути на любую глубину
        rest = t[len(next(p for p in SYSTEM_PREFIXES if t.startswith(p))):]
        if rest == "" or rest.startswith("/") or rest == "*":
            return True
    # Домашняя директория целиком по абсолютному пути: /home/<name>, /Users/<name> (но не глубже)
    m = re.match(r'^/(?:home|Users)(?:/[^/]+)?/?$', t)
    return bool(m)

def tokens(segment):
    try:
        return shlex.split(segment)
    except ValueError:
        return segment.split()

for seg in SEGMENTS:
    toks = tokens(seg)
    if not toks:
        continue

    # rm с recursive-флагом по критической цели. rm ищем как токен команды в любой
    # позиции (ловит sudo/env/timeout-обёртки и /bin/rm); переоценка невинных случаев
    # («echo rm …» без кавычек) допустима — fail-closed, escape через ! prefix.
    rm_positions = [i for i, t in enumerate(toks) if t == "rm" or t.endswith("/rm")]
    for i in rm_positions:
        rest = toks[i + 1:]
        flags = [t for t in rest if t.startswith("-")]
        targets = [t for t in rest if not t.startswith("-")]
        recursive = any(
            t == "--recursive" or re.match(r'^-[a-zA-Z]*[rR]', t) for t in flags
        )
        if recursive and any(is_critical_target(t) for t in targets):
            deny("рекурсивное rm по корню/системному пути/домашней директории")

    # git push --force/-f без --force-with-lease/--force-if-includes
    if "git" in toks and "push" in toks:
        force = any(t in ("--force", "-f") for t in toks)
        lease = any(t.startswith("--force-with-lease") or t == "--force-if-includes" for t in toks)
        if force and not lease:
            deny("git push --force без --force-with-lease/--force-if-includes")

sys.exit(0)
PYEOF
