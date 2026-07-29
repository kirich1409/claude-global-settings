---
paths:
  - "**/*.kt"
---

# Compose

Только неочевидное: правила, которые модель опускает без напоминания, поведение, зависящее от
конфигурации проекта, и места, где дефолт модели расходится с нужным. Общие идиомы (`remember`,
`rememberSaveable`, `key` в `LazyColumn`, `derivedStateOf`, state hoisting, UDF, `on*`-callbacks)
здесь не документируются — доверять модели и Compose Lint. Coroutines внутри composable —
`coroutines.md`, стиль Kotlin — `kotlin-style.md`.

## Паттерн Screen

Composable экрана — stateless:

```kotlin
@Composable
internal fun FooScreen(
    state: FooState,
    onAction: (FooAction) -> Unit,
    modifier: Modifier = Modifier,
)
```

`viewModel()` / `hiltViewModel()` / `koinViewModel()` вызывается один раз в точке входа навигации
(`FooRoute`) — никогда внутри `FooScreen` и никогда в переиспользуемых компонентах. `ViewModel` не
передаётся параметром composable: это ломает переиспользуемость и превью.

## Запрещённые типы параметров

- `MutableState<T>` — hoist как `value: T` + `onValueChange: (T) -> Unit`.
- `State<T>` — передавать значение напрямую.
- `ViewModel` — см. выше.

## Кастомные модификаторы — `Modifier.Node`, не `composed {}`

`Modifier.composed {}` deprecated и примерно на 80% медленнее: аллоцирует при каждой композиции и
ломает шаринг модификаторов. Модель всё ещё выдаёт его из старых training-данных.

| Сценарий | Подход |
|---|---|
| комбинация существующих модификаторов | обычная цепочка extension-функций |
| нужна анимация или `CompositionLocal` | `@Composable`-фабрика модификатора |
| drawing, layout, input, semantics | `Modifier.Node` + `ModifierNodeElement` |

## Stability зависит от конфигурации проекта

- **Strong skipping** (дефолт в Compose Compiler 2.0+ / Kotlin 2.0+) → `@Stable`/`@Immutable` менее
  критичны, компилятор скипает и нестабильные параметры, обычные `List`/`Map` работают. Аннотации
  остаются полезны как документация намерения.
- **Strong skipping выключен** (`composeCompiler { enableStrongSkippingMode.set(false) }` или более
  старый компилятор) → аннотации важны, коллекции нестабильны, использовать
  `kotlinx.collections.immutable`, если это принято в проекте.

Всегда следовать конвенции проекта: существующие state-классы используют `@Immutable` — добавлять и
в новые. Проверять `stability_config.conf` на кросс-модульные правила.

## Отложение фазы через lambda-модификаторы

Compose исполняется в три фазы: Composition → Layout → Drawing. Lambda-перегрузки модификаторов
позволяют пропускать ранние фазы, когда обновляться должны только поздние. Модель рефлекторно
берёт value-перегрузку.

```kotlin
// Хорошо — пропускает composition, работает в layout
Box(Modifier.offset { IntOffset(offsetX().roundToInt(), 0) })
// Плохо — полная рекомпозиция каждый кадр
Box(Modifier.offset(x = offsetX.dp, y = 0.dp))

// Хорошо — пропускает composition и layout, работает в draw
Box(Modifier.fillMaxSize().drawBehind { drawRect(animatedColor) })
// Плохо — рекомпозиция каждый кадр
Box(Modifier.fillMaxSize().background(animatedColor))
```

Часто изменяющийся `State` в модификатор — брать lambda-перегрузку (`offset {}`, `drawBehind {}`,
`graphicsLayer {}`). В кастомных composable передавать `() -> T` вместо `T`, чтобы отложить чтение.

## `rememberUpdatedState` для долгоживущих эффектов

В `LaunchedEffect(Unit)` и `DisposableEffect` захваченная напрямую lambda замерзает на значении
момента старта эффекта, а не последнем:

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

## Исчерпывающий `when` без `else`

`when` над sealed state или action должен быть исчерпывающим без `else`, чтобы компилятор ловил
пропущенные случаи при добавлении подтипа. `else -> {}` глушит компилятор и молча проглатывает
новые подтипы.

## Токены темы

Есть система токенов (`AppDimens.spacingM`, `AppColors.primary`, `AppTypography.titleMedium`) —
никаких сырых `dp` и hex в коде экрана. Нет токенов и проект использует `MaterialTheme.colorScheme`
напрямую — следовать этому.

## Accessibility за пределами `contentDescription`

- `Modifier.semantics { role = Role.Button }` на кастомных интерактивных composable с собственной
  обработкой клика.
- `mergeDescendants = true` на составных рядах, где screen reader должен читать заголовок и
  подзаголовок единым блоком.
- `Modifier.minimumInteractiveComponentSize()`, когда визуальный элемент меньше 48×48 dp, но
  интерактивен.

## KMP / Compose Multiplatform

- Никаких `android.*`, `java.*`, `javax.*`, `dalvik.*` в `commonMain`.
- Ресурсы через `org.jetbrains.compose.resources` — **API менялся несколько раз между версиями CMP**.
  Читать существующее использование в проекте, не предполагать.
- `expect`/`actual` только для платформенной реализации, UI-логика в `commonMain`.
- Проверять наличие KMP-артефактов у зависимости до использования в common-коде.
- Платформенный UI (iOS touch handling, SwiftUI/UIKit interop, desktop) сверять с актуальной
  документацией.

## Превью

Превью получает захардкоженный state — никогда `viewModel()`, репозиторий или реальные данные:
это ломает tooling и часто делает превью некомпилируемыми. Всегда `private`, всегда обёрнуто в
тему проекта. Для экранов — покрытие нескольких состояний (loading, error, empty, populated).
