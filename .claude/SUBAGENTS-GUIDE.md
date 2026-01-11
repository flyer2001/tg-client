# Гайд по субагентам для telegram-client

## Что создано

### Глобальные Swift агенты (`~/.claude/agents/swift/`)
Работают для **ВСЕХ** Swift проектов на этой машине:

1. **`diagnostics-swift.md`** — поиск багов
   - 5-фазный workflow (statical → build → runtime → root cause → fix)
   - Swift Concurrency, SwiftUI, Memory, Optionals
   - Execution confidence: автоматически build/test БЕЗ подтверждения

### Локальные агенты (`.claude/agents/`)
Работают **ТОЛЬКО** для telegram-client:

1. **`tdlib-integration.md`** — TDLib эксперт
   - Research TDLib docs (core.telegram.org)
   - Swift Concurrency patterns для TDLib
   - Known issues & workarounds

## Правило явной индикации (КРИТИЧНО!)

**При работе с субагентом Claude ВСЕГДА указывает:**

```
🤖 СУБАГЕНТ: swift-diagnostics
🎭 РОЛЬ: Bugfix Specialist
🧠 МОДЕЛЬ: sonnet
---
[Далее работа субагента]
```

Это помогает понимать **КТО** работает и **ЗАЧЕМ** такая комбинация.

**Варианты:**
- Субагент + Роль: `swift-diagnostics + Senior Swift Architect`
- Только субагент: `tdlib-integration (без роли)`
- Только роль: `Senior Testing Architect (без субагента)`

---

## Как вызывать субагентов

### Способ 1: Простой вызов (рекомендуется для начала)

Просто попроси Claude использовать субагента в промпте:

```
Use swift-diagnostics subagent to find the bug in TDLibClient.
```

или

```
Use tdlib-integration subagent to help me implement getChats method.
```

**Что произойдёт:**
```
🤖 СУБАГЕНТ: swift-diagnostics
🎭 РОЛЬ: НЕТ (автономная диагностика)
🧠 МОДЕЛЬ: sonnet
---
Начинаю 5-фазную диагностику...
```

### Способ 2: JSON handoff (для сложных задач)

Структурированный запрос с чёткими критериями:

```json
{
  "task_id": "DIAG-001",
  "agent": "swift-diagnostics",
  "goal": "Find root cause of intermittent 401 errors in Auth flow",
  "inputs": {
    "repo_paths": ["Sources/TDLibAdapter"],
    "symptoms": ["Random 401 after 30 min", "Happens only in production"]
  },
  "constraints": {
    "do_not": ["modify production code without approval"],
    "allowed_commands": ["swift build", "swift test", "grep"]
  },
  "deliverables": {
    "format": "structured",
    "include": ["root_cause", "evidence (file:line)", "fix_proposal"]
  },
  "done_when": [
    "Root cause identified with evidence",
    "Fix proposal provided with diff",
    "No guesses, only facts"
  ]
}
```

## Примеры использования

### Пример 1: Диагностика Swift Concurrency ошибки

**Промпт:**
```
Use swift-diagnostics to find data races in TDLibClient actor.
Focus on: shared mutable state, Sendable violations, @MainActor issues.
```

**Что агент сделает:**
1. Статический анализ кода (Фаза 1)
2. Запустит `swift build` (Фаза 2)
3. Добавит временные debug prints (Фаза 3)
4. Проанализирует runtime behaviour (Фаза 4)
5. Выдаст root cause + fix proposal (Фаза 5)

### Пример 2: Research TDLib метода

**Промпт:**
```
Use tdlib-integration subagent.
Task: Research how to implement pagination for getChatHistory.
Include: method signature, parameters, Swift async/await pattern, edge cases.
```

**Что агент сделает:**
1. Найдёт метод в TDLib docs (core.telegram.org)
2. Проанализирует параметры (offset, limit, from_message_id)
3. Предложит Swift Concurrency pattern
4. Опишет edge cases (empty list, pagination end)
5. Покажет working code example

### Пример 3: Комбинация агентов

**Сценарий:** Нужно добавить новый TDLib метод и убедиться что нет багов

```
Step 1: Use tdlib-integration to research getUnreadChats method.
Step 2: Implement the method based on research.
Step 3: Use swift-diagnostics to check for concurrency issues.
```

## Структура агентов (2-уровневая)

```
MD файл (статические правила)
├── name, description, model, color
├── Execution Confidence Rules (что можно без подтверждения)
├── Workflow Phases (последовательность действий)
├── Common Patterns (типичные паттерны)
└── Output Format (формат ответа)

JSON prompt (динамическая задача)
├── task_id
├── agent (имя субагента)
├── goal (чёткая цель)
├── inputs (файлы, assumptions)
├── constraints (что НЕ делать)
├── deliverables (формат ответа)
└── done_when (критерии готовности)
```

## Преимущества субагентов

1. **Экономия токенов** — субагент работает в отдельной сессии, не загружает основной контекст
2. **Специализация** — каждый агент эксперт в своей области
3. **Reproducibility** — JSON handoff = чёткий контракт, можно воспроизвести
4. **Параллелизм** — можно запускать несколько субагентов одновременно

## Когда НЕ использовать субагентов

- ❌ Простые однократные запросы ("что делает эта функция?")
- ❌ Когда нужен ПОЛНЫЙ контекст проекта (субагент его не имеет)
- ❌ Итеративный диалог с уточнениями (субагент автономный)

## Следующие шаги

1. ✅ Глобальные агенты созданы (`diagnostics-swift.md`)
2. ✅ Локальный агент создан (`tdlib-integration.md`)
3. ⏳ Протестировать на реальной задаче
4. ⏳ Создать дополнительные агенты:
   - `test-swift.md` — XCTest/Swift Testing best practices
   - `security-ios.md` — OWASP чеклист

## Ссылки

- **HYP-001:** `~/Library/Mobile Documents/iCloud~md~obsidian/Documents/MyRep/_project-hub/hypotheses/active/HYP-001-subagents-perplexity.md`
- **Kotlin reference:** https://github.com/AlexGladkov/claude-code-agents
- **Claude Code docs:** https://docs.claude.ai/agents
