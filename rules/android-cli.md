---
paths:
  - "**/*.gradle.kts"
  - "**/*.gradle"
  - "**/AndroidManifest.xml"
  - "**/*.kt"
---

# Android CLI Rules

Google's `android` CLI (https://developer.android.com/tools/agents/android-cli) is the **primary** tool for Android-platform tasks — it bundles official docs search/fetch, project metadata, AVD/SDK management, device screen/layout capture, APK deploy, bundled skills, and (v1.0+) IPC to a running Android Studio (Compose preview render, find-declaration/usages, file analysis, version lookup). Assume it is installed — it is standard on these machines. Rules tested against `v1.0.x` (~2026-05).

**Applies when** a `*.gradle*` references `com.android.{application,library,kotlin.multiplatform.library}`, or there's an `AndroidManifest.xml` / `local.properties` with `sdk.dir`, or the question is about the Android platform / SDK / Jetpack / Compose / AGP / tooling. Silent otherwise.

**Availability:** assume present. Only if an `android` call errors, probe `command -v android` once; on miss, use the Fallback section and do not retry `android` for the rest of the session.

## Decision matrix

| Task | Command |
|------|---------|
| Search Android / Jetpack / Compose / AGP / SDK docs | `android docs search "<query>"` |
| Fetch a doc page (url returned by `docs search`) | `android docs fetch <url>` |
| Project metadata (build targets, APK output paths) | `android describe --project_dir=.` |
| Live device UI tree | `android layout --pretty` |
| UI tree diff after action | `android layout -d` |
| Device screenshot | `android screen capture -o <path>` |
| Visual UI element targeting (no stable id) | `android screen capture -a` then `android screen resolve --screenshot <p> --string "tap on #3"` |
| List AVDs | `android emulator list` |
| Start / stop / remove AVD | `android emulator start <avd> [--cold]` / `stop` / `remove` |
| Create AVD from a profile (watch / phone / XR…) | `android emulator create <profile>` (`--list-profiles` to enumerate) |
| SDK package install / update / remove / list | `android sdk install|update|remove|list` |
| Deploy a built APK | `android run --apks <p1,p2…> --activity <name> --device <id> [--debug]` — `--type` = component type (ACTIVITY/SERVICE…), **not** build variant |
| Environment info (SDK path, CLI version) | `android info` |
| New project scaffold (only on explicit request) | `android create [template] --name <n> --minSdk <v>` |
| List / find bundled skills (read-only) | `android skills list` / `android skills find <keyword>` |
| Read a bundled skill as guidance (no install) | `Read ~/.android/cli/skills/**/<skill-name>/SKILL.md` |
| Install a skill (routing via Skill tool; per-project with `--project=<path>`) | `android skills add <skill-name> --agent=<agent>` |

### Android Studio integration (v1.0+, requires Studio Quail 1+ running)

Commands connect to a running Studio over IPC. Run `android studio check` first to discover `<pid>`/`<project>`; pass `--pid=<pid>` when >1 Studio runs, `--project=<name|path>` when >1 project is open. Older channels (Meerkat/Ladybug/Koala/Narwhal) don't expose the endpoint — `check` returns *No running Studio instances found*.

| Task | Command |
|------|---------|
| Probe running Studio instances and their projects | `android studio check` |
| Open a file in Studio | `android studio open-file <path> [--project=<name>]` |
| Go to declaration / find usages of a symbol | `android studio find-declaration <symbol> [--context-file=<f>] [--short]` / `find-usages <symbol>` (`--context-file` disambiguates overloads) |
| Run inspections on a file (Lint + code analysis) | `android studio analyze-file <path> [--project=<name>]` |
| Render a `@Preview` composable + a11y semantics tree | `android studio render-compose-preview <file> <composable> [--output-image-file=<png>] [--print-semantics]` |
| Latest stable+preview versions, space-separated ids | `android studio version-lookup <id...>` — ids: `group:artifact`, Gradle pluginId, `gradle` `studio` `agp` `kotlin` `compose` `ndk` `sdk` `emulator` `adb` `android`(platform) `platform-tools` `cmdline-tools` `build-tools` |

## Priority versus existing tools

- **Android docs — primary, две роли, параллельно с `ksrc`:** `android docs search` — единственный курируемый источник для guides (как принято / migration / best practice; триггер: «как», «какой подход», «migration», незнакомый компонент). Для API truth `android docs` + `ksrc` гоняются **параллельно** (jar даёт реальный API, docs — текущую рекомендованную форму; расхождение = устаревшая версия / legacy в проекте). Context7 / WebSearch / WebFetch — fallback только когда оба молчат.
- **Bundled skills — третий primary канал guides.** 19 markdown-файлов в `~/.android/cli/skills/**/SKILL.md` (frontmatter: `name`, `description`, `keywords`, `last-updated`, `author: Google LLC`). Использование как guidance **install не требует** — `Read` напрямую. Pattern: `android skills find <keyword>` → выбрать → `Read SKILL.md` → следовать structured workflow (типично 10 шагов). Триггер: миграция / upgrade / узкая область (Wear M3, XR Glimmer, CameraX, Navigation 3, edge-to-edge, Compose Styles/adaptive, R8, Perfetto, testing-setup, PBL, Engage SDK, AppFunctions, XML→Compose, AGP 9). Tier T2; `last-updated` старше года в evolving стеке → понизить вес. Запускать параллельно с `android docs search` (skills = end-to-end workflow области, docs = точечные references). **Не используется**, когда глобальный Claude Code skill покрывает задачу 1:1 (`migrate-xml-views-to-jetpack-compose` ↔ `developer-workflow-kotlin:migration`, `agp-9-upgrade` ↔ `kotlin-tooling-agp9-migration`) — глобальный имеет приоритет (routable через Skill tool, интегрирован с workflow gates).
- **Device / SDK / AVD:** `android layout` / `android screen` / `android sdk` / `android emulator` — primary над raw `adb` / `sdkmanager` / `avdmanager` / `emulator`. Падать на raw только при отсутствующем флаге.
- **Build & deploy:** проектный Gradle (`./gradlew assembleDebug`, `installDebug`) — primary для самой сборки. `android run` — для deploy-and-launch уже собранного APK: `--apks` (CSV), `--activity`, `--device`, булев `--debug`; `--type` = тип компонента (ACTIVITY/SERVICE…), **не** build variant.
- **Scaffolding:** `android create` — только по явной просьбе, никогда в обычной работе.
- **Studio integration vs существующие инструменты:** `find-declaration` / `find-usages` — **fallback** (default `ast-index` → LSP; `studio` только если он уже открыт И нужен Studio-индекс: KSP-генерация, cross-module refs, что ast-index/LSP не разрешает). `version-lookup` — **fallback** для `maven-mcp:latest-version` (maven-mcp standalone, остаётся primary; `version-lookup` — когда нужна сводка по не-Maven id `agp`+`kotlin`+`compose`+`gradle`+`sdk` сразу и Studio запущен). `analyze-file` — **fallback** для `./gradlew lint` (Gradle lint primary, детерминирован, в CI; `analyze-file` — для полных IDE-инспекций при открытом Studio). `render-compose-preview` — **primary**, аналога нет (рендер `@Preview` без эмулятора + опц. semantics tree для assertion-based UI-теста). `open-file` — convenience, только по явной просьбе.

## Hard rules

- **Read-only discovery всегда разрешён** проактивно при Android-задачах: `android skills list` / `find`, `Read ~/.android/cli/skills/**/SKILL.md`.
- **Never auto-run `android init` или `android skills add --all`.** Эти команды *регистрируют* skills в available-skills агента (роутинг), а не «делают доступными» — на диске они уже есть. Массовая регистрация создаёт дубли с глобальными skills и ломает routing.
- **`android skills add <name>` — только по явной просьбе** и только когда нужен именно роутинг через Skill tool (автосрабатывание по триггерам). Для разового использования — `Read` достаточно. Синтаксис v1.0: имя **позиционное** (флаг `--skill=` удалён), `--project=<path>` для per-project. Значение `--agent` (`CLAUDE`/`GEMINI`/`CODEX`) проверять через usage output, не угадывать.
- **`studio *` требует пробы:** перед первой `android studio <cmd>` в сессии — `android studio check`. *No running Studio instances found* → не повторять, одной строкой сказать пользователю про необходимость Studio **Quail 1+**, использовать fallback.
- **Never auto-update:** на "A new version of Android CLI is available" — одна строка пользователю раз в сессию, спросить перед `android update`. (`android info` показывает два поля: `version` ядра и `launcher_version` обёртки; лаг launcher за ядром нормален, сам по себе не повод обновляться.)

## Fallback when CLI is missing

Edge case (CLI отсутствует на машине). Notify once: "Android CLI not installed — install per the docs URL, or proceeding with fallbacks." Then:

| Task | Fallback |
|------|----------|
| Documentation | Context7 (`resolve-library-id`) → WebSearch on `developer.android.com` → WebFetch the page |
| Project metadata | Read `app/build.gradle*` / `settings.gradle*`; `ksrc` for dep sources |
| Layout / screenshot | `adb shell uiautomator dump` + `adb pull /sdcard/window_dump.xml` / `adb exec-out screencap -p > shot.png` |
| SDK / Emulator | `$ANDROID_HOME/cmdline-tools/latest/bin/sdkmanager` / `$ANDROID_HOME/emulator/emulator -list-avds`, `avdmanager` |
| Deploy | `./gradlew :app:installDebug` then `adb shell am start -n <pkg>/<activity>` |

## Operational notes

- `android skills list` (and similar) emit a long ANSI progress bar before the result — when piped/captured, treat trailing non-progress lines as the payload.
- **`--help` quirks (v1.0):** groups `sdk`/`skills` (+ `skills` subcommands), `info`/`init`, and `screen capture` reject `--help` (`Unknown option`, but still print a usage line); the `screen` **group** `--help` errors out entirely (i/o error) — call `screen capture`/`screen resolve` directly. `docs`(+`search`/`fetch`), `emulator`, `studio` (+ subcommands), `create`, `describe`, `run`, `layout` accept `--help` normally. First invocation per session may prepend `Unpacking embedded installation…` noise.
