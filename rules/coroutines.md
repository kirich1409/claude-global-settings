---
paths:
  - "**/*.kt"
---

# Kotlin Coroutines & Flow — Неочевидные правила

Этот файл содержит только те правила coroutines и Flow, которые современная модель упускает или нарушает без напоминания. Общие идиомы — основы structured concurrency, `viewModelScope` для ViewModels, экспонирование immutable `StateFlow`, `async`/`await`, билдеры `flow {}`, выбор между `suspend` и `Flow`, перехват `IOException` вместо `Exception`, отсутствие пустых `catch`-блоков — **не** документированы здесь; доверяй модели и [официальной документации kotlinx.coroutines](https://kotlinlang.org/docs/coroutines-guide.html).

---

## Владение scope по слоям

Модели иногда внедряют `CoroutineScope` уровня Application в Repository. Так делать нельзя.

| Слой | Scope | Почему |
|-------|-------|-----|
| ViewModel | `viewModelScope` | Привязан к lifecycle ViewModel, переживает config changes |
| UseCase / Repository | **Нет собственного scope — наследует от вызывающего** | Вызывающий управляет отменой |
| Работа, которая должна пережить экран | Внедрённый `CoroutineScope` (Application-scoped) | Гарантирует завершение, если пользователь уходит в середине записи |

## Внедрение dispatcher — параметр конструктора, не хардкод

Внедрять `CoroutineDispatcher` как параметр конструктора. Модели по умолчанию хардкодят `Dispatchers.IO` внутри блоков `withContext`, что делает класс нетестируемым.

```kotlin
class DefaultOrderRepository(
    private val api: OrderApi,
    @IoDispatcher private val dispatcher: CoroutineDispatcher,
) : OrderRepository {
    override suspend fun getOrders(): List<Order> =
        withContext(dispatcher) { api.getOrders().map { it.toOrder() } }
}
```

## Suspend-функции main-safe — вызывающий не оборачивает

Каждая `suspend fun` в data/domain слое должна быть безопасна для вызова с main thread. Функция сама выбирает dispatcher через внутренний `withContext`. Вызывающий **не** оборачивает её в `withContext` — это нарушает контракт и означает, что функция не соблюдает main-safety.

Модели иногда перекладывают выбор dispatcher на вызывающего. Держи это внутри функции.

## Lifecycle-паринг StateFlow / SharedFlow

`SharingStarted.WhileSubscribed(5_000)` — правильный дефолт для `stateIn` во ViewModel, и он работает только если UI собирает с **lifecycle-aware** API. Без lifecycle awareness upstream никогда не останавливается:

```kotlin
val orders: StateFlow<List<Order>> = getOrders()
    .stateIn(
        scope = viewModelScope,
        started = SharingStarted.WhileSubscribed(5_000),
        initialValue = emptyList(),
    )
```

UI:
- Compose: `collectAsStateWithLifecycle()`
- Views: `flowWithLifecycle()` / `repeatOnLifecycle(Lifecycle.State.STARTED)`

`SharingStarted.Eagerly` тратит ресурсы, если состояние не нужно постоянно. `SharingStarted.Lazily` никогда не останавливается после запуска — обычно неверно для screen-scoped состояния.

## Подводные камни операторов Flow

Два неочевидных факта, которые модель нарушает при порядке:

1. **`flowOn(dispatcher)` влияет только на upstream-операторы** — вызов дважды или после терминального оператора тихо ничего полезного не делает. Применять один раз, на стороне producer.
2. **`retry { }` должен стоять ДО `catch { }`** в цепочке. Если `catch` выполняется первым, он поглощает ошибку, и `retry` её не видит.

```kotlin
upstream
    .map { /* ... */ }
    .retry(3) { it is IOException }   // первым — получает шанс повторить
    .catch { /* fallback emission */ } // последним — обрабатывает неисправимые ошибки
    .collect { /* ... */ }
```

## Предотвращение бесконечной приостановки

Терминальные операторы `first()`, `single()`, `Channel.receive()` приостанавливаются до прихода данных. Если источник никогда не эмитирует, coroutine зависает навсегда — распространённый production-баг с event-driven Flow.

| Источник | Риск `first()` | Защита |
|---|---|---|
| `StateFlow` | Безопасно — всегда есть значение | Нет |
| `SharedFlow(replay > 0)` | Низкий — воспроизводит последние N значений | `withTimeout` для редких событий |
| `SharedFlow(replay = 0)` | **Высокий** — ждёт следующего emit | Всегда использовать `withTimeout` |
| `Channel` | **Высокий** — ждёт `send()` | `tryReceive()` или `withTimeout` |
| Cold `flow { }` | Зависит от producer | `withTimeout` если producer может не эмитировать |

Использовать `firstOrNull()`, когда отсутствие данных — допустимый исход, а не ошибка.

## Отмена — `CancellationException` должен распространяться

Каждый `catch`, перехватывающий `Exception` или `Throwable`, должен сначала перебросить `CancellationException`. Модели постоянно забывают об этом:

```kotlin
try {
    api.fetchData()
} catch (e: CancellationException) {
    throw e
} catch (e: Exception) {
    handleError(e)
}
```

`runCatching { }` поглощает `CancellationException` — никогда не использовать голый `runCatching` в suspend-коде. Либо перебрасывать внутри `onFailure`, либо использовать явный `try/catch`:

```kotlin
runCatching { api.fetchData() }
    .onFailure { e ->
        if (e is CancellationException) throw e
        handleError(e)
    }
```

## `withContext(NonCancellable)` — только в `finally`

`NonCancellable` отключает отмену для всего внутри. Использовать **только в cleanup, который должен завершиться после отмены coroutine**:

```kotlin
try {
    work()
} finally {
    withContext(NonCancellable) { releaseResources() } // валидно
}
```

В любом другом месте это баг — отключает кооперативную отмену в вызывающей цепочке.

## Маппинг ошибок на границах слоёв

Нельзя пропускать `HttpException`, `SQLiteException` или другие implementation-исключения в domain или presentation слой. Маппировать их на границе data → domain в project-специфичный тип ошибки или `Result<T>`.

## Тестирование

Три правила, которые модель упускает:

1. **Все `TestDispatchers` в одном тесте должны использовать одинаковый scheduler** — иначе `advanceUntilIdle()` не распространяется. Передавать один и тот же `TestCoroutineScheduler` каждому dispatcher.
2. **Заменить `Main` dispatcher** перед тестированием всего, что использует `viewModelScope`: `Dispatchers.setMain(testDispatcher)` в `@Before`, `Dispatchers.resetMain()` в `@After`.
3. **`UnconfinedTestDispatcher` vs `StandardTestDispatcher`** — `Unconfined` выполняется жадно (проще для большинства тестов; assertions видят последнее состояние после каждого suspend-вызова). `Standard` ставит в очередь; продвигать через `advanceUntilIdle()` или `runCurrent()` — использовать когда нужен явный контроль над порядком планирования.

Использовать Turbine для assertions Flow:

```kotlin
viewModel.state.test {
    assertTrue(awaitItem().isLoading)
    val loaded = awaitItem()
    assertFalse(loaded.isLoading)
    cancelAndIgnoreRemainingEvents()
}
```

Не использовать `delay()` или `Thread.sleep()` для ожидания coroutines в тестах.
