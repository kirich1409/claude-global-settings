#!/usr/bin/env bash
# Замеряет always-on контекст харнеса Claude Code — то, что попадает в каждую сессию
# до первого сообщения пользователя.
#
#   measure-harness.sh [root] [-v] [--json]
#
#   root     корень харнеса; по умолчанию $CLAUDE_CONFIG_DIR или ~/.claude.
#            Для проектного харнеса передать <repo>/.claude
#   -v       разбивка по файлам
#   --json   машинный вывод для diff до/после
#
# Считаются слои, которые харнес инжектирует без запроса:
#   CLAUDE.md
#   rules/**/*.md без frontmatter `paths:`   (обход рекурсивный — подпапка не спасает)
#   поля description из agents/*.md          (листинг агентов)
#   поля description из skills/*/SKILL.md    (листинг скиллов)
#
# НЕ считаются: тела скиллов и агентов (грузятся при вызове), references/**,
# paths-scoped правила, settings.json, hooks. Их стоимость — в другом месте.
set -euo pipefail

ROOT=""
ARGS=()
for a in "$@"; do
  case "$a" in
    -v|--json) ARGS+=("$a") ;;
    *) ROOT="$a" ;;
  esac
done
ROOT="${ROOT:-${CLAUDE_CONFIG_DIR:-$HOME/.claude}}"
[ -d "$ROOT" ] || { echo "нет каталога харнеса: $ROOT" >&2; exit 1; }
cd "$ROOT"

python3 - "${ARGS[@]+"${ARGS[@]}"}" <<'PY'
import re, glob, os, sys, json

verbose = "-v" in sys.argv
as_json = "--json" in sys.argv

def descriptions(pattern):
    total, rows = 0, []
    for p in sorted(glob.glob(pattern)):
        m = re.match(r"^---\n(.*?)\n---\n", open(p, encoding="utf-8").read(), re.S)
        if not m:
            continue
        d = re.search(r"^description:\s*(.*?)(?=\n[a-zA-Z_-]+:|\Z)", m.group(1), re.S | re.M)
        n = len(d.group(1).encode()) if d else 0
        total += n
        rows.append((n, p))
    return total, rows

def always_on_rules():
    total, rows = 0, []
    for p in sorted(glob.glob("rules/**/*.md", recursive=True)):
        head = "".join(open(p, encoding="utf-8").readlines()[:2])
        if head.startswith("---") and "paths:" in head:
            continue  # lazy: подгружается по совпадению пути
        n = os.path.getsize(p)
        total += n
        rows.append((n, p))
    return total, rows

claude_md = os.path.getsize("CLAUDE.md") if os.path.exists("CLAUDE.md") else 0
rules_total, rules_rows = always_on_rules()
skills_total, skills_rows = descriptions("skills/*/SKILL.md")
agents_total, agents_rows = descriptions("agents/*.md")
grand = claude_md + rules_total + skills_total + agents_total

# Кириллица в токенизаторе Claude дороже латиницы: ~2,4 байта на токен против ~4.
# Наивное b/4 занижает русскоязычный харнес вдвое, поэтому делитель считается
# по доле не-ASCII байт в самом тексте.
nonascii = sampled = 0
sample = [p for _, p in rules_rows] + (["CLAUDE.md"] if claude_md else [])
for p in sample:
    b = open(p, "rb").read()
    nonascii += sum(1 for x in b if x > 127)
    sampled += len(b)
frac = nonascii / sampled if sampled else 0
bpt = 4.0 - 1.6 * min(frac / 0.6, 1.0)   # 4,0 для латиницы, ~2,4 для сплошной кириллицы

if as_json:
    print(json.dumps({
        "claude_md": claude_md,
        "rules": {"bytes": rules_total, "files": len(rules_rows)},
        "skills_desc": {"bytes": skills_total, "files": len(skills_rows)},
        "agents_desc": {"bytes": agents_total, "files": len(agents_rows)},
        "instructions_bytes": claude_md + rules_total,
        "total_bytes": grand,
        "est_tokens": int(grand / bpt),
    }, ensure_ascii=False, indent=2))
    sys.exit()

if verbose:
    for title, rows in (("rules (always-on)", rules_rows),
                        ("skills description", skills_rows),
                        ("agents description", agents_rows)):
        print(f"--- {title}")
        for n, p in sorted(rows, reverse=True):
            print(f"{n:7d}  {p}")
        print()

print(f"CLAUDE.md            {claude_md:7d} b   {1 if claude_md else 0} файл")
print(f"rules (always-on)    {rules_total:7d} b   {len(rules_rows)} файлов")
print(f"skills description   {skills_total:7d} b   {len(skills_rows)} файлов")
print(f"agents description   {agents_total:7d} b   {len(agents_rows)} файлов")
print(f"инструкции           {claude_md + rules_total:7d} b   (CLAUDE.md + rules)")
print(f"ИТОГО always-on      {grand:7d} b")
print(f"оценка токенов       ~{int(grand / bpt / 1000)}k   ({bpt:.1f} b/token, не-ASCII {frac:.0%})")
PY
