---
paths:
  - "**/*.swift"
---

# Swift Testing — неочевидное

Только то, что модель опускает или применяет ошибочно. Общий синтаксис `@Test`, `#expect`, `@Suite`,
`#expect(throws:)`, параметризованные тесты здесь не документируются.

Решения уровня проекта: для нового кода предпочитать Swift Testing; UI-тесты остаются на XCUITest;
performance `measure {}` остаётся на XCTest. Не смешивать Swift Testing и XCTest в одном файле.

## Изоляция `@Suite`

Каждый `@Test` в `@Suite struct` получает свежий экземпляр; `init` и `deinit` заменяют
`setUp`/`tearDown`. Общего мутируемого state между тестами нет по дизайну — держать зависимости
`let`-свойствами suite.

```swift
@Suite("Order cancellation")
struct OrderCancellationTests {
    let repository = FakeOrderRepository()  // пересоздаётся на каждый @Test
    let service: OrderService
    init() { service = OrderService(repository: repository) }
}
```

Модель иногда шарит state через `static var` «ради производительности» — это ломает параллельное
выполнение и делает тесты flaky.

## `#require` против `#expect`

`#expect(condition)` записывает провал и продолжает выполнение. `try #require(condition)` —
эквивалент guard: проваливает тест И разворачивает значение. Использовать, когда последующий код
зависит от результата.

```swift
let order = try #require(orders.first)  // проваливает, если nil; разворачивает, если нет
#expect(order.status == .pending)
```

Модель по умолчанию везде ставит `#expect` и пишет ручные `guard` с `Issue.record`. `try!` в тестах
не использовать — правильное разворачивание это `try #require`.

## Параллельно по умолчанию

**Swift Testing запускает тесты параллельно.** Всё, что трогает общий глобальный state — Keychain,
файловая система, `UserDefaults`, переменные окружения, синглтоны, сеть — будет гоняться. Для
действительно непараллелизуемых тестов применять trait `.serialized` на уровне suite или теста:

```swift
@Suite("Keychain integration", .serialized)
struct KeychainTests { /* ... */ }
```

Самая частая ловушка при миграции с XCTest.

## Fakes вместо Mocks

По умолчанию ручные fakes: модель рефлекторно тянется к mocking-фреймворкам (Cuckoo, Mockingbird), а
в Swift ручной fake обычно понятнее и не требует фреймворка.

Mocks оправданы, только когда у протокола много методов, а тест интересует одно конкретное
взаимодействие, либо когда проверяемый контракт — это именно число вызовов или их порядок.

`@unchecked Sendable` на fake допустим в однопоточном тесте; при строгом Swift 6 concurrency брать
actor-based fake или собственную синхронизацию.

## Границы теста для AsyncSequence

Потребление `AsyncSequence` должно быть ограничено — прерываться после N элементов или иметь
`.timeLimit`. Без ограничения незавершённая последовательность заставляет тест зависать навсегда, а
не падать. Модель часто пишет `for await x in sequence { ... }` без условия выхода.

```swift
for await orders in repository.observeOrders() {
    received.append(orders)
    if received.count >= 1 { break }  // ← обязательно
}
```

## Traits

`.disabled` всегда принимает причину строкой — иначе отключённые тесты копятся как молчаливый
мёртвый код:

```swift
@Test("Feature X integration", .disabled("Waiting for API v2 deployment"))
```

Не использовать `.enabled(if:)`, чтобы заглушить flaky-тест. Чинить сам flake — управляемые часы,
ограниченный async, детерминированные fakes.

## Никакого `Thread.sleep` / `usleep`

Async-тесты не ждут через wall-clock sleep. `Task.sleep` — только когда задержка действительно
нужна; лучше внедрять управляемые часы (протокол `Clock` или проектный fake), чтобы тест
детерминированно продвигал время.
