# Android CLI Rules

Google's `android` CLI (https://developer.android.com/tools/agents/android-cli) is an agent-oriented tool bundling official Android docs search/fetch, project metadata, AVD management, SDK packages, device screen/layout capture, APK deploy, and (v1.0+) integration with a running Android Studio instance (Compose preview render, find-declaration / find-usages, file analysis, version lookup). When available, it is the **primary** tool for Android-platform tasks.

Rules tested against Android CLI `v1.0.x` (released ~2026-05). The `studio *` subgroup requires Android Studio **Quail 1** or newer running locally — older stable channels (Meerkat / Ladybug / Koala / Narwhal) do not expose the IPC endpoint and `android studio check` returns *No running Studio instances found*.

## Scope

Applies when **any** of the following hold:
- Project has `*.gradle*` files referencing `com.android.application`, `com.android.library`, or `com.android.kotlin.multiplatform.library`.
- Project contains `AndroidManifest.xml` or a `local.properties` with `sdk.dir`.
- User question is about the Android platform / SDK / Jetpack / Compose / AGP / Android tooling.

For non-Android tasks this rule is silent.

## Availability check

On first relevant invocation per session: run `command -v android`. Cache the result for the session — do not re-probe. Two branches: **available** → use the decision matrix below. **Not available** → use the fallback section once, then stop trying `android`.

## Decision matrix (CLI available)

| Task | Command |
|------|---------|
| Search Android / Jetpack / Compose / AGP / SDK docs | `android docs search "<query>"` |
| Fetch a doc page | `android docs fetch <url>` |
| Project metadata (build targets, APK output paths) | `android describe --project_dir=.` |
| Live device UI tree | `android layout --pretty` |
| UI tree diff after action | `android layout -d` |
| Device screenshot | `android screen capture -o <path>` |
| Visual UI element targeting (no stable id) | `android screen capture -a` then `android screen resolve --screenshot <p> --string "tap on #3"` |
| List AVDs | `android emulator list` |
| Start / stop / create / remove AVD | `android emulator start|stop|create|remove` |
| SDK package install / update / remove / list | `android sdk install|update|remove|list` |
| Deploy a built APK | `android run --apks <path> --activity <name> --type <debug\|release> --device <id>` |
| Environment info (SDK path, CLI version) | `android info` |
| New project scaffold (only on explicit request) | `android create [template] --name <n> --minSdk <v>` |
| List bundled skills (read-only) | `android skills list` |
| Find a bundled skill (read-only) | `android skills find <keyword>` |
| Read a bundled skill as guidance (no install) | `Read ~/.android/cli/skills/**/<skill-name>/SKILL.md` |
| Install a specific skill — только для роутинга через Skill tool | `android skills add <skill-name> --agent=<agent>` |
| Install a specific skill (per-project) | `android skills add <skill-name> --agent=<agent> --project=<path>` |

### Android Studio integration (v1.0+, requires Studio Quail 1+ running)

All commands below connect to a running Android Studio instance over IPC. First run `android studio check` to discover available `<pid>` / `<project>` values; pass `--pid=<pid>` when more than one Studio is running and `--project=<name|path>` when more than one project is open.

| Task | Command |
|------|---------|
| Probe running Studio instances and their projects | `android studio check` |
| Open a file in Studio | `android studio open-file <path> [--project=<name>]` |
| Go to declaration of a symbol | `android studio find-declaration <args>` |
| Find usages of a symbol | `android studio find-usages <args>` |
| Run Studio inspections on a file (Lint + code analysis) | `android studio analyze-file <path> [--project=<name>]` |
| Render a `@Preview` composable + accessibility semantics tree | `android studio render-compose-preview <file> <composable> [--output-image-file=<png>] [--print-semantics]` |
| Latest stable+preview version of Maven artifact / AGP / Kotlin / Compose BOM / Gradle / NDK / SDK / Studio | `android studio version-lookup <id...>` (e.g. `androidx.window:window agp kotlin compose`) |

## Priority versus existing tools

- **Android docs — две роли, обе primary, работают параллельно с `ksrc`:**
  - *Guides / recommended approaches / migrations / codelabs / training.* `android docs search` — единственный курируемый источник для «как принято делать X», «migration guide для Y», «best practice для Z». `ksrc` здесь не помогает — сорсы показывают что есть, а не как это применять. Триггер: любой Android-вопрос вида «как», «какой подход», «migration», «best practice», незнакомый компонент / API.
  - *API truth для Jetpack / Compose / AGP / SDK.* `android docs search` + `ksrc` запускаются **параллельно**, не «или/или»: `ksrc` даёт реальный API из source jar, `android docs` подтверждает текущую рекомендованную форму. Расхождение — сигнал что в проекте устаревшая версия или legacy-паттерн.
  - Context7 / DeepWiki / WebSearch / WebFetch — fallback **только** когда оба основных канала молчат. Не альтернатива им.
- **Bundled Android skills как guidance (без install) — третий primary канал для Android guides:**
  - **Где живут.** Все skills бандлятся с CLI в `~/.android/cli/skills/**/SKILL.md` (19 штук на v1.0). Файлы — обычные markdown с YAML frontmatter (`name`, `description`, `keywords`, `last-updated`, `author: Google LLC`). Установка для использования как guidance **не нужна** — `Read` работает напрямую.
  - **Discovery → Read pattern.** Триггер: миграция / upgrade / незнакомая узкая область Android (Wear M3, XR Glimmer, CameraX, Navigation 3, edge-to-edge, Compose Styles/adaptive, R8, Perfetto, testing-setup, PBL, Engage SDK, AppFunctions, XML→Compose, AGP 9). Шаги: `android skills find <keyword>` для списка кандидатов с описаниями → выбрать релевантный → `Read ~/.android/cli/skills/**/<name>/SKILL.md` → использовать как structured workflow (типично 10 steps: planning → dependency setup → migration → validation → cleanup).
  - **Tier:** T2 (official curated docs от Google). Содержат конкретные snippets, dependency-блоки, версии. Метаданные `last-updated` в frontmatter — использовать для freshness check (старше года в evolving стеке → понизить вес).
  - **Параллельно с `android docs search`.** Skills дают **end-to-end workflow для области**; `android docs search` — точечные guides и API references. На незнакомой задаче запускать оба канала.
  - **Не используется когда:** глобальный Claude Code skill уже покрывает задачу один-в-один (`migrate-xml-views-to-jetpack-compose` ↔ `developer-workflow-kotlin:migration`, `agp-9-upgrade` ↔ `kotlin-tooling-agp9-migration`) — глобальный имеет приоритет, потому что routable через Skill tool и интегрирован с workflow gates.
- **Device introspection**: `android layout` / `android screen` is primary over raw `adb shell uiautomator dump` / `adb exec-out screencap`. Drop to raw `adb` only when a needed flag is missing in the CLI.
- **SDK / AVD management**: `android sdk` / `android emulator` is primary over raw `sdkmanager` / `avdmanager` / `emulator`.
- **Build & deploy**: project's Gradle (`./gradlew assembleDebug`, `installDebug`) remains primary for the build itself. `android run` is preferred for the deploy-and-launch step when an APK already exists — it handles `--activity` / `--type` declaratively.
- **Project scaffolding**: `android create` only when the user explicitly asks for a fresh project. Never invoke during normal feature work.
- **Studio integration vs существующие инструменты (v1.0+):**
  - `android studio find-declaration` / `find-usages` — **fallback**, не primary. Default остаётся `ast-index` (быстро, не требует IDE) → LSP (когда нужна type-resolution и язсервер есть). `android studio` использовать только если Studio уже открыт с этим проектом **и** запрос реально требует Studio-индекса (KSP-сгенерированные символы, cross-module references, которые ast-index/LSP не разрешает).
  - `android studio version-lookup` — **fallback** для `maven-mcp:latest-version`. `maven-mcp` standalone и не требует Studio, поэтому остаётся primary для `latest-version` / `check-deps` / vulnerability сканов. `version-lookup` использовать только когда нужна сводка по «не-Maven» идентификаторам в одном запросе (`agp` + `kotlin` + `compose` + `gradle` + `sdk` сразу) и Studio уже запущен.
  - `android studio analyze-file` — **fallback** для `./gradlew lint <module>`. Gradle lint — primary (детерминирован, в CI). `analyze-file` использовать когда нужны полные IDE-инспекции (включая non-Lint, например `kotlin-inspections`), а Studio уже открыт.
  - `android studio render-compose-preview` — **primary**, аналога нет. Рендерит `@Preview` без запуска эмулятора, опционально печатает semantics tree для агентского assertion-based UI-теста. Использовать когда нужно подтвердить визуал отдельного композаблa быстрее, чем через `manual-tester` + emulator.
  - `android studio open-file` — convenience, не блокер. Использовать только когда user явно просит «открой файл в Studio».
  - **Проба перед использованием.** Перед первым вызовом любой `studio *` команды в сессии выполнить `android studio check`. Если вернулось *No running Studio instances found* — не пытаться повторно, использовать fallback (или сказать пользователю, что нужно запустить Quail 1+).

## Hard rules

- **Read-only discovery всегда разрешён.** `android skills list`, `android skills find <keyword>`, и `Read ~/.android/cli/skills/**/SKILL.md` — безопасные операции без побочных эффектов, можно вызывать проактивно при Android-задачах для discovery подходящего workflow.
- **Never run `android init`** and **never run `android skills add --all`** automatically. Эти команды *регистрируют* skills в available-skills агента (роутинг через Skill tool), а не «делают их доступными» — на диске они уже есть. Массовая регистрация создаёт дубли с существующими глобальными skills (`developer-workflow-kotlin:migration`, `kotlin-tooling-agp9-migration`, и т. п.) и конфликтует с routing'ом.
- **`android skills add <name>` — только по явной просьбе пользователя**, и только когда нужен именно роутинг через Skill tool (skill должен автоматически срабатывать по триггерам). Для разового использования skill как guidance install не нужен — `Read` файла достаточно. Синтаксис v1.0: `android skills add <skill-name> --agent=<agent>` (имя skill **позиционное**, флаг `--skill=` удалён). `--project=<path>` для per-project установки. Значение `--agent` (`CLAUDE`, `GEMINI`, `CODEX`) проверять через usage output, не угадывать.
- **`studio *` commands require a probe.** Before invoking any `android studio <cmd>` in a session, run `android studio check`. If it returns *No running Studio instances found* — do not retry; surface to the user (one line) that Android Studio **Quail 1+** must be running, and fall back per the matrix above.
- **Never auto-update**: if any CLI invocation prints "A new version of Android CLI is available" — surface a one-line notice to the user once per session and ask before running `android update`. Note: in v1.0 `android info` exposes two version fields (`version` for the core, `launcher_version` for the wrapper) — a launcher lag behind the core is normal and not by itself a reason to update.
- **Do not retry `android` after one negative `command -v` in the same session.** Use the fallback path until the user confirms installation.

## Fallback when CLI is missing

Notify the user once: "Android CLI not installed. Install per https://developer.android.com/tools/agents/android-cli, or proceeding with fallbacks." Then route as below:

| Task | Fallback |
|------|----------|
| Documentation | Context7 (`resolve-library-id` for the relevant Jetpack lib) → DeepWiki for `androidx/*` GitHub repos → WebSearch on `developer.android.com` → WebFetch the specific page |
| Project metadata | Read `app/build.gradle*` and `settings.gradle*` directly; `ksrc` for dependency sources |
| Layout dump | `adb shell uiautomator dump` + `adb pull /sdcard/window_dump.xml` |
| Screenshot | `adb exec-out screencap -p > shot.png` |
| SDK packages | `$ANDROID_HOME/cmdline-tools/latest/bin/sdkmanager` |
| Emulator | `$ANDROID_HOME/emulator/emulator -list-avds`, `emulator -avd <name>`, `avdmanager` for create/delete |
| Deploy | `./gradlew :app:installDebug` then `adb shell am start -n <pkg>/<activity>` |

## Output handling note

`android skills list` (and similar) emit a long ANSI progress bar before the result. When scripted (piped/captured), treat trailing non-progress lines as the payload. For interactive Bash use, output is fine as-is.

**`--help` quirks (v1.0):** the top-level groups `sdk` and `skills`, plus all `skills` subcommands (`add`, `remove`, `list`, `find`), and the standalone `info` / `init` commands do **not** accept `--help` — they print `Unknown option: '--help'` and a usage line. Invoke without args to see usage. By contrast, `docs`, `emulator`, `screen`, `studio`, `create`, `describe`, `run`, `layout` and all of their subcommands do accept `--help` normally.
