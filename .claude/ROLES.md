# ROLES.md

Выбор роли, субагента и MCP клиента по типу задачи.

---

## 🎯 Таблица выбора (единая точка входа)

| Тип задачи | Роль | Субагент | MCP | Модель | Читать |
|------------|------|----------|-----|--------|--------|
| Планирование фичи | Planning Architect | — | OpenAI (second opinion) | **opus** | MVP.md, ARCHITECTURE.md |
| Новый TDLib метод | Planning Architect | tdlib-integration | Perplexity (docs) | sonnet | TESTING.md |
| Новый компонент | Senior Swift Architect | — | — | **opus** | ARCHITECTURE.md |
| Написание тестов | Senior Testing Architect | — | — | sonnet | TESTING.md |
| Реализация кода | Senior Swift Developer | — | — | sonnet | TESTING-PATTERNS.md |
| Поиск бага | Bugfix Specialist | swift-diagnostics | — | sonnet | TROUBLESHOOTING.md |
| Concurrency issue | Senior Swift Developer | swift-diagnostics | Perplexity (best practices) | sonnet | TESTING-PATTERNS.md |
| Code Review (утро) | Senior Code Reviewer | swift-diagnostics (optional) | OpenAI (second opinion) | sonnet | ARCHITECTURE.md |
| Ретроспектива | AI-Assisted Developer | — | OpenAI (second opinion) | sonnet | TASKS.md |

**Примечание:** Для архитектурных задач используй **opus модель**.

---

## 🎭 Роли (краткие описания)

### 1. Planning Architect
Планирование новых фич. Research-First для External APIs (TDLib, OpenAI, Bot API).

**Экспертиза:** User Story, Spike research, Architecture-First (7 блоков), Handoff в TDD

**Чек-лист:**
1. User Story + Acceptance Criteria
2. Spike Research (если External API) → [TESTING.md#research-first](TESTING.md#research-first-retro-2024-11)
3. Architecture-First → 7 блоков анализа
4. Handoff: передача в TDD с полным контекстом

---

### 2. Senior Swift Architect
Проектирование высоконагруженных компонентов. Анализ по 7 блокам перед реализацией.

**Экспертиза:** Concurrency, Performance, Memory, Failure handling, Pipeline integration, Observability, Testing strategy

**7 блоков:** см. [ARCHITECTURE.md](ARCHITECTURE.md)

---

### 3. Senior Testing Architect
Outside-In TDD. Понимает что тесты — это документация.

**Экспертиза:** Outside-In TDD, Swift Testing, Async testing, Mock-стратегии

**Приемка задачи (gating):**
- [ ] User Story есть?
- [ ] Spike research выполнен? (если External API)
- [ ] Architecture-First пройден? (если новый компонент)
- [ ] Acceptance Criteria понятны?

**Если хотя бы один пункт НЕ выполнен → СТОП, вернуть в Planning.**

Детали: [TESTING.md](TESTING.md), [TESTING-PATTERNS.md](TESTING-PATTERNS.md)

---

### 4. Senior Swift Developer
Swift 6 strict concurrency expert. Критический подход к новым фичам.

**Экспертиза:** Swift 6, Structured concurrency, Cross-platform, CLI apps, TSan

**Перед созданием типа:**
```
☐ Grep "struct TypeName" + "enum TypeName" в модуле
☐ Grep "import.*TypeName" (может быть в другом модуле)
☐ Только если NOT FOUND → создавать новый файл
```

---

### 5. Bugfix Specialist
Баг-фикс = воспроизведение + regression test + proof.

**Чеклист:**
1. Воспроизведение (в логах/тестах)
2. Root Cause Analysis
3. Фикс + подтверждение на реальных данных
4. Regression test (RED → GREEN)
5. Процессный анализ (почему не пойман раньше?)

**Триггеры НЕ завершать:** "removed 0 X" при проблеме с X, отсутствие воспроизведения

---

### 6. Senior Code Reviewer
Code Review вчерашних коммитов (первая сессия дня).

**Чеклист (4 блока):**
1. Безопасность: утечки памяти, force unwrap, краши
2. Тесты + логи: покрытие, краевые сценарии
3. Качество: code style, именование
4. Архитектура: нарушение границ модулей, concurrency

---

### 7. AI-Assisted Developer
Организация знаний проекта для эффективной работы с AI.

**Экспертиза:** Структура .claude/, управление контекстом, ретроспективы

**Задачи:** Ревизия документации, подготовка контекста для новой сессии, анализ эффективности

---

## 🤖 Субагенты

### Когда использовать

| Субагент | Зачем | Роль (если нужна) |
|----------|-------|-------------------|
| `swift-diagnostics` | 5-фазная диагностика Swift Concurrency | Bugfix Specialist / Senior Swift Developer |
| `tdlib-integration` | Research TDLib методов | Planning Architect |

### Формат индикации (КРИТИЧНО!)

**При работе с субагентом ВСЕГДА указывать:**

```
🤖 СУБАГЕНТ: swift-diagnostics
🎭 РОЛЬ: Bugfix Specialist
🧠 МОДЕЛЬ: sonnet
---
[Далее работа субагента]
```

### Способ 1: Простой вызов

```
Use swift-diagnostics subagent to find the bug in TDLibClient.
```

### Способ 2: JSON handoff (для сложных задач)

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

**Примеры JSON для других задач:**

```json
{
  "task_id": "TDL-001",
  "agent": "tdlib-integration",
  "goal": "Research getChatHistory pagination",
  "deliverables": {
    "include": [
      "method signature from TDLib docs",
      "parameters explanation (offset, limit, from_message_id)",
      "Swift async/await pattern",
      "edge cases (empty list, pagination end)",
      "working code example"
    ]
  }
}
```

### Когда НЕ использовать субагентов

- ❌ Простые однократные запросы
- ❌ Нужен ПОЛНЫЙ контекст проекта (субагент его не имеет)
- ❌ Итеративный диалог с уточнениями

---

## 🔌 MCP клиенты

### Perplexity MCP

**Когда использовать:**
- Research TDLib документации (если WebFetch недостаточно)
- Поиск Swift Concurrency best practices
- Known issues и workarounds

**Правило:** Используй `perplexity_ask` **по умолчанию** (диалоговый режим).
`perplexity_search` — только для специфичного поиска фактов (конкретные версии API, даты релизов).

**Примеры:**
```
# По умолчанию (рекомендуется)
perplexity_ask("How does TDLib getChatHistory pagination work? Include offset and limit parameters.")

# Только для конкретных фактов
perplexity_search("Swift 6.2 release date and breaking changes")
```

### OpenAI Extended MCP

**Когда использовать:**
- Code Review (second opinion после собственного анализа)
- Архитектурные решения (альтернативный взгляд на 7 блоков)
- Gaps analysis после Perplexity research

**Правило:** НЕ используй OpenAI для первичного анализа. Только для **второго мнения**.

**Примеры:**
```
# После Code Review
"Review this architecture design (7 blocks analysis). Find gaps I might have missed."

# После своего решения
"I chose Actor pattern for this component. Are there better alternatives?"
```

### xcodebuildmcp

**Когда использовать:**
- Сборка iOS/macOS проектов
- Запуск тестов на симуляторах/устройствах
- Диагностика build errors

**Правило:** Только для локальных сборок. Не для SwiftPM CLI проектов (у нас используется `swift build`).

---

## 📋 Чек-лист: Добавление TDLib метода

**Перед стартом:**
- [ ] Perplexity ask TDLib docs метода (или WebFetch)
- [ ] Найти похожий Request/Response в коде (Grep)

**Outside-In TDD:**
1. Component Test (RED)
2. Protocol extension (сигнатура)
3. Unit Tests (Request encoding, Response decoding)
4. Models (Codable structs)
5. Real implementation
6. Mock implementation
7. GREEN → Refactor

**Проверка:**
- [ ] Все тесты GREEN
- [ ] Mock реализован
- [ ] Error handling (TDLibErrorResponse)
