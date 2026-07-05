# SwiftUI State — неочевидные правила

Этот файл перечисляет только те правила управления state, которые современная модель Claude опускает или ошибочно применяет без напоминания. Общий выбор property wrapper'ов (`@State` для view-local UI state, `@Binding` для мутации родителя потомком, `@Observable` для shared моделей, `@Environment` для системных значений, `@AppStorage` для мелких настроек), `private` на `@State`, и «использовать `$`, а не `Binding(get:set:)`» — здесь **не** документируются; доверяй модели и документации Apple по SwiftUI.

---

## `@State`, инициализированный из параметра `init`, замораживается

Самый дорогой баг property wrapper'ов в SwiftUI: хранение внешнего значения как `@State` делает обновления родителя невидимыми после первого рендера.

```swift
// БАГ: обновления родителя игнорируются после init — @State принадлежит только владельцу
struct ItemRow: View {
    @State private var item: Item
    init(item: Item) { _item = State(initialValue: item) }
}

// Фикс: передавать насквозь, или @Binding, если нужна мутация
struct ItemRow: View {
    let item: Item
}
```

Модель пишет багованную форму, когда view «нужно отслеживать локальный state, производный от переданного значения». Практически никогда это действительно не нужно.

## `@Observable` отслеживает чтения по каждому свойству в `body`

`@Observable` — **не** то же самое, что старый `@Published` / грубый `objectWillChange` — каждое чтение свойства внутри `body` становится зависимостью. Два следствия, которые модель упускает:

1. **Читать только то, что отображается.** Обращение к `model.totalCount` в debug-логе «просто чтобы посмотреть» заставляет view перерисовываться при каждом изменении `totalCount`.
2. **Вычисляемые свойства модели, читающие N хранимых свойств, создают N зависимостей у любого вызывающего.** «Простое» вычисляемое `var summary: String { "\(name) — \(count) items" }` заставляет каждого вызывающего зависеть и от `name`, и от `count`.

Деструктуризация в начале `body` (`let (a, b) = (model.a, model.b)`) не обходит трекинг — оба чтения всё равно регистрируются.

## Property wrapper'ы внутри `@Observable` нуждаются в `@ObservationIgnored`

Хранение `@AppStorage`, `@FocusState` или любого другого property wrapper внутри `@Observable`-класса без `@ObservationIgnored` ломает observation — форма хранения wrapper'а несовместима с трекингом макроса observation.

```swift
@Observable
class Settings {
    @ObservationIgnored
    @AppStorage("theme") var theme: String = "light"
}
```

То же применимо к lazy/кэшируемым свойствам, которые не должны отслеживаться (loggers, formatters, внутренние счётчики).

## `@Environment(Type.self)` без default падает

`@Environment(SomeType.self)` (без ключа `defaultValue`) молча падает в runtime, если значение не внедрено — view крашится при первом чтении. Либо:

- Предоставлять его в корне каждого Scene, хостящего этот view, либо
- Использовать форму `EnvironmentKey` с `defaultValue` (обычно stub-заглушка Unimplemented, громко падающая в тестах/превью)

Модель часто выдаёт view, читающие `@Environment(...)` без гарантии внедрения — работает в симуляторе, пока view не появится в окне `Settings` или новом `WindowGroup`.

## `@State private var model = ObservableModel()` — не `@StateObject`

Для владеемых view `@Observable`-моделей на iOS 17+ правильная обёртка времени жизни — `@State`. `@StateObject` — legacy-паттерн для `ObservableObject`. Модель всё ещё выдаёт `@StateObject` из старых training-данных — заменять его.

```swift
struct OrderListScreen: View {
    @State private var model = OrderListModel()  // ✓ владеет временем жизни, переживает рекомпозиции
    var body: some View { /* ... */ }
}
```
