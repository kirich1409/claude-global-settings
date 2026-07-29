# Верификация library API до написания кода

Обязательно перед Edit/Write кода с внешней библиотекой. Memorized signatures источником не
являются; код проекта — только используемый срез API и может быть legacy.

**Где брать API truth:**

- **Android** — `ksrc` + `android docs` параллельно; guides — `android docs` + bundled Android CLI skills.
- **JVM/Kotlin/KMP/Gradle** — `ksrc` даёт сорсы, но не «как принято»: для паттернов нужен второй канал.
- **Прочее** — Context7 → WebSearch, плюс экосистемный аналог `ksrc`.

**High-staleness — оба канала обязательны:** Ktor 3.x, Room (KMP `@Upsert`, multiplatform),
SQLDelight, kotlinx.serialization, kotlinx.datetime, Hilt, Koin, Compose Multiplatform, Compose
Material3, AGP 8+/9, KSP, Firebase Android (BoM v34+ убрал KTX), Navigation 3.

## Reference implementations

Перед нетривиальной фичей искать референс-код проактивно, наравне с доками: реальный код часто
сильнее доков в роли «как соединить X» — wiring, DI, слои. Для API truth он остаётся supporting.

- **Vendor-endorsed** → T1/T2: `android/nowinandroid`, `android/compose-samples`,
  `android/architecture-samples`, `JetBrains/compose-multiplatform` examples, Apple sample apps,
  `pointfreeco/isowords`, `shadcn-ui/taxonomy`.
- **Domain-OSS** той же предметной сферы → T3, никогда не единственный источник.

Ссылаться на `owner/repo` и путь, не копировать код в правила. Версия стека в референсе далеко от
версии проекта — понизить вес: риск deprecated path.

## Быстро меняющийся декларативный UI

Для Compose, CMP и SwiftUI мало проверить, какой API существует: нужно ещё, как сейчас
рекомендуется, иначе получается устаревший код. Официальные reference-приложения здесь важнее доков.

Адреса, которые легко перепутать:

- **Jetpack Compose** — issue-трекер Google IssueTracker, не GitHub. Версия — по BOM.
- **Compose Multiplatform** — core выровнен с Jetpack Compose по major.minor (CMP 1.11.1 ↔ JC
  runtime 1.11.2), но Material3 и навигация (`org.jetbrains.androidx.navigation:navigation-compose`)
  имеют собственную нумерацию, и KMP-форк может отставать от androidx upstream (KMP navigation 2.9.2
  против androidx 2.9.8) — версию каждого артефакта проверять отдельно. Issues — GitHub
  `JetBrains/compose-multiplatform`.
- **SwiftUI** — `apple-doc-mcp-server`, когда подключён: ksrc-эквивалента для Apple нет, а сайт
  Apple это SPA и raw `WebFetch` ненадёжен. Issues — Apple Developer Forums.
- **Changelog между версиями** — `maven-mcp dependency-changes`, самый богатый сигнал для CMP.
