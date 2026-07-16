#!/bin/bash
# Secret-read guard (PreToolUse: Bash) — блокирует команды, ссылающиеся на секретные пути.
#
# Зачем: deny-правила Read(./.env, ~/.ssh/**, …) закрывают инструмент Read, но
# разрешённые Bash-ридеры (cat/head/tail/grep/sed/…) читают те же файлы в обход,
# а curl --data @.env может их экфильтровать. Guard зеркалит deny-список Read
# из settings.json на уровне Bash-команд: секреты не попадают ни в контекст, ни в сеть.
#
# Fail-open по инфраструктуре (нет python3 / нечитаемый JSON → пропустить),
# fail-closed по совпадению паттерна. Ложное срабатывание (например,
# `docker compose --env-file .env up`) — пользователь запускает команду сам
# (`! <cmd>` в промпте) или корректирует PATTERNS ниже.

INPUT=$(cat)

if ! command -v python3 >/dev/null 2>&1; then
    echo "WARN: python3 not found — secret-read-guard cannot parse tool input, skipping check" >&2
    exit 0
fi

# Payload через env: heredoc занимает stdin python3 под сам скрипт (как в push-branch-guard).
SECRET_GUARD_INPUT="$INPUT" python3 - <<'PYEOF'
import json, os, re, sys

try:
    payload = json.loads(os.environ.get("SECRET_GUARD_INPUT") or "{}")
except Exception:
    sys.exit(0)

cmd = (payload.get("tool_input") or {}).get("command") or ""
if not cmd:
    sys.exit(0)

# (regex, что зацепило) — зеркало deny-списка Read в settings.json.
# Дотфайл .env (не production.env), корневой secrets/ (не src/secrets/) — та же
# семантика, что у Read(./.env*) и Read(./secrets/**).
PATTERNS = [
    (r'(^|[\s"\'`=@:/(])\.env(\.[\w.-]+)?($|[\s"\'`);|&<>])', "файл .env*"),
    (r'(^|[\s"\'`=@:])(\./)?secrets/', "каталог secrets/"),
    (r'(~|\$HOME|/Users/[^/\s]+|/home/[^/\s]+)/\.(ssh|aws|gnupg|kube)($|[/\s"\'`;|&)])',  # validate-config: allow
     "~/.ssh, ~/.aws, ~/.gnupg, ~/.kube"),
    (r'\bid_(rsa|ed25519|ecdsa|dsa)\b', "приватный SSH-ключ"),
    (r'\.(pem|p12|pfx)($|[\s"\'`;|&)])', "ключ/сертификат (*.pem/*.p12/*.pfx)"),
    (r'\.key($|[\s"\'`;|&)])', "ключ (*.key)"),
    (r'\.credentials\.json', ".credentials.json"),
]

for pattern, label in PATTERNS:
    if re.search(pattern, cmd):
        sys.stderr.write(
            "SECRET-GUARD: команда ссылается на секретный путь (%s) — заблокировано.\n"
            "Deny-правила Read зеркалируются на Bash: секреты не читаются и не передаются наружу.\n"
            "Ложное срабатывание → пользователь выполняет команду сам (! prefix) "
            "или правит hooks/secret-read-guard.sh.\n"
            "Команда: %s\n" % (label, cmd)
        )
        sys.exit(2)

sys.exit(0)
PYEOF
