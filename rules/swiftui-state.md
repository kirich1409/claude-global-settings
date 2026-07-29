---
paths:
  - "**/*.swift"
---

# SwiftUI State — ловушки

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
`defaultValue` — обычно Unimplemented-заглушкой, громко падающей в тестах и превью. Работает в
симуляторе, пока view не появится в окне `Settings` или новом `WindowGroup`.

## Гранулярность `@Observable`

Каждое чтение свойства внутри `body` становится зависимостью, и деструктуризация в начале `body` от
этого не спасает. Два следствия: обращение к свойству в debug-логе «просто посмотреть» подписывает
view на его изменения; вычисляемое свойство модели, читающее N хранимых, создаёт N зависимостей у
каждого вызывающего.
