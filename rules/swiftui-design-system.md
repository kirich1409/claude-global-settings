---
paths:
  - "**/*.swift"
---

# SwiftUI Design System — неочевидное

Только то, что модель опускает или применяет ошибочно. «Консистентность важнее изощрённости»,
«HIG — база», токены для spacing и typography, `accessibilityLabel` на интерактивных элементах
здесь не документируются. Playbook внедрения на уровне проекта — в README дизайн-системы проекта.

## Не токенизировать

- **Тень** — на macOS использовать `Material`; на iOS держать 2–3 уровня elevation, не изобретать
  шкалу теней.
- **Прозрачность** — `.foregroundStyle(.secondary)` / `.tertiary` / `.quaternary` вместо токена
  opacity.
- **Насыщенность шрифта отдельными токенами** — применять `.fontWeight(.semibold)` прямо к стилю.

## Жёсткие запреты

Случаи, которые модель выдаёт из старых training-данных:

| Запрещено | Вместо |
|---|---|
| `.foregroundColor(_:)` | `.foregroundStyle(_:)` |
| модификатор `.accentColor(_:)` | `.tint(_:)` плюс asset `AccentColor` |
| `RoundedRectangle(cornerRadius: 8)` | `.clipShape(.rect(cornerRadius: ..., style: .continuous))` |

## Accessibility за пределами `accessibilityLabel`

- Клавиатурные шорткаты на основных действиях sheet и формы: `⌘Return` подтвердить, `⌘.` отменить.
- **Сигнал только цветом не работает.** Сочетать цвет с SF Symbol (`exclamationmark.triangle.fill`
  для ошибки, `checkmark.circle.fill` для успеха), реагировать на
  `@Environment(\.accessibilityDifferentiateWithoutColor)`.
- Анимации под `accessibilityReduceMotion`: `withAnimation(reduceMotion ? nil : .spring) { ... }`.
- Кастомные фоны под `accessibilityReduceTransparency` — системные материалы делают это сами,
  кастомные должны соответствовать.

## Environment не пересекает Scene

Значения `@Environment` не распространяются между `Scene` автоматически. Каждый `WindowGroup`,
`Window`, `Settings`, `MenuBarExtra` внедряет тему и зависимости в корне своей scene.

```swift
@main
struct MyApp: App {
    var body: some Scene {
        WindowGroup { RootView().environment(\.theme, store.theme) }
        Settings    { SettingsView().environment(\.theme, store.theme) }
    }
}
```

Модель часто внедряет только в основной `WindowGroup`, и второе окно падает или показывает дефолты.

## Теминг — гибридное решение

- **Статичный enum** для примитивов, не меняющихся в runtime: spacing, radius, motion, typography.
- **Семантические системные цвета** для адаптивных цветов — они сами обрабатывают light, dark и HCR.
- **Struct через environment** только когда пользователь выбирает палитру в runtime.

Модель сразу прыгает к environment injection для всего; статичные enum проще и не требуют
повторного внедрения в каждой scene.

## Стили компонентов — статичные extension

Переиспользуемые `ButtonStyle`, `LabelStyle`, `ToggleStyle` выставлять статичными extension на
протоколе, тогда место вызова читается естественно:

```swift
extension ButtonStyle where Self == BrandPrimaryButtonStyle {
    static var brandPrimary: Self { .init() }
}
// Button("Save") { ... }.buttonStyle(.brandPrimary)
```

`PrimitiveButtonStyle` — только когда дефолтного tap-жеста недостаточно.

## Превью переиспользуемых компонентов

Матрица покрытия: светлая и тёмная тема, Increase Contrast (и Dark HCR), Reduce Transparency,
Dynamic Type на `.xSmall` и `.accessibility2`, disabled-состояние. Выделенная схема-каталог
(`DesignSystemCatalog` или аналог) — поверхность обнаружения; без неё компоненты дублируются.

## macOS 26+ / Liquid Glass

- Пересборка с Xcode 26 применяет Liquid Glass к toolbar, sheet, popover, sidebar
  `NavigationSplitView` и scene `Settings` автоматически, opt-in не нужен.
- **Никогда на monospaced canvas** (терминал, редактор кода) — текст деградирует под рефракцией.
  Для фона окна использовать `.containerBackground(.thinMaterial, for: .window)`.
- `.glassEffect(_:in:isEnabled:)`, `GlassEffectContainer`, `.glassEffectID(_:in:)` — только для
  плавающего UI: командная палитра, плавающие кнопки.
- Reduce Transparency, Increase Contrast и Reduce Motion система обрабатывает сама; кастомный код
  должен следовать.

## Dynamic Type на macOS

macOS в основном игнорирует Dynamic Type: `@ScaledMetric` и `.dynamicTypeSize` применяются слабо
или не применяются вовсе. Писать Dynamic-Type-ready форму (`.font(.body)`) всё равно, но не
полагаться на неё для user-facing масштабирования на macOS canvas. Для content-canvas, где
масштабирование важно (терминал, редактор), реализовать предпочтение масштаба на уровне приложения
(`⌘+` / `⌘−`) и передавать коэффициент явно.

## i18n с первого дня

Даже для англоязычного приложения настраивать `Localizable.xcstrings` сразу: все user-facing строки
через `Text("key", bundle: .module)` или `LocalizedStringResource`; тестировать раскладки с длинными
строками (немецкий, русский — ожидать +30–40% ширины); RTL — выравнивание `.leading`/`.trailing`,
никогда `.left`/`.right`. Ретрофит примерно в 10 раз дороже.
