---
paths:
  - "**/*.kt"
---

# Compose — конфиг-зависимое и проектное

## Stability зависит от конфигурации проекта

- **Strong skipping** (дефолт в Compose Compiler 2.0+ / Kotlin 2.0+) → `@Stable`/`@Immutable` менее
  критичны, компилятор скипает и нестабильные параметры, обычные `List`/`Map` работают. Аннотации
  остаются полезны как документация намерения.
- **Strong skipping выключен** (`composeCompiler { enableStrongSkippingMode.set(false) }` или более
  старый компилятор) → аннотации важны, коллекции нестабильны, использовать
  `kotlinx.collections.immutable`, если это принято в проекте.

Проверять `stability_config.conf` на кросс-модульные правила и следовать конвенции проекта:
существующие state-классы используют `@Immutable` — добавлять и в новые.

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

## Compose Multiplatform

Ресурсы через `org.jetbrains.compose.resources` — **API менялся несколько раз между версиями CMP**.
Читать существующее использование в проекте, не предполагать. Платформенный UI (iOS touch handling,
SwiftUI/UIKit interop, desktop) сверять с актуальной документацией.
