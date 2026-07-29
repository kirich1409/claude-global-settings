---
paths:
  - "**/*.swift"
---

# SwiftUI State — неочевидное

Только то, что модель опускает или применяет ошибочно. Общий выбор property wrapper'ов, `private`
на `@State`, «использовать `$`, а не `Binding(get:set:)`» здесь не документируются.

## `@State`, инициализированный из параметра `init`, замораживается

Самый дорогой баг property wrapper'ов: хранение внешнего значения как `@State` делает обновления
родителя невидимыми после первого рендера.

```swift
// БАГ: обновления родителя игнорируются после init
struct ItemRow: View {
    @State private var item: Item
    init(item: Item) { _item = State(initialValue: item) }
}

// Фикс: передавать насквозь, или @Binding, если нужна мутация
struct ItemRow: View {
    let item: Item
}
```

Модель пишет багованную форму, когда view «нужен локальный state, производный от переданного
значения». Практически никогда это действительно не нужно.

## `@Observable` отслеживает чтения по каждому свойству в `body`

Это не старый `@Published` с грубым `objectWillChange`: каждое чтение свойства внутри `body`
становится зависимостью. Два следствия:

1. **Читать только то, что отображается.** Обращение к `model.totalCount` в debug-логе «просто
   посмотреть» заставляет view перерисовываться при каждом его изменении.
2. **Вычисляемое свойство модели, читающее N хранимых, создаёт N зависимостей у вызывающего.**
   «Простое» `var summary: String { "\(name) — \(count) items" }` подписывает каждого вызывающего и
   на `name`, и на `count`.

Деструктуризация в начале `body` от трекинга не спасает — оба чтения всё равно регистрируются.

## Property wrapper внутри `@Observable` требует `@ObservationIgnored`

`@AppStorage`, `@FocusState` и любой другой wrapper внутри `@Observable`-класса без
`@ObservationIgnored` ломает observation: форма хранения wrapper'а несовместима с трекингом макроса.

```swift
@Observable
class Settings {
    @ObservationIgnored
    @AppStorage("theme") var theme: String = "light"
}
```

То же для lazy и кэшируемых свойств, которые не должны отслеживаться: loggers, formatters, счётчики.

## `@Environment(Type.self)` без default падает

Без `defaultValue` значение, которое не внедрили, роняет view в runtime при первом чтении. Либо
предоставлять его в корне каждой Scene, хостящей view, либо использовать форму `EnvironmentKey` с
`defaultValue` — обычно Unimplemented-заглушкой, громко падающей в тестах и превью.

Модель часто выдаёт view, читающие `@Environment` без гарантии внедрения: работает в симуляторе,
пока view не появится в окне `Settings` или новом `WindowGroup`.

## `@State private var model = ObservableModel()`, не `@StateObject`

Для владеемых view `@Observable`-моделей на iOS 17+ правильная обёртка времени жизни — `@State`.
`@StateObject` — legacy для `ObservableObject`; модель всё ещё выдаёт его из старых training-данных.
