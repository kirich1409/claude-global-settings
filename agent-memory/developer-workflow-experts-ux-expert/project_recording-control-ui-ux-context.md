---
name: recording-control-ui-ux-context
description: UX-контекст эпика #42 (menu bar статус-айтем + popover) — повторяющиеся блокеры доступности и терминальных состояний
metadata:
  type: project
---

Эпик #42 `recording-control-ui` (Onset, macOS 26): персистентный menu bar `NSStatusItem` + rich SwiftUI popover, живой таймер, Carbon hotkey ⌘⌥⇧R, Dock-restore.

Рекуррентные UX-блокеры этой фичи (всплывают при ревью любой её итерации):

- **a11y-контракт popover** — выбор SwiftUI popover вместо `NSMenu` теряет бесплатный VoiceOver/клавиатуру. AC должны явно задавать: фокус-на-открытии, Tab-обход, Esc-закрытие, возврат фокуса на айтем, операбельность Stop/Finder с клавиатуры. TC-38 тестирует «popover-навигацию» — нужен соответствующий AC, иначе нефальсифицируемо. NFR-A11Y violation в этом проекте = critical.
- **`error` vs `done`** — AC-22 склеивает их в «нейтральный вид». `NotificationManager` отложен в #44 → при свёрнутом окне нет канала узнать про ошибку записи = silent-failure (NFR-ERR). `error` должен оставлять устойчивый признак в айтеме.
- **idle-персистентность (OQ#1)** — системный privacy-индикатор macOS 26 (Control Center, оранжевая точка во время захвата экрана) делает наш recording-индикатор частично избыточным (оправдан таймером+управлением). Слабое звено — idle-айтем: системного аналога нет, HIG no-clutter применим. Idle-popover content не определён.
- **Цветовая семантика** — red=наша запись, наш orange=деградация НЕ должен путаться с системным privacy-индикатором. Требует явного Decision, не research-риска.

**Why:** research `swarm-report/research/research-menubar-recording-status.md` отметил эти риски, но спека при разрешении не все их закрыла.
**How to apply:** при следующем ревью этой спеки/реализации сверять, закрыты ли эти 4 пункта; при ревью UI других фич Onset — те же NFR-A11Y/NFR-ERR пороги (a11y violation = critical, silent-failure = critical/major).
