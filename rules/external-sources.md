# Внешние источники

## Что здесь есть кроме web

| Источник | Для чего |
|---|---|
| `ksrc` | сорсы JVM/Gradle зависимостей из локального Gradle cache, точная pinned-версия |
| `android docs search`/`fetch` | API truth и guides для Android/Jetpack/Compose/AGP/SDK |
| `~/.android/cli/skills/**/SKILL.md` | bundled Android CLI skills: миграции, Wear, XR, edge-to-edge, R8, Perfetto. Discovery — `android skills find <kw>` |
| `maven-mcp` + source jar | сорсы любой версии из Maven Central, включая не подключённую к проекту |
| Android Code Search (`cs.android.com`) | AOSP и androidx по веткам и версиям, плюс usages platform-API |
| grep.app, Sourcegraph public, GitHub code search | usages символа по всему OSS |

`WebFetch` по rendered GitHub-страницам не использовать — брать raw.

Список — seed для обнаружения, а не гарантия: доступность зависит от окружения (`ksrc` требует
Gradle cache, MCP могут быть не подключены, grep.app и Sourcegraph блокируются сетевой политикой).
Целый класс каналов недоступен — сказать это явно, чтобы сниженная уверенность была видимой.

Context7: один провал `resolve-library-id` — стоп, не гнаться за синонимами.

## Оценка доверия

Источник может быть формально primary, а содержимое — устаревшим, для другой версии или
галлюцинацией. Оценивать tier до того, как поверить.

| Tier | Что | Источники |
|---|---|---|
| **T1** ground truth | артефакт без интерпретации | `ksrc`, код проекта, official release artifact |
| **T2** official docs | вендорская документация, releases, changelogs | `android docs`, Context7 для официальных либ |
| **T3** aggregated/AI | может галлюцинировать | Context7 для community-либ без вендорской docs |
| **T4** random web | блоги, StackOverflow, туториалы | WebSearch, случайный WebFetch |

Tier принадлежит источнику, а не каналу: найденный через grep.app vendor-endorsed сэмпл — T1/T2,
случайный репо — T4.

**Память — не tier.** `MEMORY.md`, recalled facts и существующий код проекта фиксируют то, что было
верно на момент записи. Память — указатель «где смотреть», не факт.

**По умолчанию T1 + T2 параллельно** для любого Edit/Write с внешней библиотекой — базовый режим, а
не «при сомнении». T1-only допустим только с явным обоснованием: стабильная stdlib; уже виденный
символ на той же pinned-версии, подтверждённый `ksrc`; тривиальное использование. «Кажется
очевидным» обоснованием не является.

**Конфликты:** T1 vs T2 — следовать T1, отметить расхождение, при существенном gap предложить bump.
Два официальных расходятся — свежий changelog важнее старой docs-страницы; непонятно — поднять
вопрос, не выбирать молча.
