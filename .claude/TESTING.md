# Стратегия тестирования

> **Обновлено:** 2025-12-01

---

## ⚠️ Критичные правила

1. **Swift Testing** — только Swift Testing, НЕ XCTest
2. **TDD обязателен** — тесты ДО реализации ([workflow](#tdd-workflow-outside-in))
3. **swift test без pipe** — `swift test | head/tail/grep` вызывает SIGPIPE зависание
4. **Async без sleep** — используй async паттерны ([см. ниже](#async-тестирование))
5. **Не raw JSON** — используй модели + encode

```bash
# Запуск тестов
✅ swift test 2>&1
✅ swift test --filter MyTest 2>&1
```

---

## Уровни тестирования

| Уровень | Что тестирует | Mock |
|---------|---------------|------|
| **E2E** | User story целиком | Реальный TDLib |
| **Component** | Один компонент | MockTDLibClient |
| **Unit** | Функция/модель | Нет зависимостей |

```
Новая user story?           → E2E + Component тесты
Часть существующей story?   → Component тест
Модель/encoder/decoder?     → Unit тест
```

### Документация в тестах

**Принцип:** тесты = источник знаний о внешних API, внутренних решениях и моделях.

| Уровень | Что документировать | Пример |
|---------|---------------------|--------|
| **Unit** (внешний API) | Ссылки на API docs, примеры реальных JSON | [ChatTests.swift](../Tests/TgClientUnitTests/TDLibAdapter/TDLibCodableModels/Responses/ChatTests.swift) |
| **Unit** (внутренняя модель) | Контракт, edge cases, причины решений | [ResponseWaitersTests.swift](../Tests/TgClientUnitTests/TDLibAdapter/ResponseWaitersTests.swift) |
| **Component** | Ссылки на unit тесты/модели, незадокументированное поведение | [AuthenticationFlowTests.swift](../Tests/TgClientComponentTests/TDLibAdapter/AuthenticationFlowTests.swift) |
| **E2E** | Пользовательский сценарий, ручная/полуручная проверка | `Tests/TgClientE2ETests/` или `scripts/manual_*.sh` |

---

## Research-First [RETRO-2024-11]

**Когда:** новый API или новый метод существующего API (TDLib, HTTP, библиотека).

| Шаг | Действие | Результат |
|-----|----------|-----------|
| 1. Spike | Документация + **throwaway код** для проверки реального поведения (≤30 мин) | "API работает так" |
| 2. Architecture | Edge cases? Concurrency? Memory? | Проговорить вслух |
| 3. ADR | Если >50 строк — записать в ARCHITECTURE.md | Документ решения |
| 4. TDD | Только после шагов 1-3 | RED → GREEN → REFACTOR |

**⚠️ Spike = код!** Реальное поведение API может расходиться с документацией.

**Причина правила:** Пропуск spike → 9 дней cascade changes (Race Condition инцидент).

---

## TDD Workflow: Outside-In

```
RED → GREEN → REFACTOR
```

### Быстрый чек-лист

```
☐ E2E сценарий (DoCC)
☐ Component Test (RED)
☐ Models + Unit Tests → GREEN
☐ Implementation → Component Test GREEN
☐ REFACTOR
☐ E2E validation (manual)
```

**Подробный алгоритм:** [TESTING-PATTERNS.md#декомпозиция-тестов](TESTING-PATTERNS.md#декомпозиция-тестов)

### Декомпозиция тестов

Если Component Test > 30-40 строк → разбей на части:

```
Test 1: первый шаг (happy)
Test 2: первый шаг (error)
...
Integration Test: вся цепочка
```

### Для каждого шага

```
1. Happy path → RED → GREEN → REFACTOR
2. Edge cases (только критичные и вероятные)
3. Следующий шаг
```

**Матрица edge cases:** [TESTING-PATTERNS.md#edge-cases](TESTING-PATTERNS.md#edge-cases-прагматичный-подход)

---

## Async тестирование

| Паттерн | Когда | Подробнее |
|---------|-------|-----------|
| `confirmation()` | AsyncStream, подсчёт событий | [TESTING-PATTERNS.md](TESTING-PATTERNS.md#паттерн-1-confirmation) |
| `withMainSerialExecutor` | Детерминированный порядок | [TESTING-PATTERNS.md](TESTING-PATTERNS.md#паттерн-2-withmainserialexecutor) |

---

## Структура тестов

```
Tests/
├── TestHelpers/              # Общие хелперы (DocC в коде)
├── TgClientUnitTests/        # Unit тесты
├── TgClientComponentTests/   # Component тесты
└── TgClientE2ETests/         # E2E тесты
```

---

## Ссылки

| Тема | Файл |
|------|------|
| Декомпозиция, edge cases, REFACTOR, async | [TESTING-PATTERNS.md](TESTING-PATTERNS.md) |
| Проблемы сборки/тестов | [TROUBLESHOOTING.md#тесты](TROUBLESHOOTING.md#проблемы-с-тестами) |
