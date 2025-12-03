# Задачи проекта

> **Последнее обновление:** 2025-12-03
> **Текущая версия:** v0.2.0 (MVP завершён, готовимся к v0.3.0)

---

## 📋 Следующие задачи (до v0.3.0)

### 1. v0.3.0: SummaryGenerator (AI-саммари непрочитанных)

**User Story:**
Как пользователь CLI-приложения
Я хочу получать AI-саммари непрочитанных сообщений из каналов
Чтобы быстро понять суть контента без чтения всех сообщений

**Acceptance Criteria:**
- ✅ Протокол `SummaryGeneratorProtocol` с `generate(messages:) async throws -> String`
- ✅ Реализация `OpenAISummaryGenerator` (HTTP вызовы, без SDK)
- ✅ Формат: Telegram Markdown (резюме + группировка по каналам + ссылки)
- ✅ Обработка лимита 4096 символов (Telegram API)
- ✅ Unit-тесты (форматирование)
- ✅ Component-тест (real OpenAI API)
- ✅ E2E тест (ChannelMessageSource → SummaryGenerator)
- ✅ Structured logging (request/response/errors)

**Task Breakdown (Outside-In TDD):**

#### 1.1. Spike: Research OpenAI API ⚠️ Research-First
- [ ] WebFetch документации `platform.openai.com/docs/api-reference/chat`
- [ ] Quick prototype: `curl` или Swift playground
- [ ] Зафиксировать: формат запроса, лимиты токенов, retry стратегию

#### 1.2. DocC документация User Story
- [ ] Создать `SummaryGenerator.md` в Sources/DigestCore/Generators/
- [ ] Описать User Story (что и зачем)
- [ ] Документировать публичный контракт `SummaryGeneratorProtocol`
- [ ] Примеры использования (code snippets)
- [ ] Формат вывода (структура markdown)

#### 1.3. E2E тест (RED) — real dependencies
- [ ] `Tests/TgClientE2ETests/SummaryGenerationE2ETests.swift`
- [ ] Сценарий: ChannelMessageSource → SummaryGenerator → markdown
- [ ] ⚠️ Real OpenAI API через `OPENAI_API_KEY` env

#### 1.4. Протокол SummaryGeneratorProtocol
- [ ] `Sources/TGClientInterfaces/SummaryGeneratorProtocol.swift`
- [ ] Метод: `generate(messages: [SourceMessage]) async throws -> String`

#### 1.5. Component тест (RED) — real HTTP
- [ ] `Tests/DigestCoreTests/OpenAISummaryGeneratorTests.swift`
- [ ] Тест с реальным OpenAI API (URLSession)
- [ ] Assert: проверка структуры markdown (резюме, каналы, ссылки)

**Декомпозиция при разрастании (>150 строк):**
- `OpenAISummaryGenerator_HappyPathTests.swift`
- `OpenAISummaryGenerator_ErrorHandlingTests.swift`
- `OpenAISummaryGenerator_FormattingTests.swift`

#### 1.6. Implementation → GREEN
- [ ] `Sources/DigestCore/Generators/OpenAISummaryGenerator.swift`
- [ ] HTTP клиент: URLSession
- [ ] Prompt engineering: system + user messages
- [ ] Parsing: `choices[0].message.content`
- [ ] Довести component тест до зелёного

#### 1.7. Unit тесты (детали реализации)
- [ ] Форматирование markdown: группировка по каналам
- [ ] Обрезка по 4096 символов
- [ ] Escaping для Telegram Markdown

#### 1.8. Refactoring
- [ ] Выделить HTTP retry logic (экспоненциальная задержка, 3 попытки)
- [ ] Оптимизировать prompt
- [ ] Structured logging: request/response/errors

#### 1.9. Mock (только в конце!)
- [ ] `MockSummaryGenerator` для использования в других модулях

#### 1.10. Документация (архитектура)
- [ ] Обновить `ARCHITECTURE.md`: добавить SummaryGenerator в диаграмму
- [ ] Обновить `MVP.md`: отметить SummaryGenerator как готовый

---

### 2. Thread Sanitizer анализ [техдолг, низкий приоритет]

**Статус:**
- ✅ `swift build -c debug --sanitize=thread` работает на Linux
- ❌ `swift test --sanitize=thread` зависает (SwiftPM 6.2 bug)
- 📌 **Отложено до переезда на macOS** для отладки

**На macOS:**
```bash
swift test -c debug --sanitize=thread --filter TgClientUnitTests
```

---

## 🔄 Проверка гипотез ретро

_Раз в 1-3 дня. Результат записать в [RETRO-RESULT.md](archived/RETRO-RESULT.md)_

```
Дата: ____

## Метрики:
1. Race conditions (TSan): ___
2. Spike ДО реализации: ___ из ___ external APIs
3. Новые Mock >100 строк: ___
4. Закомментированные тесты: ___

## Инциденты:
- [ ] Все с regression тестом?

## Нарушения правил:
- Какие? Почему?

## Выводы:
- Работает:
- Не работает:
```

---

**Ссылки:**
- [MVP.md](MVP.md) — scope и статус MVP
- [BACKLOG.md](BACKLOG.md) — бэклог будущих фич
- [CHANGELOG.md](CHANGELOG.md) — история изменений
