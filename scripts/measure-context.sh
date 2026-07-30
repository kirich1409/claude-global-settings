#!/usr/bin/env bash
# Замеряет always-on контекст ~/.claude: то, что попадает в каждую сессию до первого запроса.
# Всегда загружается: CLAUDE.md, rules/**/*.md без frontmatter `paths:`,
# плюс поля `description` из agents/*.md и skills/*/SKILL.md (листинг агентов и скиллов).
set -euo pipefail

ROOT="${CLAUDE_CONFIG_DIR:-$HOME/.claude}"
cd "$ROOT"

python3 - "$@" <<'PY'
import re, glob, os, sys

verbose = "-v" in sys.argv

def desc_bytes(pattern):
    total, rows = 0, []
    for p in sorted(glob.glob(pattern)):
        m = re.match(r"^---\n(.*?)\n---\n", open(p).read(), re.S)
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
        head = "".join(open(p).readlines()[:2])
        if head.startswith("---") and "paths:" in head:
            continue  # lazy: подгружается по совпадению пути
        n = os.path.getsize(p)
        total += n
        rows.append((n, p))
    return total, rows

claude_md = os.path.getsize("CLAUDE.md")
rules_total, rules_rows = always_on_rules()
skills_total, skills_rows = desc_bytes("skills/*/SKILL.md")
agents_total, agents_rows = desc_bytes("agents/*.md")

if verbose:
    for title, rows in (("rules", rules_rows), ("skills", skills_rows), ("agents", agents_rows)):
        print(f"--- {title}")
        for n, p in sorted(rows, reverse=True):
            print(f"{n:7d}  {p}")
        print()

grand = claude_md + rules_total + skills_total + agents_total
print(f"CLAUDE.md          {claude_md:7d} b   1 файл")
print(f"rules (always-on)  {rules_total:7d} b   {len(rules_rows)} файлов")
print(f"skills desc        {skills_total:7d} b   {len(skills_rows)} файлов")
print(f"agents desc        {agents_total:7d} b   {len(agents_rows)} файлов")
print(f"ИТОГО always-on    {grand:7d} b")
# Кириллица в токенизаторе Claude идёт дороже латиницы: оценка ~2,4 байта на токен,
# не путать с наивным b/4 для английского.
print(f"оценка токенов     ~{grand // 24 * 10 // 1000}k  (кириллица, ~2,4 b/token)")
PY
