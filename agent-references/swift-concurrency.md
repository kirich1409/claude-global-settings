# Swift Concurrency — неочевидные правила

Этот файл перечисляет только те правила Swift Concurrency, которые современная модель Claude опускает или ошибочно применяет без напоминания. Общие идиомы — `async`/`await`, `try await`, `async let`, `TaskGroup`, основы structured concurrency, вывод Sendable для value-типов, выбор actor вместо locks, базовый async-синтаксис тестов — здесь **не** документируются; доверяй модели и [книге Apple о Concurrency](https://docs.swift.org/swift-book/documentation/the-swift-programming-language/concurrency/).

---

## Размещение `@MainActor`

Модель по умолчанию чрезмерно применяет `@MainActor` «для безопасности». Останавливать это.

- **`@Observable`-классы модели, обновляющие UI-bound state** → `@MainActor` (правильно).
- **Слой Service / Repository / DataSource** → **никогда** `@MainActor`. I/O, парсинг, маппинг должны выполняться вне главного потока. Аннотировать слой как `actor` для thread-safe state, выбор диспетчера оставлять на стороне вызывающего кода.
- **Одному методу нужен доступ к main thread** → `@MainActor func updateUI(...)`, а не весь тип целиком.
- **Внутри async-кода** → использовать `@MainActor` / `MainActor.run { }`, никогда `DispatchQueue.main.async`.

Методы `@MainActor` гарантируют выполнение на main thread только при вызове из async-контекста. Синхронные вызывающие всё ещё могут выполнить их вне main на синтезированном потоке — не предполагать ничего.

## `Task.detached` — это не «побег от `@MainActor`»

`Task.detached` существует для редкого случая, когда действительно нужна top-level unstructured задача без унаследованной isolation, priority или task-local значений. Модель рефлекторно тянется к нему, чтобы «сбежать» от `@MainActor`. Не делать так.

- Чтобы выполнить метод вне main actor → пометить метод `nonisolated`.
- Чтобы выполнить CPU-работу параллельно → `async let` или `TaskGroup` из не-actor контекста.
- `Task.detached` корректен только для: осиротевшей фоновой работы, переживающей родителя; работы, которая явно НЕ должна наследовать task-local значения; редкого случая interop.

## `nonisolated` для чистых вычисляемых членов

На actor или `@MainActor`-типе помечать свойства / методы, не трогающие мутируемый state, как `nonisolated`. Без этого каждое чтение вынуждает `await`. Модель часто забывает об этом и создаёт бессмысленные кросс-actor переходы.

```swift
actor OrderCache {
    private var cache: [OrderID: Order] = [:]
    nonisolated var description: String { "OrderCache" } // ← правильно
}
```

## Мостик отмены `Task`

Три вещи, которые модель упускает:

1. **Кооперативная отмена в длинных циклах** — `try Task.checkCancellation()` (или `Task.isCancelled`) внутри тела цикла. Без этого отмена срабатывает только в точках suspension.
2. **Проброс отмены в не-async API** — оборачивать `URLSessionDataTask` / `OperationQueue` / аналогичное в `withTaskCancellationHandler { ... } onCancel: { task.cancel() }`. Модель часто пишет `withCheckedThrowingContinuation` без моста отмены, оставляя базовый запрос выполняться.
3. **Хранить handle `Task`**, когда работу нужно отменять при dealloc, навигации или новом запросе:

```swift
private var loadTask: Task<Void, Never>?
func startLoading() {
    loadTask?.cancel()
    loadTask = Task { /* ... */ }
}
```

## Жизненный цикл `AsyncStream` / `AsyncThrowingStream`

Два молчаливых footgun'а:

- **`continuation.finish()` обязателен**, когда producer завершил работу. Забытый вызов заставляет потребителей `for await` зависать навсегда — не падать, а именно зависать.
- **`continuation.onTermination` должен освобождать ресурсы** — наблюдателей, файловые хендлы, network listeners. Без этого каждый отменённый потребитель течёт по базовому ресурсу.

```swift
AsyncStream { continuation in
    let observer = register(...)
    continuation.onTermination = { _ in unregister(observer) } // ← обязательно
    // и continuation.finish() как только источник исчерпан
}
```

## Дисциплина `@unchecked Sendable`

`@unchecked Sendable` — только для доказанно thread-safe reference-типов, внутренне синхронизированных через lock, queue или atomic-примитив. Никогда не использовать её, чтобы заглушить предупреждение Sendable на типе, у которого действительно есть data races. Компилятор прав; аннотация — не фикс.

```swift
// Допустимо — внутренний lock защищает весь доступ
final class AtomicCounter: @unchecked Sendable {
    private let lock = NSLock()
    private var _value = 0
}

// НЕ допустимо — заглушение реальной гонки
final class MutableThing: @unchecked Sendable {
    var data: [String] = []
}
```

## Swift 6 Strict Concurrency — миграция и клапаны обхода

Лестница миграции (использовать текущую ступень проекта; поднимать постепенно):

1. `-strict-concurrency=targeted` — предупреждения только на аннотированных API
2. `-strict-concurrency=complete` — предупреждения повсюду
3. Языковой режим Swift 6 — предупреждения становятся ошибками

Клапаны обхода использовать умеренно:

- **`@preconcurrency import ThirdParty`** — допустимо для сторонних модулей, ещё не обновлённых под Sendable. **Никогда** не применять `@preconcurrency` к собственным типам; исправлять соответствие.
- **`nonisolated(unsafe)`** — клапан только для interop (legacy globals, ObjC bridging). Никогда не общий заглушитель.
- Модификатор параметра `sending` передаёт владение; редко применим в обычном коде.

## Тесты — управляемые часы

Async-тесты не должны полагаться на wall-clock время. Использовать `Task.sleep` только когда задержка действительно нужна; лучше — управляемые часы (протокол `Clock`, `ContinuousClock` или внедрённые в проект фейковые часы), чтобы тест мог детерминированно продвигать время.

Никогда `Thread.sleep` / `usleep` в async-тестах.
