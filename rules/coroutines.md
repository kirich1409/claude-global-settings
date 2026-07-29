---
paths:
  - "**/*.kt"
---

# Coroutines и Flow — ловушки

## Порядок операторов Flow

- `flowOn(dispatcher)` влияет только на upstream. Вызов дважды или после терминального оператора
  тихо ничего не делает. Применять один раз, на стороне producer.
- `retry {}` ставится **до** `catch {}`: если `catch` выполнится первым, он поглотит ошибку и
  `retry` её не увидит.

## Бесконечная приостановка

`first()`, `single()` и `Channel.receive()` висят до прихода данных — источник не эмитирует,
coroutine зависает навсегда. Опасно для `SharedFlow(replay = 0)` (ждёт следующего emit), `Channel`
и cold `flow {}`, чей producer может не эмитировать: там нужен `withTimeout` либо `tryReceive()`.
`StateFlow` безопасен — значение есть всегда. `firstOrNull()` — когда отсутствие данных допустимый
исход, а не ошибка.

## `withContext(NonCancellable)` — только в `finally`

`NonCancellable` отключает отмену для всего внутри. Допустим исключительно в cleanup, который обязан
завершиться после отмены. В любом другом месте это баг: отключает кооперативную отмену вверх по
цепочке.

## Тестирование

Все `TestDispatcher` в одном тесте используют **один** `TestCoroutineScheduler` — иначе
`advanceUntilIdle()` не распространяется. Перед тестированием всего, что использует `viewModelScope`,
заменять Main: `Dispatchers.setMain(testDispatcher)` в `@Before`, `resetMain()` в `@After`. Для
assertions по Flow — Turbine.
