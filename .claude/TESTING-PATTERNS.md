# Паттерны тестирования (справочник)

> **Назначение:** Детальные алгоритмы и примеры для сложных случаев.
> **Когда читать:** По ссылке из TESTING.md когда нужен конкретный паттерн.
> **Обновлено:** 2026-10-16 (async: что реально доступно в проекте)

---

## Навигация

| Паттерн | Секция |
|---------|--------|
| Декомпозиция тестов | [#декомпозиция-тестов](#декомпозиция-тестов) |
| Edge cases | [#edge-cases](#edge-cases-прагматичный-подход) |
| REFACTOR чек-лист | [#refactor](#refactor-чек-лист) |
| Async: confirmation | [#async-confirmation](#паттерн-1-confirmation) |
| Async: serial executor | [#async-serial](#паттерн-2-withmainserialexecutor) |
| Async: actor isolation | [#async-actor](#паттерн-3-actor-isolation) |

---

## Декомпозиция тестов

**Что это:** Разбиение большого Component теста на маленькие части.

**Что это НЕ:** Создание новых классов/actors (это архитектура → ADR).

### Когда применять

```
Component Test > 30-40 строк? → Декомпозиция
```

### Процесс

```
E2E сценарий: "Получить непрочитанные сообщения"
    │
    ▼
Component Test — разбиваем на шаги:
    │
    ├─> Test: loadChats (happy)
    ├─> Test: loadChats (error) — если mock простой
    │
    ├─> Test: filterChannels (happy)
    ├─> Test: filterChannels (edge: empty)
    │
    ├─> Test: fetchMessages (happy)
    │
    └─> Integration Test: вся цепочка
```

### Порядок для каждого шага

```
1. Happy path → RED → GREEN → REFACTOR
2. Быстрая проверка edge cases (см. матрицу ниже)
3. Следующий шаг
```

### Пример структуры тестов

```swift
@Suite("ChannelMessageSource")
struct ChannelMessageSourceTests {

    // === Шаг 1: loadChats ===
    @Test func loadChats_returnsChats() { }
    @Test func loadChats_throwsOnError() { }

    // === Шаг 2: filterChannels ===
    @Test func filterChannels_returnsOnlyChannels() { }
    @Test func filterChannels_emptyWhenNoChannels() { }

    // === Шаг 3: fetchMessages ===
    @Test func fetchMessages_returnsMessages() { }

    // === Integration ===
    @Test func fetchUnreadMessages_fullFlow() { }
}
```

---

## Edge cases: прагматичный подход

### Матрица "Критичность × Вероятность"

```
                    │ Высокая вероятность │ Низкая вероятность
────────────────────┼─────────────────────┼────────────────────
Критично для        │ ✅ Тест СЕЙЧАС      │ 📝 TODO в коде
пользователя        │                     │
────────────────────┼─────────────────────┼────────────────────
Не критично         │ ⚡ Быстрый тест     │ ❌ Игнорируем
                    │    если просто      │
```

### Примеры для TDLib проекта

| Ситуация | Вероятность | Критичность | Решение |
|----------|-------------|-------------|---------|
| TDLib вернул error | Высокая | Критично | ✅ Тест |
| Пустой список | Высокая | Не критично | ⚡ Быстрый тест |
| Сеть упала | Средняя | Критично | ✅ Тест |
| Канал удалён | Низкая | Не критично | 📝 TODO |
| Rate limit | Низкая | Средняя | 📝 TODO |

### Упрощённый чек-лист (3 вопроса)

```
После happy path:

□ API вернул ошибку? → Тест если mock уже есть
□ Пустой результат? → Обычно 2-3 строки
□ Что-то ещё критичное? → TODO
```

### Формат TODO для отложенных cases

```swift
// TODO: [EDGE] Rate limit handling
// Вероятность: низкая | Критичность: средняя
```

### Главное правило

> Если для edge case нужен новый mock — это TODO, не тест. MVP важнее покрытия.

---

## REFACTOR чек-лист

### Что такое REFACTOR

```
RED    → тест не проходит
GREEN  → минимальный код чтобы прошёл
REFACTOR → улучшаем код, тесты всё ещё GREEN
```

### Чек-лист: нужен ли?

```
□ Есть дублирование? → вынести в метод
□ Названия понятны? → переименовать
□ Функция > 20-25 строк? → разбить
□ Вложенность > 2 уровней? → упростить

Всё ✓ → не нужен, следующий тест
```

### Что НЕ входит в REFACTOR

```
❌ Edge cases — это НОВЫЕ тесты
❌ Новые фичи — это НОВЫЕ тесты
❌ Архитектурные изменения — ADR
```

### Документирование проблем

| Ситуация | Куда |
|----------|------|
| Проблема в коде | `// TODO: описание` |
| Идея на будущее | BACKLOG.md |
| Архитектурный долг | ADR |

---

## Async тестирование

### Паттерн 1: confirmation()

**Когда:** AsyncSequence/AsyncStream, подсчёт событий.

```swift
@Test func receivesUpdates() async throws {
    await confirmation(expectedCount: 3) { confirm in
        await handler.start { update in
            confirm()
        }
    }
}
```

https://developer.apple.com/documentation/testing/confirmation

### Паттерн 2: withMainSerialExecutor

> Гипотеза H-PF — в проекте пока нет.

**Когда:** Проверка порядка, детерминированные тесты. Требует `swift-concurrency-extras` — подключение решается в
И4 ([testing-v1-plan.md](testing-v1-plan.md)); спайк 2026-10-16: на Linux работает. Swift 6 не даёт мутировать
захваченный `var` из `Task` — состояние через `LockIsolated`.

```swift
import ConcurrencyExtras

@Test func processesSequentially() async throws {
    await withMainSerialExecutor {
        let order = LockIsolated<[Int]>([])
        await handler.start { id in order.withValue { $0.append(id) } }
        #expect(order.value == [1, 2, 3])
    }
}
```

Сейчас для порядка — «затвор» на continuation (`CommandProcessorConcurrencyTests`).

https://www.pointfree.co/blog/posts/110-reliably-testing-async-code-in-swift

### Паттерн 3: Actor isolation

**Когда:** Thread-safety, concurrent вызовы.

```swift
@Test func threadSafe() async throws {
    await withTaskGroup(of: Void.self) { group in
        for _ in 1...10 {
            group.addTask { await handler.process() }
        }
    }
}
```

---

## Ресурсы

- [Swift Testing](https://developer.apple.com/documentation/testing)
- [swift-concurrency-extras](https://github.com/pointfreeco/swift-concurrency-extras)
