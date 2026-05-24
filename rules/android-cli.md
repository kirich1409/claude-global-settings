# Android CLI Rules

Google's `android` CLI (https://developer.android.com/tools/agents/android-cli) is an agent-oriented tool bundling official Android docs search/fetch, project metadata, AVD management, SDK packages, device screen/layout capture, and APK deploy. When available, it is the **primary** tool for Android-platform tasks.

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

## Priority versus existing tools

- **Android docs — две роли, обе primary, работают параллельно с `ksrc`:**
  - *Guides / recommended approaches / migrations / codelabs / training.* `android docs search` — единственный курируемый источник для «как принято делать X», «migration guide для Y», «best practice для Z». `ksrc` здесь не помогает — сорсы показывают что есть, а не как это применять. Триггер: любой Android-вопрос вида «как», «какой подход», «migration», «best practice», незнакомый компонент / API.
  - *API truth для Jetpack / Compose / AGP / SDK.* `android docs search` + `ksrc` запускаются **параллельно**, не «или/или»: `ksrc` даёт реальный API из source jar, `android docs` подтверждает текущую рекомендованную форму. Расхождение — сигнал что в проекте устаревшая версия или legacy-паттерн.
  - Context7 / DeepWiki / WebSearch / WebFetch — fallback **только** когда оба основных канала молчат. Не альтернатива им.
- **Device introspection**: `android layout` / `android screen` is primary over raw `adb shell uiautomator dump` / `adb exec-out screencap`. Drop to raw `adb` only when a needed flag is missing in the CLI.
- **SDK / AVD management**: `android sdk` / `android emulator` is primary over raw `sdkmanager` / `avdmanager` / `emulator`.
- **Build & deploy**: project's Gradle (`./gradlew assembleDebug`, `installDebug`) remains primary for the build itself. `android run` is preferred for the deploy-and-launch step when an APK already exists — it handles `--activity` / `--type` declaratively.
- **Project scaffolding**: `android create` only when the user explicitly asks for a fresh project. Never invoke during normal feature work.

## Hard rules

- **Never run `android init`** and **never run `android skills add --all`** automatically. Bundled skills (`migrate-xml-views-to-jetpack-compose`, `agp-9-upgrade`, `camera1-to-camerax`, `r8-analyzer`, `play-billing-library-version-upgrade`, `display-ai-glasses-with-jetpack-compose-glimmer`, `edge-to-edge`, `navigation-3`, `base`) overlap with existing global skills (`developer-workflow-kotlin:migrate-to-compose`, `kotlin-tooling-agp9-migration`, etc.) and would create skill-routing conflicts.
- **When the user explicitly asks for a specific Android-CLI skill**, install it scoped to Claude Code only: `android skills add --skill=<name> --agent=claude-code`. Verify the exact `--agent` value via the CLI's usage output before running.
- **Never auto-update**: if any CLI invocation prints "A new version of Android CLI is available" — surface a one-line notice to the user once per session and ask before running `android update`.
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

`android skills list` (and similar) emit a long ANSI progress bar before the result. When scripted (piped/captured), treat trailing non-progress lines as the payload. For interactive Bash use, output is fine as-is. A few subcommands (`info`, `sdk`, `init`, `skills`) do not support `--help` and print usage on error instead — invoke without args to see usage.
