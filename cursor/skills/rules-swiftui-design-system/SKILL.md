---
name: rules-swiftui-design-system
description: Правила дизайн-системы SwiftUI (токены, theming, accessibility-чеклист) — применять при написании/правке .swift UI с дизайн-системой.
paths: **/*.swift
---

# SwiftUI Design System — неочевидные правила

Этот файл перечисляет только те правила дизайн-системы, которые современная модель Claude опускает или ошибочно применяет без напоминания. Общие рекомендации — «консистентность важнее изощрённости», «Apple HIG — база», «токены для spacing/radius/typography», «у каждого интерактивного элемента есть accessibilityLabel», «превью существуют», базовый синтаксис теминга — здесь **не** документируются; доверяй модели и HIG от Apple.

Про playbook внедрения на уровне проекта (волны, лейблы владения, стратегия миграции) — см. README дизайн-системы проекта, не этот файл.

---

## Не токенизировать это

Три категории, которые модель часто токенизирует избыточно:

- **Тень (Shadow)** — на macOS использовать `Material`; на iOS держать максимум 2-3 уровня elevation, не изобретать шкалу теней
- **Прозрачность (Opacity)** — использовать `.foregroundStyle(.secondary)` / `.tertiary` / `.quaternary` вместо токена opacity
- **Насыщенность шрифта как отдельные токены** — применять `.fontWeight(.semibold)` прямо к текстовым стилям

## Жёсткие запреты (сверх общего «никаких захардкоженных значений»)

Неочевидные случаи, которые модель всё ещё выдаёт из старых training-данных:

| Запрещено | Использовать вместо |
|---|---|
| `.foregroundColor(_:)` | `.foregroundStyle(_:)` |
| модификатор `.accentColor(_:)` | `.tint(_:)` + asset `AccentColor` |
| `RoundedRectangle(cornerRadius: 8)` | `.clipShape(.rect(cornerRadius: ..., style: .continuous))` для непрерывных углов |

Общие запреты (никаких сырых `.padding(16)`, `Color.black`, `Font.system(size: 14)` вне иконок/canvas) — это знание модели по умолчанию; следовать токенам проекта, где они есть.

## Accessibility за пределами `accessibilityLabel`

Модель по умолчанию пишет `accessibilityLabel`. Часто упускается:

- **Клавиатурные шорткаты на основных действиях sheet/формы** — `⌘Return` для подтверждения, `⌘.` для отмены
- **Сигнал только цветом не работает.** Сочетать цвет с SF Symbol (`exclamationmark.triangle.fill` для ошибок, `checkmark.circle.fill` для успеха). Реагировать на `@Environment(\.accessibilityDifferentiateWithoutColor)`.
- **Анимации, управляемые `accessibilityReduceMotion`**: `withAnimation(reduceMotion ? nil : .spring) { ... }`
- **Кастомные фоны, управляемые `accessibilityReduceTransparency`** — системные материалы обрабатывают это автоматически; кастомные фоны должны соответствовать.

## Мультиокна: Environment не пересекает Scenes

Значения `@Environment` **не** распространяются между границами `Scene` автоматически. Каждый `WindowGroup`, `Window`, `Settings`, `MenuBarExtra` должен внедрять тему/зависимость в корне своей собственной scene.

```swift
@main
struct MyApp: App {
    var body: some Scene {
        WindowGroup    { RootView().environment(\.theme, store.theme) }
        Settings       { SettingsView().environment(\.theme, store.theme) }
        MenuBarExtra("App", systemImage: "x") {
            MenuContent().environment(\.theme, store.theme)
        }
    }
}
```

Модель часто внедряет только в основной `WindowGroup`, и второе окно падает или показывает значения по умолчанию.

## Теминг — гибридное правило принятия решений

- **Статичный enum** для примитивов, не меняющихся в runtime — spacing, radius, motion, typography
- **Семантические обёртки NSColor / системного цвета** для адаптивных цветов (автоматически обрабатывают light/dark/HCR)
- **Struct, внедряемый через environment**, только когда пользователь выбирает между палитрами в runtime (темы терминала, акцентные палитры)

Модель часто сразу прыгает к environment injection для всего; статичные enum'ы проще и не требуют повторного внедрения scene за scene.

## Стилизация компонентов — статичные extension'ы `*Style`

Выставлять переиспользуемые `ButtonStyle` / `LabelStyle` / `ToggleStyle` и т.д. через статичные extension'ы на протоколе — тогда в месте вызова код читается естественно:

```swift
extension ButtonStyle where Self == BrandPrimaryButtonStyle {
    static var brandPrimary: Self { .init() }
}
// Использование: Button("Save") { ... }.buttonStyle(.brandPrimary)
```

`PrimitiveButtonStyle` — только когда дефолтного tap-жеста недостаточно.

## Превью — матрица покрытия для переиспользуемых компонентов

Переиспользуемым компонентам дизайн-системы нужно покрытие превью по:

- Светлая + тёмная тема
- Increase Contrast (и Dark HCR)
- Reduce Transparency
- Dynamic Type на `.xSmall` и `.accessibility2`
- Disabled-состояние (где применимо)

Выделенная схема-каталог (`DesignSystemCatalog` или аналог), перечисляющая каждый компонент, — это поверхность обнаружения — без неё разработчики дублируют компоненты.

## macOS 26+ / Liquid Glass

- Пересборка с Xcode 26 автоматически применяет Liquid Glass к toolbar, sheet, popover, sidebar `NavigationSplitView`, scene `Settings`. Opt-in не нужен.
- **Никогда на monospaced canvas** (терминал, редактор кода) — текст деградирует под рефракцией. Использовать `.containerBackground(.thinMaterial, for: .window)` для материала фона окна вместо этого.
- `.glassEffect(_:in:isEnabled:)` / `GlassEffectContainer` / `.glassEffectID(_:in:)` — только для плавающего UI (командная палитра, плавающие кнопки).
- `Reduce Transparency` / `Increase Contrast` / `Reduce Motion` — система обрабатывает fallback'и; кастомный код должен следовать этому.

## Dynamic Type на macOS

macOS в основном игнорирует Dynamic Type — `@ScaledMetric` и `.dynamicTypeSize` применяются слабо или вообще не применяются. Всё равно писать Dynamic-Type-ready форму (`.font(.body)`), но не полагаться на неё для user-facing масштабирования на macOS canvas.

Для content-canvas, где масштабирование важно (терминал, редактор): реализовать предпочтение масштаба шрифта на уровне приложения (`⌘+` / `⌘−`) и передавать коэффициент явно.

## Базовый уровень i18n

Даже для приложений только на английском настраивать `Localizable.xcstrings` с первого дня:

- Все user-facing строки через `Text("key", bundle: .module)` (или `LocalizedStringResource`)
- Тестировать раскладки с длинными строками (немецкий, русский) — ожидать текст шире на 30-40%
- RTL — выравнивание `.leading` / `.trailing`, никогда `.left` / `.right`

Ретрофит i18n примерно в 10 раз дороже, чем встроить его сразу.

## Источники

- Apple HIG, WWDC25 сессии 323 (новый дизайн SwiftUI) и 310 (новый дизайн AppKit)
- Документация NSColor UI element colors
