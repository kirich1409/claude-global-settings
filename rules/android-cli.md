---
paths:
  - "**/*.gradle.kts"
  - "**/*.gradle"
  - "**/AndroidManifest.xml"
  - "**/*.kt"
---

# Android CLI Rules

Google's `android` CLI (https://developer.android.com/tools/agents/android-cli) is the **primary** tool for Android-platform tasks — it bundles official docs search/fetch, project metadata, AVD/SDK management, device screen/layout capture, APK deploy, and bundled skills. Assume it is installed — it is standard on these machines. Rules tested against `v1.0.x` (~2026-05).

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

> Android Studio integration (`android studio *`) intentionally omitted — not used.

## Routing vs existing tools

Команды — в таблицах выше; здесь только когда `android` primary, а когда fallback.

- **Docs:** `android docs search` — единственный курируемый канал guides (как принято / migration / best practice). Для API truth — **параллельно с `ksrc`** (jar = реальный API, docs = рекомендованная форма; расхождение = legacy / устаревшая версия). Context7 / Web — fallback, когда оба молчат.
- **Bundled skills** (`~/.android/cli/skills/**/SKILL.md`, 19 шт, T2) — третий канал guides, **install не нужен**: `find <kw>` → `Read SKILL.md` → structured workflow (~10 шагов). Триггер: миграция / upgrade / узкая область (Wear M3, XR, CameraX, Navigation 3, edge-to-edge, Compose Styles/adaptive, R8, Perfetto, testing-setup, PBL, Engage, AppFunctions, XML→Compose, AGP 9). `last-updated` старше года в evolving стеке → понизить вес. **Не использовать**, когда глобальный Claude Code skill покрывает 1:1 (`agp-9-upgrade` ↔ `kotlin-tooling-agp9-migration`) — глобальный приоритетнее (routable, интегрирован с gates).
- **Device / SDK / AVD / screen / layout:** `android` primary над raw `adb` / `sdkmanager` / `avdmanager` / `emulator` — на raw только при отсутствующем флаге.
- **Build:** сама сборка — проектным Gradle; `android run` — только deploy-and-launch уже собранного APK.

## Hard rules

- **Skills: регистрация ≠ доступность.** Файлы уже на диске — `Read` работает всегда, проактивно. `android skills add` / `init` *регистрируют* skill в роутинге Skill tool — **только по явной просьбе** и когда нужно автосрабатывание по триггерам. **Never** авто `android init` / `skills add --all`: дублирует глобальные skills и ломает routing. Синтаксис: имя позиционное (`--skill=` удалён); флаги `--agent` / `--project` — проверять через usage, не угадывать.
- **Never auto-update:** на "A new version available" — одна строка раз в сессию, спросить перед `android update`. (`info`: `version` ядра vs `launcher_version` обёртки; лаг launcher нормален.)

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
- **`--help` quirks (v1.0):** groups `sdk`/`skills` (+ `skills` subcommands), `info`/`init`, and `screen capture` reject `--help` (`Unknown option`, but still print a usage line); the `screen` **group** `--help` errors out entirely (i/o error) — call `screen capture`/`screen resolve` directly. `docs`(+`search`/`fetch`), `emulator`, `create`, `describe`, `run`, `layout` accept `--help` normally. First invocation per session may prepend `Unpacking embedded installation…` noise.
