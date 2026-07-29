---
paths:
  - "**/*.swift"
---

# SwiftUI Patterns — ловушки

## `.navigationDestination` — в корне `NavigationStack`

`navigationDestination(for:)` должен быть в корне стека. Размещение у потомка молча ломает роутинг
после первого push.

```swift
NavigationStack(path: $path) {
    HomeScreen()
        .navigationDestination(for: Route.self) { route in /* все case здесь */ }
}
```

## Условный модификатор `.if {}` — анти-паттерн

Широко рекомендуемый в интернете и широко неправильный: тип возвращаемого значения меняется вместе
с условием, что ломает identity и diffing. Применять модификаторы условно инлайн, через тернарный
оператор на значении модификатора, а не на его наличии:

```swift
Text("Status")
    .foregroundStyle(isActive ? .green : .secondary)
```

## Превью — статичные сэмплы на модели

Добавлять `static let samples` (или `static func sample(...)`) на доменный тип, а не конструировать
тестовые данные инлайн в каждом `#Preview`. Следовать конвенции превью проекта
(`#Preview("name", traits:)`, dark/light, multi-device).
