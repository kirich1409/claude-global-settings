# Верификация library API до написания кода

Обязательно перед Edit/Write кода с внешней библиотекой. Training data устаревает; код проекта —
только используемый срез API и может быть legacy или антипаттерном. Memorized signatures источником
не являются никогда.

**Три роли каналов дополняют друг друга, часто нужны параллельно:**

- **API truth** (сигнатуры, семантика, типы) — всегда при написании кода с библиотекой.
- **Guides** (рекомендуемые паттерны, миграции, troubleshooting) — для «как сделать X», незнакомого
  стека, нетривиальной интеграции.
- **Project style & versions** (стиль, pinned-версии, подключённые модули) — всегда, отдельным
  проходом поверх внешних каналов. Это **не** API truth.

**Композиция по стекам** (`→` = fallback внутри роли, не приоритет между ролями):

- **Android:** API truth = `ksrc` + `android docs` параллельно. Guides = `android docs` + bundled
  Android CLI skills параллельно. Fallback: Context7 → WebSearch.
- **JVM/Kotlin/KMP/Gradle:** API truth = `ksrc` → Context7 → WebSearch. Guides = Context7 →
  WebSearch. `ksrc` даёт только сорсы, для «как принято» нужен второй канал.
- **Frontend/JS/TS:** оба канала — Context7 → WebSearch.
- **Прочее (Python, Go, Rust, C#, Swift):** Context7 → WebSearch, плюс экосистемный аналог `ksrc`.

**High-staleness — оба канала обязательны:** Ktor 3.x, Room (KMP `@Upsert`, multiplatform),
SQLDelight, kotlinx.serialization, kotlinx.datetime, Hilt, Koin, Compose Multiplatform, Compose
Material3, AGP 8+/9, KSP, Firebase Android (BoM v34+ убрал KTX), Navigation 3.

## Reference implementations

Перед нетривиальной фичей искать референс-код проактивно, наравне с доками — это часть preparation
gate. Реальный код часто сильнее доков в роли Guides («как соединить X»: wiring, DI, слои). Для API
truth он остаётся supporting, T1 — это `ksrc` и официальный артефакт.

- **Стек-сэмплы**, vendor-endorsed → **T1/T2**: `android/nowinandroid`, `android/compose-samples`,
  `android/architecture-samples`, `JetBrains/compose-multiplatform` examples, Apple sample apps,
  `pointfreeco/isowords`, `shadcn-ui/taxonomy`.
- **Domain-OSS** — популярное OSS той же предметной сферы → **T3**: чужой intent, может нести
  конвенции команды и антипаттерны. Никогда не единственный источник.

**Discovery:** vendor-endorsed важнее всего остального; далее свежесть коммитов, release cadence,
динамика issues, «used by», репутация организации. Голые звёзды не сигнал. Domain-уровень: GitHub
topics (`sample-app`, `reference-architecture`), awesome-list'ы. Точечный поиск usages по коду —
каналы в [[external-sources]].

**Guardrails:**

- **Pointer, не embed** — ссылаться на `owner/repo` и путь, не копировать код в правила: иначе
  stale плюс раздувание контекста.
- **Version-proximity** — версия стека в референсе близка к версии проекта, иначе риск deprecated
  path, понизить вес.
- **Usage-slice** — один репо это один способ использования, а не эталон. Cross-check с T1/T2 до
  переноса паттерна.

## Быстро меняющийся декларативный UI

Для Jetpack Compose, Compose Multiplatform и SwiftUI мало проверить, какой API существует: нужно
ещё, как сейчас рекомендуется делать, иначе получается устаревший код (`NavigationView` вместо
`NavigationStack`, deprecated Compose API). Перед нетривиальным экраном пройти три шага.

**A. Какой API реально в версии проекта.** `ksrc` (T1, source jar точной версии; JVM/KMP, не Swift)
→ доки того же номера или Context7 (T2). SwiftUI: `apple-doc-mcp-server`, когда подключён —
ksrc-эквивалента для Apple нет.

**B. Как делают сейчас.** Официальные reference-приложения (код важнее доков, T1/T2) → What's New,
release notes, roadmap (Android Dev Blog, JetBrains Kotlin Blog, WWDC) и дизайн-канон (Compose API
Guidelines, Material 3, Apple HIG) → community (T3/T4, только для cross-check).

**C. Что изменилось.** `maven-mcp dependency-changes` — changelog между версиями (T2, самый богатый
сигнал для CMP). Issue-трекеры по правильному адресу: Jetpack Compose → Google IssueTracker, не
GitHub; CMP → GitHub issues `JetBrains/compose-multiplatform`; SwiftUI → Apple Developer Forums.

**Per-stack:**

- **Jetpack Compose** → `android docs` CLI + release notes и BOM + `ksrc`.
- **Compose Multiplatform** → core Compose выровнен с Jetpack Compose по major.minor (CMP 1.11.1 ↔
  JC runtime 1.11.2: minor совпадает, patch свой, CMP релизится позже). Но Material3 и навигация
  (`org.jetbrains.androidx.navigation:navigation-compose`) имеют собственную нумерацию, и KMP-форк
  может отставать от androidx upstream (KMP navigation 2.9.2 против androidx 2.9.8) — версию
  каждого артефакта проверять отдельно. CMP-специфика (iOS, Desktop, resources, `expect`/`actual`)
  — JetBrains KMP docs и GitHub release-таблицы.
- **SwiftUI** → `apple-doc-mcp-server` плюс Apple и WWDC; сайт Apple это SPA, raw WebFetch
  ненадёжен, предпочитать MCP.
