---
paths:
  - "**/*.swift"
---

# Swift Concurrency — ловушки

## Жизненный цикл `AsyncStream` / `AsyncThrowingStream`

Два молчаливых footgun'а:

- **`continuation.finish()` обязателен**, когда producer завершил работу. Забытый вызов заставляет
  потребителей `for await` зависать навсегда — не падать, а именно зависать.
- **`continuation.onTermination` должен освобождать ресурсы** — наблюдателей, файловые хендлы,
  network listeners. Без этого каждый отменённый потребитель течёт по базовому ресурсу.

```swift
AsyncStream { continuation in
    let observer = register(...)
    continuation.onTermination = { _ in unregister(observer) } // ← обязательно
    // и continuation.finish() как только источник исчерпан
}
```

## Мостик отмены `Task`

- **Кооперативная отмена в длинных циклах** — `try Task.checkCancellation()` внутри тела цикла: без
  этого отмена срабатывает только в точках suspension.
- **Проброс отмены в не-async API** — оборачивать `URLSessionDataTask` / `OperationQueue` в
  `withTaskCancellationHandler { ... } onCancel: { task.cancel() }`. Голый
  `withCheckedThrowingContinuation` оставляет базовый запрос выполняться.

## `@unchecked Sendable`

Только для доказанно thread-safe reference-типов, внутренне синхронизированных через lock, queue или
atomic. Никогда — чтобы заглушить предупреждение на типе, у которого есть реальная гонка: компилятор
прав, аннотация не фикс.

## Клапаны обхода strict concurrency

- **`@preconcurrency import ThirdParty`** — допустимо для сторонних модулей, ещё не обновлённых под
  Sendable. **Никогда** не применять `@preconcurrency` к собственным типам.
- **`nonisolated(unsafe)`** — только для interop (legacy globals, ObjC bridging), никогда не общий
  заглушитель.
