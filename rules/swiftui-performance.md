---
paths:
  - "**/*.swift"
---

# SwiftUI Performance — ловушки

## `.animation(_:value:)` требует `value`

`.animation(.default)` без параметра `value:` **deprecated** и анимирует каждое изменение state в
поддереве, включая несвязанные. Модель всё ещё выдаёт форму без value из старых training-данных.

```swift
Text("Count: \(count)")
    .animation(.spring, value: count)
```

## `.frame()` не выполняет downsampling

`.frame(width:height:)` задаёт только **отображаемый** размер. Изображение всё равно декодируется в
полном разрешении и хранится в памяти в полном разрешении: на списке со 100 большими удалёнными
изображениями это раздувает память, даже если каждый thumbnail 80×80. Реально снижает стоимость
`preparingThumbnail(of:)` или downsampling на уровне данных. `AsyncImage(url:).frame(80, 80)` задачу
не решает.

## Аллокации в `body`

`let formatter = DateFormatter()` внутри `body` создаётся заново при каждом рендере — SwiftUI
переоценивает `body` постоянно. Выносить в `static let`; то же для sort/filter/map больших
коллекций.
