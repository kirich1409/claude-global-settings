---
paths:
  - "**/*.swift"
---

# SwiftUI Patterns — неочевидное

Только то, что модель опускает или применяет ошибочно. Когда выделять sub-view, `@ViewBuilder` для
контейнеров, enum-роуты, базовая настройка `#Preview` здесь не документируются.

## `AnyView` ломает diffing

Модель тянется к `AnyView`, когда generics становятся неудобными. Это баг корректности, а не просто
удар по производительности: `AnyView` стирает статический тип, который SwiftUI использует для
identity и diffing.

```swift
// НЕ ТАК — стирание типа ломает diffing
var content: AnyView { AnyView(makeView()) }

// ТАК — generics + @ViewBuilder, компилятор отслеживает конкретные типы
struct Card<Content: View>: View {
    @ViewBuilder let content: () -> Content
    var body: some View { /* ... */ }
}
```

Стирания не избежать — предпочитать `Group { ... }` или рефакторинг, возвращающий `some View`.

## Кастомный модификатор — extension, а не `.modifier(X())`

Модификатор со state — `ViewModifier`; stateless цепочка — обычный extension на `View`. Место
вызова всегда оборачивать методом-extension (`.shimmer()`, `.cardStyle()`): `.modifier(SomeModifier())`
раскрывает тип реализации и читается хуже.

## Роутинг — `.navigationDestination` в корне `NavigationStack`

Неочевидное: `navigationDestination(for:)` должен быть в корне стека. Размещение у потомка молча
ломает роутинг после первого push.

```swift
NavigationStack(path: $path) {
    HomeScreen()
        .navigationDestination(for: Route.self) { route in /* все case здесь */ }
}
```

`NavigationLink(destination:)` для нового кода deprecated — использовать `NavigationLink(value:)` в
паре с `.navigationDestination`.

## Sheets — один модификатор, item-based, enum

Несколько модификаторов `.sheet` на одном view — срабатывает только последний. Консолидировать в
один, управляемый `Identifiable`-enum: `@State private var activeSheet: SheetType?` и
`.sheet(item: $activeSheet) { ... }`. Не управлять sheets набором булевых флагов. То же для alert и
confirmation dialog.

## Identity в `ForEach` — `id: \.self` ловушка на мутируемых данных

`id: \.self` годится только для неизменяемых коллекций простых значений (`[String]`, `[Int]`,
enums). Для модели с мутирующими полями identity меняется вместе с содержимым: анимации ломаются,
`@State` сбрасывается, фокус прыгает.

Использовать `Identifiable` или явный keypath `\.id`. **Никогда не индекс массива**
(`enumerated()` + `id: \.offset`) — вставки и удаления перенесут анимации и view-local state не на
те строки.

## `.task` отменяется при disappear, `Task` в `onAppear` — нет

```swift
// ТАК — отменяется автоматически, когда view исчезает
.task { orders = await fetchOrders() }
// ТАК — перезапускается при изменении зависимости
.task(id: selectedCategory) { orders = await fetchOrders(in: selectedCategory) }

// НЕ ТАК — Task продолжается после исчезновения view, утекает работа и пишет в мёртвый state
.onAppear { Task { orders = await fetchOrders() } }
```

Модель всё ещё выдаёт `onAppear + Task {}` из старых training-данных.

## `if` уничтожает state, `.opacity` сохраняет

`if cond { TextField(...) }` — это разный view в дереве в зависимости от `cond`: переключение
уничтожает предыдущий экземпляр вместе с фокусом, scroll offset и любым `@State`. Чтобы переключать
видимость с сохранением state:

```swift
TextField("Search", text: $query)
    .opacity(showSearch ? 1 : 0)
    .frame(height: showSearch ? nil : 0)
    .allowsHitTesting(showSearch)
```

Для действительно разных иерархий (залогинен или нет, список или ошибка) `if` корректен. Ловушка —
использовать `if` именно для переключения видимости.

## Условный модификатор `.if {}` — анти-паттерн

Широко рекомендуемый и широко неправильный: тип возвращаемого значения меняется вместе с условием,
что путает diffing — та же проблема identity, что выше. Применять модификаторы условно инлайн,
через тернарный оператор на значении модификатора, а не на его наличии:

```swift
Text("Status")
    .foregroundStyle(isActive ? .green : .secondary)
    .fontWeight(isActive ? .bold : .regular)
```

## Превью — статичные сэмплы на модели

Добавлять `static let samples` (или `static func sample(...)`) на доменный тип, а не конструировать
тестовые данные инлайн в каждом `#Preview`. Только захардкоженные данные: ни живой сети, ни реальной
модели с I/O. Следовать конвенции превью проекта (`#Preview("name", traits:)`, dark/light,
multi-device).
