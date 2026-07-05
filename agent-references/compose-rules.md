# Compose Rules

Специфичные для проекта конвенции Compose и неочевидные подводные камни, выходящие за рамки того, что современная модель пишет по умолчанию. Общие идиомы Compose — `remember` для кэшируемых значений, `rememberSaveable` для config changes, `key` в `LazyColumn` для динамических элементов, `derivedStateOf` для производного state, state hoisting, UDF, PascalCase, `on*` callbacks — здесь **не** документируются; доверяй модели и Compose Lint.

Этот файл перечисляет только:
- Действительно неочевидные правила, которые модель опускает без напоминания
- Поведение, зависящее от конфигурации проекта (stability под strong skipping)
- Сильные мнения там, где дефолт модели отличается

Про coroutines внутри composable-функций (`LaunchedEffect`, `rememberCoroutineScope`, сбор Flow) — см. `coroutines.md`. Про стиль Kotlin — см. `kotlin-style.md`.

---

## Паттерн Screen

Composable-функция экрана должна быть **stateless**:

```kotlin
@Composable
internal fun FooScreen(
    state: FooState,
    onAction: (FooAction) -> Unit,
    modifier: Modifier = Modifier,
)
```

- `viewModel()` / `hiltViewModel()` / `koinViewModel()` разрешается **один раз в точке входа навигации** (`FooRoute`), никогда внутри `FooScreen` и никогда внутри переиспользуемых shared-компонентов.
- Никогда не передавать `ViewModel` как параметр composable-функции — модель иногда делает это ради удобства; это ломает переиспользуемость и возможность превью.

## Запрещённые типы параметров

Никогда не принимать следующее как параметры composable-функции:

- `MutableState<T>` — hoist как `value: T` + `onValueChange: (T) -> Unit`
- `State<T>` — передавать значение напрямую
- `ViewModel` — см. паттерн Screen выше

Модель иногда использует `MutableState` как short-cut. Не делать так.

## Кастомные модификаторы — Modifier.Node, никогда не `composed {}`

`Modifier.composed {}` deprecated и ~на 80% медленнее (аллоцирует при каждой композиции, ломает шаринг модификаторов). Модель всё ещё выдаёт `composed {}` из старых training-данных — явно выбирать `Modifier.Node`:

| Сценарий | Подход |
|---|---|
| Комбинация существующих модификаторов | Обычная цепочка extension-функций |
| Нужна анимация или `CompositionLocal` | `@Composable`-фабрика модификатора |
| Drawing, layout, input, semantics | `Modifier.Node` + `ModifierNodeElement` |

```kotlin
private class FooNode(...) : Modifier.Node(), DrawModifierNode {
    override fun ContentDrawScope.draw() { /* ... */ }
}
private data class FooElement(...) : ModifierNodeElement<FooNode>() {
    override fun create() = FooNode(...)
    override fun update(node: FooNode) { /* update fields */ }
}
fun Modifier.foo(...): Modifier = this then FooElement(...)
```

## Stability — зависит от конфигурации проекта

Важны ли `@Stable` / `@Immutable`, зависит от конфигурации Compose Compiler:

- **Strong skipping mode** (дефолт в Compose Compiler 2.0+ / Kotlin 2.0+) → аннотации **менее критичны**; компилятор скипает даже нестабильные параметры. Обычные `List` / `Map` работают для skipping. Аннотации остаются полезны как документация намерения.
- **Strong skipping выключен** (`composeCompiler { enableStrongSkippingMode.set(false) }` или более старый компилятор) → аннотации важны. Коллекции нестабильны; использовать `kotlinx.collections.immutable` (`ImmutableList`), если это принято в проекте.

**Всегда следовать существующей конвенции проекта.** Если существующие state-классы используют `@Immutable`, добавлять её и в новые для консистентности. Проверить `stability_config.conf` на кросс-модульные правила, если он существует.

## Производительность — отложение фазы через lambda-модификаторы

Compose выполняется в три фазы: **Composition → Layout → Drawing**. Lambda-based перегрузки модификаторов позволяют runtime пропускать более ранние фазы, когда обновляться нужно только более поздним. Модель часто рефлекторно выбирает value-based перегрузку.

```kotlin
// Хорошо — пропускает composition, выполняется только в layout
Box(Modifier.offset { IntOffset(offsetX().roundToInt(), 0) })

// Плохо — полная рекомпозиция каждый кадр
Box(Modifier.offset(x = offsetX.dp, y = 0.dp))

// Хорошо — пропускает composition + layout, выполняется только в draw
Box(Modifier.fillMaxSize().drawBehind { drawRect(animatedColor) })

// Плохо — рекомпозируется каждый кадр
Box(Modifier.fillMaxSize().background(animatedColor))
```

При передаче часто изменяющегося `State` в модификатор предпочитать lambda-перегрузку (`offset { }`, `drawBehind { }`, `graphicsLayer { }`).

Также: передавать `() -> T` вместо `T`, чтобы отложить чтения в кастомных composable-функциях, когда значение обновляется часто.

## Side Effects — `rememberUpdatedState` для долгоживущих эффектов

Внутри `LaunchedEffect(Unit)` или `DisposableEffect` lambda-параметры, захваченные напрямую, будут иметь значение с момента *старта* эффекта — не последнее. Использовать `rememberUpdatedState`, чтобы держать захваченный callback свежим без перезапуска эффекта:

```kotlin
@Composable
fun FooScreen(onTimeout: () -> Unit) {
    val currentOnTimeout by rememberUpdatedState(onTimeout)
    LaunchedEffect(Unit) {
        delay(5_000)
        currentOnTimeout() // всегда последняя lambda
    }
}
```

Модель иногда захватывает исходную lambda напрямую и выдаёт баг с устаревшим callback.

## Исчерпывающий `when` без `else`

`when` над sealed state / action типом **должен быть исчерпывающим без ветки `else`**. Компилятор должен ловить пропущенные case при добавлении нового подтипа. Модель иногда пишет `else -> {}`, чтобы заглушить компилятор — это молча проглатывает новые подтипы.

```kotlin
when (action) {
    is FooAction.ItemClicked -> handle(action.id)
    FooAction.Refresh -> refresh()
    // Нет else — добавление нового подтипа FooAction должно быть ошибкой компиляции.
}
```

## Токены темы — никаких сырых `dp` / hex

Если в проекте есть система токенов (`AppDimens.spacingM`, `AppColors.primary`, `AppTypography.titleMedium`) — никогда не выдавать сырые литералы `dp` или hex-значения цвета в коде экрана. Использовать токены.

Если в проекте нет токенов и используется `MaterialTheme.colorScheme.x` напрямую — следовать этому. Обнаруживается на шаге 1 compose-developer.

## Accessibility — за пределами `contentDescription`

Модель по умолчанию пишет `contentDescription`. Часто упускается:

- **`Modifier.semantics { role = Role.Button }`** на кастомных интерактивных composable-функциях (кастомная обработка клика без использования `Button`/`IconButton`)
- **`mergeDescendants = true`** на составных рядах, где screen reader должен читать заголовок + подзаголовок как единый блок
- **`Modifier.minimumInteractiveComponentSize()`**, когда визуальный элемент меньше 48×48 dp, но интерактивен

```kotlin
Icon(
    imageVector = Icons.Default.Close,
    contentDescription = stringResource(R.string.close),
    modifier = Modifier
        .clickable(role = Role.Button) { onAction(FooAction.Dismiss) }
        .minimumInteractiveComponentSize(),
)
```

## KMP / Compose Multiplatform

- Никакого `android.*` / `java.*` / `javax.*` / `dalvik.*` в `commonMain`
- Ресурсы через API `org.jetbrains.compose.resources` — **API менялся несколько раз в разных версиях CMP**. Читать существующее использование ресурсов в проекте; не предполагать.
- `expect`/`actual` только для платформо-специфичной реализации; UI-логика в `commonMain`
- Проверять, что у каждой зависимости есть KMP-артефакты, прежде чем использовать в common-коде
- Платформо-специфичный UI (iOS touch handling, SwiftUI / UIKit interop, desktop) — сверять с актуальной документацией, не предполагать форму API

## Превью — никогда не ViewModel

Превью получает **захардкоженный state**, никогда не `viewModel()` / репозиторий / реальные данные. Модель иногда подключает VM в превью «для реалистичности» — это ломает tooling и часто делает превью некомпилируемыми.

Превью всегда `private`, всегда обёрнуты в composable-функцию темы проекта. Покрытие нескольких состояний (loading / error / empty / populated) — конвенция для превью экранов.
