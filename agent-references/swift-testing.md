# Swift Testing — неочевидные правила

Этот файл перечисляет только те правила тестирования, которые современная модель Claude опускает или ошибочно применяет без напоминания. Общий синтаксис — `@Test`, `#expect`, `@Suite`, базовые async-тесты, `#expect(throws:)`, `XCTAssertEqual` для XCTest, параметризованные тесты с `arguments:` — здесь **не** документируется; доверяй модели и [документации Apple по Testing](https://developer.apple.com/documentation/testing).

Для решений, зависящих от конфигурации проекта: для нового кода предпочитать Swift Testing. UI-тесты остаются на XCUITest. Performance `measure {}` остаётся на XCTest. Не смешивать Swift Testing и XCTest в одном файле.

---

## Изоляция тестов `@Suite`

Каждый `@Test` в `@Suite struct` получает **свежий экземпляр**. `init` и `deinit` заменяют `setUp` / `tearDown` из XCTest. По дизайну **нет общего мутируемого state между тестами** — хранить зависимости как `let`-свойства на suite, и каждый тест увидит их заново инициализированными.

Модель иногда пытается шарить state через `static var` «ради производительности» — это ломает параллельное выполнение и создаёт flaky-тесты.

```swift
@Suite("Order cancellation")
struct OrderCancellationTests {
    let repository = FakeOrderRepository()  // пересоздаётся на каждый @Test
    let service: OrderService
    init() { service = OrderService(repository: repository) }
}
```

## `#require` против `#expect`

- `#expect(condition)` → assertion, которая продолжает выполнение при провале (записывает и идёт дальше).
- `try #require(condition)` → эквивалент guard: проваливает тест И разворачивает значение. Использовать, когда последующий код зависит от результата.

Модель по умолчанию везде использует `#expect` и пишет ручные `guard` с `Issue.record`. Использовать `#require`, чтобы сжать это:

```swift
let order = try #require(orders.first)  // проваливает тест, если nil; разворачивает, если не nil
#expect(order.status == .pending)
```

Никогда `try!` в тестах — `try #require` является правильным разворачиванием.

## Изоляция «параллельно по умолчанию»

**Swift Testing по умолчанию запускает тесты параллельно.** Всё, что трогает общий глобальный state — Keychain, файловую систему, `UserDefaults`, переменные окружения, singleton'ы, сеть — будет гоняться (race).

Для тестов, которые действительно не могут выполняться параллельно: применять trait `.serialized` на уровне suite или теста.

```swift
@Suite("Keychain integration", .serialized)
struct KeychainTests { /* ... */ }
```

Это самая распространённая ловушка при миграции с XCTest. Модель не в курсе, если ей не сказать.

## Fakes вместо Mocks

По умолчанию использовать ручные fakes. Модель рефлекторно тянется к mocking-фреймворкам (Cuckoo, Mockingbird); в Swift ручные fakes обычно понятнее и не требуют фреймворка.

```swift
final class FakeAPIClient: APIClient, @unchecked Sendable {
    var responses: [String: Any] = [:]
    private(set) var requestedPaths: [String] = []
    func get<T: Decodable>(_ path: String, as: T.Type) async throws -> T {
        requestedPaths.append(path)
        guard let r = responses[path] as? T else { throw APIError.notFound }
        return r
    }
}
```

Использовать mocks только когда: (a) у протокола много методов, а тест интересует одно конкретное взаимодействие; (b) точное проверяемое число вызовов или их порядок И ЕСТЬ проверяемый контракт.

`@unchecked Sendable` на fake допустим, когда тест однопоточный; при строгом Swift 6 concurrency рассмотреть fake на основе actor или собственную синхронизацию.

## Границы теста для AsyncSequence

Потребление `AsyncSequence` в тесте должно быть **ограничено** — прерываться после N элементов или применять `.timeLimit`. Без ограничения незавершённая последовательность заставляет тест зависать навсегда, а не падать. Модель часто пишет `for await x in sequence { ... }` без условия выхода.

```swift
for await orders in repository.observeOrders() {
    received.append(orders)
    if received.count >= 1 { break }  // ← обязательно
}
```

Либо использовать `.timeLimit(.minutes(1))` как страховку.

## Traits — `.disabled` требует причину

`.disabled` всегда принимает строку с причиной — без неё отключённые тесты накапливаются как молчаливый мёртвый код:

```swift
@Test("Feature X integration", .disabled("Waiting for API v2 deployment"))
func featureXIntegration() async throws { /* ... */ }
```

Никогда не использовать `.enabled(if:)`, чтобы заглушить flaky-тесты. Исправлять сам flake (управляемые часы, ограниченный async, детерминированные fakes), а не прятать его.

## Никакого `Thread.sleep` / `usleep`

Async-тесты не должны ждать через wall-clock sleep. Использовать `Task.sleep` только когда задержка действительно нужна; лучше — внедрять управляемые часы (протокол `Clock` или специфичный для проекта fake), чтобы тест детерминированно продвигал время.
