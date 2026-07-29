---
paths:
  - "**/*.swift"
---

# SwiftUI Design System — неочевидное

## Устаревшие формы из training-данных

| Запрещено | Вместо |
|---|---|
| модификатор `.accentColor(_:)` | `.tint(_:)` плюс asset `AccentColor` |
| `RoundedRectangle(cornerRadius: 8)` | `.clipShape(.rect(cornerRadius: ..., style: .continuous))` |

## Не токенизировать

- **Тень** — на macOS использовать `Material`; на iOS держать 2–3 уровня elevation, не изобретать
  шкалу теней.
- **Прозрачность** — `.foregroundStyle(.secondary)` / `.tertiary` / `.quaternary` вместо токена
  opacity.
- **Насыщенность шрифта отдельными токенами** — применять `.fontWeight(.semibold)` прямо к стилю.

Теминг: статичный enum для примитивов, не меняющихся в runtime (spacing, radius, motion,
typography); семантические системные цвета для адаптивных цветов — они сами обрабатывают light,
dark и HCR; struct через environment только когда пользователь выбирает палитру в runtime.

## Environment не пересекает Scene

Значения `@Environment` не распространяются между `Scene` автоматически. Каждый `WindowGroup`,
`Window`, `Settings`, `MenuBarExtra` внедряет тему и зависимости в корне своей scene — иначе второе
окно падает или показывает дефолты.

```swift
WindowGroup { RootView().environment(\.theme, store.theme) }
Settings    { SettingsView().environment(\.theme, store.theme) }
```

## macOS 26+ / Liquid Glass

- Пересборка с Xcode 26 применяет Liquid Glass к toolbar, sheet, popover, sidebar
  `NavigationSplitView` и scene `Settings` автоматически, opt-in не нужен.
- **Никогда на monospaced canvas** (терминал, редактор кода) — текст деградирует под рефракцией.
  Для фона окна использовать `.containerBackground(.thinMaterial, for: .window)`.
- `.glassEffect(_:in:isEnabled:)`, `GlassEffectContainer`, `.glassEffectID(_:in:)` — только для
  плавающего UI: командная палитра, плавающие кнопки.

## Dynamic Type на macOS

macOS в основном игнорирует Dynamic Type: `@ScaledMetric` и `.dynamicTypeSize` применяются слабо или
не применяются вовсе. Писать Dynamic-Type-ready форму всё равно, но не полагаться на неё для
user-facing масштабирования на macOS canvas. Для content-canvas, где масштабирование важно
(терминал, редактор), реализовать предпочтение масштаба на уровне приложения (`⌘+` / `⌘−`) и
передавать коэффициент явно.

## Прочее

- **Сигнал только цветом не работает.** Сочетать цвет с SF Symbol
  (`exclamationmark.triangle.fill`, `checkmark.circle.fill`), реагировать на
  `@Environment(\.accessibilityDifferentiateWithoutColor)`.
- Клавиатурные шорткаты на основных действиях sheet и формы: `⌘Return` подтвердить, `⌘.` отменить.
- Матрица превью переиспользуемого компонента: светлая и тёмная тема, Increase Contrast (и Dark
  HCR), Reduce Transparency, Dynamic Type на `.xSmall` и `.accessibility2`, disabled.
- **i18n с первого дня**, даже для англоязычного приложения: `Localizable.xcstrings`, все
  user-facing строки через `LocalizedStringResource`, RTL через `.leading`/`.trailing`, никогда
  `.left`/`.right`. Ретрофит примерно в 10 раз дороже.
