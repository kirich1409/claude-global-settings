---
name: rules-android-cli
description: Обнаружение и использование Android CLI skills — применять при работе с Android/Gradle/KMP исходниками (.gradle, .gradle.kts, AndroidManifest.xml, .kt).
paths: **/*.gradle.kts, **/*.gradle, **/AndroidManifest.xml, **/*.kt
---

# Правила Android CLI

`android` CLI от Google (https://developer.android.com/tools/agents/android-cli) — **основной** инструмент для задач Android-платформы: поиск и загрузка официальной документации, метаданные проекта, управление AVD/SDK, захват экрана/макета устройства, деплой APK и bundled skills. Считать установленным — стандарт на этих машинах. Правила проверены на `v1.0.x` (~2026-05).

**Применять когда** `*.gradle*` ссылается на `com.android.{application,library,kotlin.multiplatform.library}`, или есть `AndroidManifest.xml` / `local.properties` с `sdk.dir`, или вопрос касается Android-платформы / SDK / Jetpack / Compose / AGP / tooling. В остальных случаях не применять.

**Доступность:** считать присутствующим. Если вызов `android` завершается ошибкой — один раз выполнить `command -v android`; при отсутствии использовать раздел Fallback и не повторять попытки `android` до конца сессии.

## Матрица решений

| Задача | Команда |
|------|---------|
| Поиск в документации Android / Jetpack / Compose / AGP / SDK | `android docs search "<query>"` |
| Загрузка страницы документации (URL из `docs search`) | `android docs fetch <url>` |
| Метаданные проекта (build targets, пути APK) | `android describe --project_dir=.` |
| UI-дерево живого устройства | `android layout --pretty` |
| Diff UI-дерева после действия | `android layout -d` |
| Скриншот устройства | `android screen capture -o <path>` |
| Визуальный выбор элемента (нет стабильного id) | `android screen capture -a`, затем `android screen resolve --screenshot <p> --string "tap on #3"` |
| Список AVD | `android emulator list` |
| Запуск / остановка / удаление AVD | `android emulator start <avd> [--cold]` / `stop` / `remove` |
| Создание AVD из профиля (watch / phone / XR…) | `android emulator create <profile>` (`--list-profiles` для перечисления) |
| Установка / обновление / удаление / список SDK-пакетов | `android sdk install|update|remove|list` |
| Деплой собранного APK | `android run --apks <p1,p2…> --activity <name> --device <id> [--debug]` — `--type` = тип компонента (ACTIVITY/SERVICE…), **не** build variant |
| Информация об окружении (SDK path, версия CLI) | `android info` |
| Scaffold нового проекта (только по явному запросу) | `android create [template] --name <n> --minSdk <v>` |
| Список / поиск bundled skills (только чтение) | `android skills list` / `android skills find <keyword>` |
| Чтение bundled skill как руководства (без установки) | `Read ~/.android/cli/skills/**/<skill-name>/SKILL.md` |
| Установка skill (маршрутизация через Skill tool; per-project с `--project=<path>`) | `android skills add <skill-name> --agent=<agent>` |

> Интеграция с Android Studio (`android studio *`) намеренно опущена — не используется.

## Маршрутизация vs существующие инструменты

Команды — в таблицах выше; здесь только когда `android` primary, а когда fallback.

- **Docs:** `android docs search` — единственный курируемый канал guides (как принято / migration / best practice). Для API truth — **параллельно с `ksrc`** (jar = реальный API, docs = рекомендованная форма; расхождение = legacy / устаревшая версия). Context7 / Web — fallback, когда оба молчат.
- **Bundled skills** (`~/.android/cli/skills/**/SKILL.md`, 19 шт, T2) — третий канал guides, **install не нужен**: `find <kw>` → `Read SKILL.md` → structured workflow (~10 шагов). Триггер: миграция / upgrade / узкая область (Wear M3, XR, CameraX, Navigation 3, edge-to-edge, Compose Styles/adaptive, R8, Perfetto, testing-setup, PBL, Engage, AppFunctions, XML→Compose, AGP 9). `last-updated` старше года в evolving стеке → понизить вес. **Не использовать**, когда глобальный Claude Code skill покрывает 1:1 (`agp-9-upgrade` ↔ `kotlin-tooling-agp9-migration`) — глобальный приоритетнее (routable, интегрирован с gates).
- **Device / SDK / AVD / screen / layout:** `android` primary над raw `adb` / `sdkmanager` / `avdmanager` / `emulator` — на raw только при отсутствующем флаге.
- **Build:** сама сборка — проектным Gradle; `android run` — только deploy-and-launch уже собранного APK.

## Жёсткие правила

- **Skills: регистрация ≠ доступность.** Файлы уже на диске — `Read` работает всегда, проактивно. `android skills add` / `init` *регистрируют* skill в роутинге Skill tool — **только по явной просьбе** и когда нужно автосрабатывание по триггерам. **Никогда** авто `android init` / `skills add --all`: дублирует глобальные skills и ломает routing. Синтаксис: имя позиционное (`--skill=` удалён); флаги `--agent` / `--project` — проверять через usage, не угадывать.
- **Никогда авто-обновление:** на "A new version available" — одна строка раз в сессию, спросить перед `android update`. (`info`: `version` ядра vs `launcher_version` обёртки; лаг launcher нормален.)

## Fallback при отсутствии CLI

Крайний случай (CLI отсутствует на машине). Уведомить один раз: "Android CLI not installed — установить по URL в документации, или продолжаем с fallback." Затем:

| Задача | Fallback |
|------|----------|
| Документация | Context7 (`resolve-library-id`) → WebSearch по `developer.android.com` → WebFetch страницы |
| Метаданные проекта | Read `app/build.gradle*` / `settings.gradle*`; `ksrc` для исходников зависимостей |
| Макет / скриншот | `adb shell uiautomator dump` + `adb pull /sdcard/window_dump.xml` / `adb exec-out screencap -p > shot.png` |
| SDK / Emulator | `$ANDROID_HOME/cmdline-tools/latest/bin/sdkmanager` / `$ANDROID_HOME/emulator/emulator -list-avds`, `avdmanager` |
| Деплой | `./gradlew :app:installDebug`, затем `adb shell am start -n <pkg>/<activity>` |

## Операционные заметки

- `android skills list` (и аналоги) выводят длинный ANSI progress bar перед результатом — при piped/captured обработке считать полезной нагрузкой только строки после прогресс-бара.
- **Особенности `--help` (v1.0):** группы `sdk`/`skills` (+ подкоманды `skills`), `info`/`init` и `screen capture` отклоняют `--help` (`Unknown option`, но всё же выводят строку usage); **группа** `screen` с `--help` падает полностью (i/o error) — вызывать `screen capture`/`screen resolve` напрямую. `docs`(+`search`/`fetch`), `emulator`, `create`, `describe`, `run`, `layout` принимают `--help` штатно. При первом вызове за сессию возможна преамбула `Unpacking embedded installation…`.
