# Каналы зависимостей JVM

Чем закрыты классы каналов из `~/.claude/references/external-sources.md` на этих машинах. Правило
безусловное намеренно: вопрос о JVM-библиотеке приходит и вне Gradle-проекта — исследование в пустом
каталоге, сравнение библиотек до выбора, ответ по координате без открытого билд-файла, — а
`paths:`-скоуп и указатель на справочник в таком запросе не срабатывают. Набор машинно-зависимый:
наличие проверять, отсутствующий канал называть вслух, а не подменять памятью.

| Класс канала | Чем закрыт | Форма вызова |
|---|---|---|
| Сорсы зависимости на pinned-версии | `ksrc` (CLI) | `ksrc search "<pattern>" --artifact <glob>` → `ksrc cat <file-id> --lines a,b` |
| Метаданные реестра: версия, CVE, лицензия, транзитивы, BOM, EOL | MCP `maven-mcp` | `get_latest_version`, `get_dependency_vulnerabilities`, `get_dependency_license`, `get_transitive_graph`, `expand_bom`, `get_eol_status` |
| Аудит зависимостей проекта (L1a) | MCP `maven-mcp` | `scan_project_dependencies`, `audit_project_dependencies`, `detect_dependency_conflicts` |

Жёстко:

- Исходники зависимости не искать грепом по `~/.gradle/caches`: file-id выдаёт `ksrc search` или
  `ksrc where`. Путь внутри jar начинается с имени source set (`commonMain/…`, `jvmMain/…`), поэтому
  собрать file-id по package нельзя — брать из вывода поиска.
- Последнюю версию, CVE и лицензию не брать из памяти и не идти WebFetch'ем на maven.org, пока
  канал реестра доступен.
- `ksrc` резолвит через Gradle: без `gradlew` в корне он берёт `gradle` с PATH и падает на
  несовместимости JDK. Тогда `--project <путь к модулю с wrapper>`, а не отказ от канала.
- **Вне проекта** канал реестра работает по одной координате (`get_latest_version`,
  `search_artifacts`, `get_dependency_vulnerabilities`, `get_dependency_health`, `get_eol_status`), а
  сорсы и аудит проекта — нет: им нужен резолв Gradle. Значит исследование библиотеки в пустом
  каталоге ведётся реестром, а API проверяется после того, как зависимость подключена.
