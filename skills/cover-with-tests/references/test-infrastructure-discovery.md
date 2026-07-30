# Обнаружение тестовой инфраструктуры

Reference для фазы 4 скилла `cover-with-tests` — точка входа в `../SKILL.md`.

Пользоваться этими таблицами, осматривая существующие проверки (три-пять образцов, если они есть) и
конфигурацию сборки, чтобы собрать Test Infrastructure Summary, который питает генерацию кода дальше.
Сгенерированные проверки должны быть неотличимы от написанных в проекте вручную: не вводить новый
фреймворк, библиотеку утверждений или инструмент подмены.

Таблицы ниже перечисляют экосистемы, у которых сегодня есть профильный инженерный агент. Стек, которого
здесь нет, — не повод остановиться: те же категории обнаруживаются в его конфигурации сборки и
существующих проверках, а результат ложится в тот же Summary.

## Обнаружить фреймворки и библиотеки

| Категория | Что искать | Где искать |
|---|---|---|
| Тестовый фреймворк (Kotlin) | JUnit 4, JUnit 5, Kotest | зависимости в `build.gradle(.kts)`, импорты существующих тестов |
| Тестовый фреймворк (Swift) | Swift Testing (`@Test` / `@Suite`), XCTest (`XCTestCase`), Quick | зависимости в `Package.swift`, тестовые таргеты Xcode, импорты существующих тестов |
| Библиотека утверждений | Truth, AssertJ, матчеры Kotest, `kotlin.test`, `#expect`, `XCTAssert*`, матчеры Nimble | импорты и утверждения существующих тестов |
| Подмены и двойники | MockK, Mockito-Kotlin, ручные фейки; в Swift фейки, стабы и шпионы за протоколами | импорты существующих тестов, `@MockK`, `mock()`, классы `Fake*`/`Stub*`/`Spy*` |
| Асинхронность в тестах | `kotlinx-coroutines-test` (`runTest`), Turbine; в Swift async-тесты, `withCheckedContinuation`, `XCTestExpectation` | импорты существующих тестов, конфигурация сборки |
| UI-тестирование | Compose `createComposeRule`, `compose-ui-test`; ViewInspector, XCUITest, snapshot-тесты | импорты существующих тестов, конфигурация сборки |
| DI в тестах | Hilt test, Koin test, ручная конструкция (оба стека) | паттерны подготовки в существующих тестах |

## Обнаружить конвенции

| Конвенция | Что искать | Как |
|---|---|---|
| Именование | `should verb`, `test verb`, имена в бэктиках, `given_when_then`, описательные строки Swift Testing (`@Test("Empty cart shows zero total")`) | прочитать имена существующих тестовых функций и `@Test` |
| Размещение файлов | Kotlin: тот же пакет, что у исходника, либо отдельный тестовый пакет; Swift: `Tests/<Target>Tests/` (SwiftPM) либо тестовый таргет Xcode, соответствующий модулю | сравнить расположение тестовых файлов с исходными |
| Именование тестовых классов | `ClassNameTest`, `ClassNameSpec`, `ClassNameTests`; в Swift структуры `@Suite` или наследники `XCTestCase` с именем `<Type>Tests` | прочитать имена существующих тестовых классов и сьютов |
| Паттерн подготовки | `@Before` / `@BeforeEach`, `init {}`, builder или фабрика; в Swift Testing `init` / `deinit`, в XCTest `setUp` / `tearDown` | прочитать блоки подготовки существующих тестов |
| Стиль утверждений | текучий (`assertThat(x).isEqualTo(y)`) против простого (`assertEquals`); `#expect(...)` против `XCTAssertEqual(...)` | прочитать существующие утверждения |

## Шаблон Test Infrastructure Summary

Свести находки в структурированную сводку, которую агент генерации кода потребляет дословно:

```
## Test Infrastructure Summary

**Platform:** {Kotlin/Android / Swift/iOS / Swift/macOS / KMP / <другая экосистема>}
**Framework:** {JUnit 4 / JUnit 5 / Kotest / Swift Testing / XCTest / Quick / <обнаруженный>}
**Assertions:** {Truth / AssertJ / Kotest matchers / kotlin.test / #expect / XCTAssert / Nimble / <обнаруженный>}
**Test doubles:** {MockK / Mockito-Kotlin / manual fakes / protocol-backed fakes / stubs / spies / none}
**Async testing:** {runTest + Turbine / runTest / runBlocking / async tests / XCTestExpectation / none}
**UI testing:** {compose-ui-test / ViewInspector / XCUITest / snapshot / none}

**Naming convention:** {описание — «имена в бэктиках с префиксом should» либо «описательные строки Swift Testing»}
**Class / suite naming:** {«ClassNameTest», «@Suite struct FooTests»}
**File placement:** {«тот же пакет в src/test/kotlin/» либо «Tests/AuthTests/»}
**Setup pattern:** {«@Before с аннотациями MockK» либо «init/deinit в Swift Testing»}
**Assertion style:** {«текучие утверждения Truth» либо «#expect с описательными тестами»}

**Example test file:** {путь к репрезентативному существующему тесту для образца}
```

Заголовки разделов и имена полей держать неизменными — промпты дальше по потоку рассчитывают на эту
структуру.
