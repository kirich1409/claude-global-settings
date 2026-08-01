# create-pr — паттерны обнаружения визуальных изменений

Ссылается из: `~/.claude/skills/create-pr/SKILL.md` (§7.3).

Смотреть на пути изменённых файлов:

- Android/Compose: `*Screen.kt`, `*Composable.kt`, `res/layout/`, `res/drawable/`
- Compose Multiplatform: те же паттерны Kotlin UI плюс UI-каталоги в `commonMain`
- Web: `*.tsx`, `*.jsx`, `*.css`, `*.scss`, `*.html`
- iOS: `*View.swift`, `*Screen.swift`, `Views/`, `Screens/`, `*.xib`, `*.storyboard`
  (обычный `*.swift` слишком широк — большинство Swift-файлов не про UI; сопоставлять по суффиксу и
  каталогу)

Визуальные изменения обнаружены — включить раздел «Screenshots / demo» и запросить у пользователя
вложения в режимах `draft` и `promote`. `refresh` сохраняет существующее содержимое раздела.
