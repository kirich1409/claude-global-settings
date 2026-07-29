---
paths:
  - "**/*.kt"
---

# Coroutines и Flow — неочевидное

Только то, что модель упускает или нарушает без напоминания. Основы structured concurrency,
`viewModelScope`, экспонирование immutable `StateFlow`, `async`/`await`, билдеры `flow {}`, выбор
между `suspend` и `Flow` здесь не документируются.

## Владение scope по слоям

| Слой | Scope | Почему |
|---|---|---|
| ViewModel | `viewModelScope` | привязан к lifecycle, переживает config changes |
| UseCase / Repository | **своего нет, наследует от вызывающего** | вызывающий управляет отменой |
| работа, переживающая экран | внедрённый Application-scoped `CoroutineScope` | гарантирует завершение записи, если пользователь ушёл |

Внедрять Application-scope в Repository нельзя — модель иногда это делает.

## Dispatcher — параметр конструктора

Хардкод `Dispatchers.IO` внутри `withContext` делает класс нетестируемым.

```kotlin
class DefaultOrderRepository(
    private val api: OrderApi,
    @IoDispatcher private val dispatcher: CoroutineDispatcher,
) : OrderRepository {
    override suspend fun getOrders(): List<Order> =
        withContext(dispatcher) { api.getOrders().map { it.toOrder() } }
}
```

## Suspend-функции main-safe

Каждая `suspend fun` в data и domain слое безопасна для вызова с main thread: функция сама выбирает
dispatcher внутренним `withContext`. Вызывающий её не оборачивает — обёртка на стороне вызывающего
означает, что контракт нарушен.

## Lifecycle-паринг StateFlow

`SharingStarted.WhileSubscribed(5_000)` — правильный дефолт для `stateIn` во ViewModel, но работает,
только если UI собирает lifecycle-aware API: `collectAsStateWithLifecycle()` в Compose,
`flowWithLifecycle()` или `repeatOnLifecycle(STARTED)` во View. Без этого upstream не остановится
никогда.

`Eagerly` тратит ресурсы, если состояние не нужно постоянно. `Lazily` не останавливается после
запуска — для screen-scoped состояния обычно неверно.

## Порядок операторов Flow

- `flowOn(dispatcher)` влияет только на upstream. Вызов дважды или после терминального оператора
  тихо ничего не делает. Применять один раз, на стороне producer.
- `retry {}` ставится **до** `catch {}`: если `catch` выполнится первым, он поглотит ошибку и
  `retry` её не увидит.

```kotlin
upstream
    .retry(3) { it is IOException }   // первым — получает шанс повторить
    .catch { /* fallback emission */ } // последним — неисправимые ошибки
    .collect { /* ... */ }
```

## Бесконечная приостановка

`first()`, `single()` и `Channel.receive()` висят до прихода данных. Источник не эмитирует —
coroutine зависает навсегда; частый production-баг с event-driven Flow.

| Источник | Риск `first()` | Защита |
|---|---|---|
| `StateFlow` | безопасно, значение есть всегда | нет |
| `SharedFlow(replay > 0)` | низкий | `withTimeout` для редких событий |
| `SharedFlow(replay = 0)` | **высокий**, ждёт следующего emit | всегда `withTimeout` |
| `Channel` | **высокий**, ждёт `send()` | `tryReceive()` или `withTimeout` |
| cold `flow {}` | зависит от producer | `withTimeout`, если producer может не эмитировать |

`firstOrNull()` — когда отсутствие данных допустимый исход, а не ошибка.

## `CancellationException` должен распространяться

Любой `catch` по `Exception` или `Throwable` сначала перебрасывает `CancellationException` — модель
об этом постоянно забывает.

```kotlin
try {
    api.fetchData()
} catch (e: CancellationException) {
    throw e
} catch (e: Exception) {
    handleError(e)
}
```

`runCatching {}` поглощает `CancellationException` — голым в suspend-коде не использовать; либо
перебрасывать внутри `onFailure`, либо писать явный `try/catch`.

## `withContext(NonCancellable)` — только в `finally`

`NonCancellable` отключает отмену для всего внутри. Допустим исключительно в cleanup, который
обязан завершиться после отмены:

```kotlin
try { work() } finally {
    withContext(NonCancellable) { releaseResources() }
}
```

В любом другом месте это баг: отключает кооперативную отмену вверх по цепочке.

## Маппинг ошибок на границах слоёв

`HttpException`, `SQLiteException` и прочие implementation-исключения не пропускать в domain и
presentation. Маппить на границе data → domain в project-специфичный тип ошибки или `Result<T>`.

## Тестирование

- Все `TestDispatcher` в одном тесте используют **один** `TestCoroutineScheduler` — иначе
  `advanceUntilIdle()` не распространяется.
- Заменять Main перед тестированием всего, что использует `viewModelScope`:
  `Dispatchers.setMain(testDispatcher)` в `@Before`, `Dispatchers.resetMain()` в `@After`.
- `UnconfinedTestDispatcher` выполняется жадно и проще для большинства тестов;
  `StandardTestDispatcher` ставит в очередь и продвигается `advanceUntilIdle()`/`runCurrent()` —
  брать, когда нужен явный контроль над порядком планирования.

Для assertions по Flow использовать Turbine. Не ждать coroutines через `delay()` или
`Thread.sleep()`.
