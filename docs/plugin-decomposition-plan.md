# Декомпозиция claude-global-settings → marketplace плагинов

## Контекст

Отказ от глобальной настройки по умолчанию: каждый проект настраивается при заведении (сгенерированный CLAUDE.md/AGENTS.md + плагины под тип проекта). Глобально остаётся минимум: стиль, запреты, принципы. Примеры проектов (НЕ исчерпывающий список — набор стеков открытый и будет расти): **(1)** Android / личный GitHub; **(2)** Android+iOS / рабочий GitLab; **(3)** локальные эксперименты без remote (Rust и др.); **(4)** non-dev проекты (видео/контент).

Решения пользователя: 8 плагинов (средняя гранулярность); git-core + отдельные github-flow/gitlab-flow; маркетплейс — **новый репо** `kirich1409/claude-plugins`; правила живут в плагинах и активны везде, где плагин включён; жёсткий запрет «главная сессия не пишет код» → в dev-workflow, глобально — мягкая формулировка.

Ограничения платформы: плагин НЕ несёт CLAUDE.md / paths-scoped правила / permissions / model / env / statusline. Несёт: skills, agents, hooks (SessionStart умеет инжектить контекст), .mcp.json, bin/ (в PATH), deps между плагинами (semver через теги `{name}--v{version}`). Субагенты hook-инъекцию главной сессии не наследуют (`rules/orchestration.md:33-37`) → стилевые правила доставляются через «агент обязан их Read».

---

## ФИНАЛЬНАЯ СТРУКТУРА kirich1409/claude-plugins

Легенда: ← = переносится из claude-global-settings (✏ = с переписыванием); ★ = создаётся с нуля.

```
.claude-plugin/marketplace.json                  ★ name: krozov-plugins, pluginRoot: ./plugins
CLAUDE.md                                        ★ repo-local: PR-only, русский для правил, результаты спайков
README.md                                        ★
scripts/validate-marketplace.sh                  ★ (форк ← scripts/validate-config.sh)
.github/workflows/validate.yml, gitleaks.yml     ← ✏
plugins/
│
├─ dev-workflow/                                 # конвейер, оркестрация, QA — архетипы 1,2,3
│  ├─ .claude-plugin/plugin.json                 ★ (deps: нет)
│  ├─ rules/                                     # инжектятся SessionStart-хуком (~675 строк)
│  │   workflow.md ✏  task-types.md  task-execution.md ✏(путь wait-for)
│  │   qa-and-testing.md  context-resilience.md  code-policies.md
│  │   dependencies.md  external-sources.md ✏(Android-строки → kotlin-android)
│  │   verify-library-api.md  model-effort-routing.md ✏  ast-index.md ✏
│  │   orchestration.md ✏✏ (сюда — жёсткий запрет из «Нельзя нарушать»;
│  │                        переписать ~/.claude-пути и раздел наследования)
│  ├─ rules-for-agents/                          # НЕ инжектятся; агенты читают перед правкой кода
│  │   code-style.md  logging.md                 ←
│  ├─ skills/  (11)
│  │   research/  write-spec/  write-plan/  implement-plan/  check/
│  │   finalize/  acceptance/  generate-test-plan/  multiexpert-review/
│  │   evaluate-dependency/  write-tests/ ✏(fallback general-purpose без stack-плагина)
│  ├─ agents/  (12)
│  │   code-reviewer  architecture-expert  debugging-expert  performance-expert
│  │   security-expert  devops-expert  dependency-evaluator  ux-expert
│  │   ui-accessibility-reviewer  business-analyst  manual-tester  source-researcher
│  ├─ hooks/hooks.json                           ★
│  │   SessionStart: inject-rules.sh ★ (cat rules/*.md) + warn-prereqs.sh ★
│  │   SessionStart: ast-index update/watch      ← ✏ (inline из settings.json:226, минус ~/.claude-исключение)
│  │   SessionEnd:   ast-index-stop-watch.sh     ←
│  │   PostToolUse(EnterWorktree): ast-index-bootstrap-worktree.sh  ←
│  └─ bin/wait-for.sh                            ←
│     Внешние prereqs (warn, не deps): ast-index CLI+plugin, Context7, ksrc, maven-mcp
│
├─ git-core/                                     # git без хостинга — архетипы 1,2,3
│  ├─ .claude-plugin/plugin.json                 ★
│  ├─ rules/git-workflow.md                      ← ✏ (минус секция ~/.claude PR-only)
│  ├─ skills/  create-pr/ ✏(degrade без github-flow)  drive-to-merge/  worktree-cleanup/
│  └─ hooks/hooks.json                           ★
│      PreToolUse: branch-guard.sh ✏(убрать исключение ~/.claude)  push-branch-guard.sh  stash-reminder.sh
│      SessionStart: git-state-banner            ← (inline из settings.json:231)
│
├─ github-flow/                                  # архетип 1; deps: git-core
│  ├─ .claude-plugin/plugin.json                 ★
│  ├─ rules/  github-ops.md ✏(пути → bin)  github-merge-policy.md ✏(GitLab-часть → gitlab-flow)
│  ├─ agents/gh-project-manager.md               ← ✏
│  └─ bin/  gh-common.sh  gh-fetch-issue  gh-list-issues  gh-add-comment  gh-link-pr
│           gh-get-completion-signal  gh-get-dependencies  gh-transition-status
│           (← scripts/gh/* ✏, переименованы с префиксом gh- от PATH-коллизий)
│     Prereq: gh CLI
│
├─ gitlab-flow/                                  # архетип 2; deps: git-core
│  ├─ .claude-plugin/plugin.json                 ★
│  └─ rules/gitlab-ops.md                        ★ (~40 строк: маппинг gh↔glab из github-ops.md:40
│                                                   + осторожный merge-профиль: MWPS с согласия,
│                                                   /check перед пушем, merge train)
│     Prereq: glab CLI
│
├─ kotlin-android/                               # архетипы 1,2; deps: dev-workflow
│  ├─ .claude-plugin/plugin.json                 ★
│  ├─ rules/                                     # agent-read (579 строк); paths: сохранён для материализации
│  │   kotlin-style.md  coroutines.md  compose-style.md  gradle-style.md  android-cli.md
│  ├─ agents/  kotlin-engineer ✏  compose-developer ✏  build-engineer ✏
│  │           (✏ = преамбул «Read правила плагина перед правкой кода»)
│  └─ hooks/hooks.json                           ★
│      SessionStart: роутер ★ (~10 строк: пути правил + «передавать их в prompt делегирования»)
│                    + append Android-строк source-routing ★ + warn android CLI ★
│     Prereqs: android CLI, ksrc, maven-mcp, Context7
│
├─ swift-ios/                                    # архетип 2; deps: dev-workflow
│  ├─ .claude-plugin/plugin.json                 ★
│  ├─ rules/                                     # agent-read (610 строк); кандидат №1 на материализацию
│  │   swift-concurrency.md  swift-testing.md  swiftui-design-system.md
│  │   swiftui-patterns.md  swiftui-performance.md  swiftui-state.md
│  ├─ agents/  swift-engineer ✏  swiftui-developer ✏
│  └─ hooks/hooks.json ★  (SessionStart: роутер ★)
│
├─ project-bootstrap/                            # любой проект; user-scope глобально — ВЕСЬ ПЛАГИН ★
│  ├─ .claude-plugin/plugin.json                 ★
│  └─ skills/
│      init-project/SKILL.md                     ★ «завожу проект» — generic-движок БЕЗ зашитой
│        матрицы стеков. Логика «какой плагин когда предлагать» живёт в МЕТАДАННЫХ плагинов
│        (marketplace.json: category/tags + detect-хинты), а не в bootstrap:
│        1) читает каталог подключённых маркетплейсов (krozov-plugins + внешние) —
│           каждый плагин декларирует в entry: category (stack/vcs/workflow/content/…),
│           tags и detect-маркеры (файлы: settings.gradle*, *.xcodeproj, Cargo.toml,
│           package.json…; remote: github.com/gitlab; или «предлагать всегда/спрашивать»)
│        2) сканирует проект и матчит detect-маркеры → кандидаты; ничего не сматчилось
│           (пустой каталог, non-dev) — тоже норма
│        3) интервью по одному вопросу: подтверждение кандидатов, выбор из остального
│           каталога, опции (доска? материализовать правила? язык доков?)
│        4) генерация CLAUDE.md проекта (для dev: build-команды, модули, PR/MR policy;
│           для non-dev: описание задачи/структуры материалов) + AGENTS.md
│        5) запись .claude/settings.json: extraKnownMarketplaces + выбранные enabledPlugins
│        6) опц. материализация rules → .claude/rules/ + манифест (SHA источников)
│        7) эмпирическая верификация (перезапуск, контрольный вопрос, пробный guard-блок)
│        Новый стек/домен (rust-плагин, видео/контент-плагины) = новая entry в marketplace
│        с tags/detect — bootstrap подхватывает без изменений своего кода.
│      sync-project-setup/SKILL.md               ★ drift-diff enabledPlugins и правил против манифеста
│
└─ safety-guards/                                # user-scope глобально; defaultEnabled: true
   ├─ .claude-plugin/plugin.json                 ★
   └─ hooks/hooks.json ★
       PreToolUse(Bash): secret-read-guard.sh ←  destructive-guard.sh ←
```

## Что создаётся С НУЛЯ (сводный список ★)

1. **Репо-инфраструктура**: marketplace.json; repo CLAUDE.md; README; validate-marketplace.sh (форк validate-config: schema-чек JSON, существование/исполняемость хуков, `bash -n`, запрет хардкода `~/.claude`, wiki-links только внутри плагина, «version изменён → тег обязателен»); 8 × plugin.json; 6 × hooks.json.
2. **Плагин project-bootstrap целиком** (init-project + sync-project-setup) — generic-движок «завожу проект»: матчит detect-метаданные из каталога маркетплейсов, без зашитого списка стеков; новые стеки/домены добавляются как plugin-entries с tags/detect. Соответственно marketplace.json каждой entry несёт category/tags/detect-хинты (★).
3. **gitlab-flow**: правило gitlab-ops.md (выделяется из github-ops/merge-policy + glab-специфика).
4. **Хуки-инжекторы**: inject-rules.sh (dev-workflow), роутеры kotlin-android/swift-ios, warn-prereqs для внешних зависимостей.
5. **Переписывания ✏**: orchestration.md (главное — под plugin-мир + жёсткий запрет), github-ops/merge-policy (разрез GitHub/GitLab), external-sources (вынос Android-строк), write-tests (fallback), create-pr (degrade), git-workflow/branch-guard (минус ~/.claude), преамбулы 5 stack-агентов, gh-скрипты (пути/имена).

## Что остаётся в claude-global-settings (тонкий остаток)

- **CLAUDE.md ~60-70 строк** ✏✏: «Нельзя нарушать» (git-баны; оркестрация → мягко «предпочитать делегирование в крупных кодовых задачах»), «Принципы», влитый communication.md, repo-local PR-only секция. Индекс правил удаляется.
- **settings.json** ✏: model/effort/language/tui; permissions/sandbox (в плагины непереносимы); statusline; hooks только auto-pull, gc-local-state, context-mode-cache-heal, notify; `extraKnownMarketplaces` + `krozov-plugins`; user-scope `enabledPlugins`: safety-guards, project-bootstrap + существующие внешние плагины (context7, ksrc, maven-mcp, security-guidance, remember, code-simplifier, claude-md-management, ast-index, context-mode, warp, wakatime); skillOverrides ✏ на `plugin:skill`-имена.
- **Sync-инфра**: auto-pull.sh, sync-settings.sh (csync), json-3way-merge.py + .gitattributes, statusline-command.sh, setup.sh ✏, bootstrap-machine.sh ✏ (+marketplace add), validate-config.sh ✏ (слим), cgs-pr.sh, gitleaks/validate CI.
- **DROP**: rules/claude-repo-pr-workflow.md (→ repo-local CLAUDE.md обоих репо), skills/find-skills (заменён нативным `/plugin`), индекс правил в CLAUDE.md.

Каждый из 30 rules / 15 skills / 18 agents / 13 hooks / всех scripts учтён выше — сирот нет.

## Механизмы доставки правил (сводка)

| Плагин | Механизм | Инжекция в контекст |
|---|---|---|
| dev-workflow | A: hook-инъекция + B: code-style/logging agent-read | ~675 строк (≈ сегодняшний always-on) |
| git-core / github-flow / gitlab-flow | A | ~30 / ~90 / ~40 строк |
| kotlin-android / swift-ios | B: agent-read + роутер; C: материализация по флагу init | ~10 строк роутер |
| safety-guards / project-bootstrap | только hooks/skills | 0 |

Итого Android-проект ≈ 715 строк — не хуже сегодняшнего глобального набора.

## Порядок миграции (аддитивно; глобальный конфиг не трогается до P7)

- **P0** Скелет репо + CI. Verify: `marketplace add`, установка заглушки, CI красный на сломанном JSON.
- **P1** Спайки: (а) лимит stdout SessionStart-хука (~45KB); (б) `${CLAUDE_PLUGIN_ROOT}` в телах agents/skills; (в) наследование субагентами project `.claude/rules` и hook-инъекции. Результаты → CLAUDE.md репо.
- **P2** safety-guards + git-core + github-flow; пилот — сам claude-plugins (dogfooding). Verify: guard блокирует push в main; реальный PR через create-pr/drive-to-merge.
- **P3** dev-workflow; пилоты: claude-plugins + Rust-эксперимент (архетип 3). Verify: свежая сессия видит правила; /write-plan на игрушечной задаче; wait-for.sh в PATH; ast-index watcher поднялся.
- **P4** kotlin-android, затем swift-ios; пилот — реальный Android-репо (архетип 1). Verify: kotlin-engineer реально читает правила (контрольная задача-провокация на нарушение стиля); замер контекста до/после.
- **P5** gitlab-flow + рабочий проект (архетип 2, среда с glab).
- **P6** project-bootstrap (generic-движок; проверенные в P2–P5 связки — лишь пресеты-примеры в метаданных плагинов). Verify: init с нуля по одному проекту каждого примера + проект «неизвестного» типа (пустой каталог) — движок корректно предлагает выбор из каталога, а не падает в зашитый сценарий.
- **P7** Global shrink одним PR (тонкий CLAUDE.md, удаление перенесённого, слим settings/validate). Verify: пустой каталог — только тонкий контекст; Android-пилот — всё через плагины; bootstrap-machine на второй машине.
- **P8** Уборка: DROP-файлы, README, ретро-чек statusline/.sync-status.

## Риски

1. Hook-инъекция не достигает субагентов → механизм B + P1-спайк.
2. Лимит stdout SessionStart → fallback: несколько hook-записей / материализация.
3. Внешние зависимости не выразимы как plugin-deps → prereqs + warn + проверка в init-project.
4. Кросс-плагинные ссылки правил → «если установлен X», CI-чек.
5. Двойная загрузка в переходный период (глобальные + пилот) — принято; не смешивать с замерами P4.
6. skillOverrides: проверить синтаксис `plugin:skill` после переезда.
7. Правило «русский для конфигов ~/.claude» → переформулировать на «для конфиг-репо»; skills остаются англоязычными.
