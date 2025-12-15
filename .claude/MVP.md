# MVP: Telegram Digest Bot

> **Статус:** In Progress
> **Текущая версия:** 0.3.0
> **Последнее обновление:** 2025-12-06

**Готово (v0.2.0):**
- ✅ TDLibAdapter с Race Condition fix (sendAndWait)
- ✅ ChannelMessageSource (сбор непрочитанных из каналов)
- ✅ 128 Unit/Component тестов, E2E тест
- ✅ Работает на macOS + Linux

**Детали:** См. [CHANGELOG.md](CHANGELOG.md)

---

## 🎯 Продуктовое видение

### Проблема
Информационная перегрузка в Telegram каналах: десятки непрочитанных сообщений, которые невозможно быстро просмотреть.

### Решение
Автоматический дайджест непрочитанных сообщений из каналов с AI-саммари, доставляемый через Telegram бота 2 раза в день + по требованию.

### Целевая аудитория (MVP)
- Автор проекта
- Тестовый пользователь (1-2 человека)

---

## ✅ Функционал MVP (Must Have)

### 1. Сбор сообщений из каналов
- **Scope:** Только Telegram каналы (не группы, не личные чаты)
- **Фильтр:** Каналы НЕ находящиеся в архиве
- **Типы сообщений:** Только текст
- **Лимиты:** Без ограничений по количеству (в рамках лимита TG API)

### 2. AI Саммаризация (OpenAI)
- **Провайдер:** OpenAI API (GPT-4 или GPT-3.5-turbo)
- **Архитектура:** Абстракция `SummaryGeneratorProtocol` для смены провайдера
- **Формат вывода:**
  - Краткое саммари в начале (2-3 предложения)
  - Группировка по каналам
  - Ссылки на оригинальные сообщения
- **Ограничения:**
  - Максимум 4096 символов (лимит Telegram API)
  - Если больше → разбиение на несколько сообщений
- **Формат:** Telegram Markdown

### 3. Доставка через Telegram Bot
- **Куда:** Личный чат с ботом (пользователь → бот)
- **Формат:** Telegram MarkdownV2
- **Режимы запуска:**
  - **Scheduled:** 2 раза в день (cron)
  - **On-demand:** Команда `/digest` в боте

### 4. Отметка прочитанным
- **Когда:** ТОЛЬКО после успешной отправки всех саммари
- **Как:** TDLib API `viewMessages` для всех обработанных каналов
- **Rollback:** Если отправка фейлится → НЕ помечать прочитанным

### 5. Хранение состояния
- **Минимальное:** Timestamp последней успешной обработки
- **Формат:** JSON файл `~/.tdlib/digest_state.json`

### 6. Мониторинг и алерты
- Structured logging (JSON), уровни: DEBUG, INFO, WARN, ERROR
- Алерты через TG бот: ошибки авторизации, AI API, отправки
- Healthcheck: heartbeat файл + cron

### 7. Deployment
- **Платформа:** Linux VPS (Ubuntu/Debian)
- **Режим:** systemd service + cron
- **Конфигурация:** Переменные окружения

---

## 📋 Технические требования MVP

### Архитектура (бизнес-логика)

```
┌─────────────────────────────────────────────────────────┐
│                    DigestOrchestrator                   │
│              (main entry point, координатор)            │
└─────────────────────────────────────────────────────────┘
                           │
        ┌──────────────────┼──────────────────┐
        ▼                  ▼                  ▼
┌───────────────┐  ┌──────────────┐  ┌──────────────┐
│ MessageSource │  │SummaryGenerator│  │ BotNotifier  │
│ (Channels MVP)│  │   (OpenAI)    │  │  (TG Bot API)│
└───────────────┘  └──────────────┘  └──────────────┘
                           │
                           ▼
                  ┌─────────────────┐
                  │  StateManager   │
                  │ (timestamp JSON)│
                  └─────────────────┘
```

> **Примечание:** MonitoringService — cross-cutting concern, вызывается из всех компонентов для логирования и алертов.

### Ключевые компоненты

#### 1. MessageSource (Channel Implementation)
- Протокол: `MessageSourceProtocol`
- Реализация: `ChannelMessageSource` (MVP - только каналы)
- Методы:
  - `fetchUnreadMessages(since: Date?) async throws -> [SourceMessage]`
  - `markAsRead(messages: [SourceMessage]) async throws`

##### TDLib API: Работа с непрочитанными сообщениями

> **Документация TDLib:** https://core.telegram.org/tdlib/docs/

TDLib отслеживает состояние прочитанности на стороне сервера Telegram:
- `unreadCount: Int` — количество непрочитанных
- `lastReadInboxMessageId: Int64` — ID последнего прочитанного

**Методы TDLib API:**

1. **`getChatHistory`** — получение сообщений ([docs](https://core.telegram.org/tdlib/docs/classtd_1_1td__api_1_1get_chat_history.html))
2. **`viewMessages`** — отметка прочитанными ([docs](https://core.telegram.org/tdlib/docs/classtd_1_1td__api_1_1view_messages.html))

**Оптимизация: получение только непрочитанных**

```swift
// 1. Получить каналы с непрочитанными
let chats = try await tdlib.send(GetChatsRequest(chatList: .main, limit: 100))
let unreadChannels = chats.filter { $0.type == .channel && $0.unreadCount > 0 }

// 2. Для каждого канала
for channel in unreadChannels {
    let history = try await tdlib.send(
        GetChatHistoryRequest(chatId: channel.id, fromMessageId: 0, limit: channel.unreadCount)
    )
    let unreadMessages = history.messages.filter { $0.id > channel.lastReadInboxMessageId }
}

// 3. После успешной отправки дайджеста
try await tdlib.send(ViewMessagesRequest(chatId: channel.id, messageIds: messageIds, forceRead: true))
```

⚠️ **Race condition:** между запросами кто-то может прочитать → фильтровать по `lastReadInboxMessageId`

#### 2. SummaryGenerator (🚧 v0.3.0 в разработке)
- **Протокол:** `SummaryGeneratorProtocol`
- **Реализация:** `OpenAISummaryGenerator` (MVP)
- **Метод:** `generate(messages: [SourceMessage]) async throws -> String`
- **Тесты:** Component тесты используют OpenAISummaryGenerator + MockHTTPClient (mock только network boundary)

**Технические решения (spike 2025-12-03):**
- Модель: `gpt-3.5-turbo` (~$0.006/дайджест для 100 сообщений)
- HTTP: URLSession, retry 3x с exponential backoff (1s, 2s, 4s)
- Промпт: на русском, system message + user message
- Лимит ответа: 3800 символов (резерв для Telegram 4096)
- Errors: 401→fatal, 429/5xx→retry

**Spike материалы (архив):**
- Документация: `.claude/archived/spike-openai-api-2025-12-03.md`
- Тестовый скрипт (базовый): `.claude/archived/openai-spike-test.sh`
- Тестовый скрипт (русский промпт): `.claude/archived/openai-russian-prompt-test.sh`
- Research библиотек (HTTP client, errors, streaming): `.claude/archived/openai-libraries-research-2025-12-04.md`

**Task Breakdown (Outside-In TDD):**

1. **Spike** ✅ - Research OpenAI API
2. **DocC документация** - User Story + примеры
3. **E2E тест (RED)** - ChannelMessageSource → SummaryGenerator
4. **Протокол** - SummaryGeneratorProtocol
5. **Component тест (RED)** - реальный HTTP к OpenAI
6. **Unit тесты** - форматирование промпта (группировка каналов)
7. **Implementation → GREEN** - OpenAISummaryGenerator + URLSession
8. **Unit тесты** - обработка ответа (4096 chars limit, разбивка)
9. **Refactoring** - retry logic, logging
10. **Документация** - обновить ARCHITECTURE.md

Детали: см. `.claude/TASKS.md` (текущая задача)

#### 3. BotNotifier
- Протокол: `BotNotifierProtocol`
- Реализация: `TelegramBotNotifier`

#### 4. StateManager
- Протокол: `StateManagerProtocol`
- Реализация: `FileBasedStateManager`

### Environment Variables

```bash
# Telegram Client (TDLib)
TELEGRAM_API_ID / TELEGRAM_API_HASH / TELEGRAM_PHONE

# Telegram Bot
TELEGRAM_BOT_TOKEN / TELEGRAM_BOT_CHAT_ID

# OpenAI
OPENAI_API_KEY / OPENAI_MODEL=gpt-4-turbo

# State
DIGEST_STATE_DIR=~/.tdlib
```

---

## 🎬 User Flow (MVP)

### Scheduled Run (Cron)
```
1. Cron запускает `tg-digest scheduled` (09:00, 18:00)
2. DigestOrchestrator:
   a. MessageSource получает непрочитанные из каналов
   b. SummaryGenerator создает AI-саммари
   c. BotNotifier отправляет в TG бота
   d. Если успешно → MessageSource.markAsRead
   e. Обновляет timestamp в StateManager
3. При ошибке → алерт через BotNotifier
```

### On-Demand Run
```
1. Пользователь отправляет `/digest` в бота
2. Тот же flow, но игнорирует timestamp
```

---

## ✅ Критерии готовности MVP

### Функциональные
- [ ] Авторизация TDLib клиента
- [ ] Получение непрочитанных каналов (не в архиве)
- [ ] Извлечение текстовых сообщений с ссылками
- [ ] Генерация AI-саммари через OpenAI
- [ ] Отправка через Telegram бота
- [ ] Отметка прочитанными
- [ ] Scheduled + On-demand запуск
- [ ] Алерты при ошибках

### Технические
- [ ] TDD: 80% coverage для core логики
- [ ] Structured logging (JSON)
- [ ] systemd service + healthcheck
- [ ] Документация деплоя

### Тестирование
- [ ] Unit-тесты: SummaryGenerator, ChannelFetcher, StateManager
- [ ] Component-тесты: DigestOrchestrator
- [ ] Manual E2E на VPS

---

## 🔧 Принятые решения

| Вопрос | Решение | Причина |
|--------|---------|---------|
| OpenAI SDK | Прямые HTTP calls | Меньше зависимостей |
| Telegram Bot | Long Polling | Проще для MVP |
| Формат логов | JSON строки | Для будущего Prometheus/Loki |
| Deployment | systemd | Меньше overhead для single user |

---

## 🚀 Version Roadmap

### v0.4.0: Mark as Read + Retry Strategy

**Статус:** 🚧 В разработке (2025-12-12)

**Цель:** Отметка сообщений как прочитанных + retry strategy для временных ошибок OpenAI.

#### Scope

**Обязательные фичи:**
- [x] TDLib `viewMessages` API интеграция ✅
- [x] Parallel mark-as-read для N чатов (TaskGroup) ✅
- [x] Concurrency limit (maxParallelMarkAsReadRequests = 20) ✅
- [x] Structured logging (начало, прогресс, итог, ошибки) ✅
- [x] Partial failure handling (1 чат failed → остальные помечаем) ✅
- [x] **Retry strategy для DigestOrchestrator** ✅ (добавлено в v0.4.0)
  - Exponential backoff: 1s → 2s → 4s
  - Retry для: TimeoutError, 429 rate limit, 5xx server errors
  - Fail-fast для: 401, 400, emptyResponse

**НЕ входит в scope v0.4.0:**
- ❌ CLI флаг `--mark-as-read` / `--no-mark-as-read` (отложено в v0.6.0)
- ❌ BotNotifier implementation (отложено в v0.5.0)
- ❌ Unsupported content tracking ("⚠️ Пропущено 3 фото" → v0.6.0)

#### Архитектура

**Целевой pipeline (v0.5.0):**

```
fetch → digest (retry 3x) → **BotNotifier** → markAsRead
  (1)        (2)                 (3)              (4)
```

**Текущий pipeline (v0.4.0 временное решение):**

```
fetch → digest (retry 3x) → markAsRead
  (1)        (2)              (3)
```

**⚠️ Временное решение v0.4.0:**
- markAsRead идёт ПОСЛЕ digest (БЕЗ BotNotifier)
- **Риск:** Если приложение крашнется после digest, пользователь НЕ получит дайджест
- **Mitigation:** Пользователь запустит снова → получит дайджест (сообщения остались unread)
- **Решение v0.5.0:** BotNotifier → markAsRead ПОСЛЕ успешной отправки

**Обоснование последовательности (целевой v0.5.0):**
- Помечаем прочитанным ТОЛЬКО после успешной отправки дайджеста пользователю
- Если BotNotifier.send() упадёт → сообщения останутся непрочитанными → пользователь получит дайджест в следующий раз
- Защита от потери информации при сбоях отправки

**MarkAsReadService API:**

```swift
actor MarkAsReadService {
    init(
        tdlib: TDLibClient,
        maxParallelRequests: Int = 20,
        timeout: Duration = .seconds(2)
    )

    /// Отметить сообщения как прочитанные для указанных чатов
    /// - Returns: Map [chatId: Result] (успех/ошибка для каждого чата)
    func markAsRead(_ messages: [ChatId: [MessageId]]) async -> [ChatId: Result<Void, Error>]
}
```

**Параллелизм (переиспользование паттерна из ChannelMessageSource):**

```swift
withThrowingTaskGroup(of: (ChatId, Result<Void, Error>).self) { group in
    var activeTasksCount = 0

    for (chatId, messageIds) in messages {
        // Ограничиваем параллелизм
        while activeTasksCount >= maxParallelRequests {
            _ = try await group.next()
            activeTasksCount -= 1
        }

        group.addTask {
            do {
                try await tdlib.sendAndWait(
                    ViewMessagesRequest(
                        chatId: chatId,
                        messageIds: messageIds,
                        forceRead: true
                    )
                )
                return (chatId, .success(()))
            } catch {
                logger.error("Failed to mark chat \(chatId) as read", error: error)
                return (chatId, .failure(error))
            }
        }
        activeTasksCount += 1
    }

    // Собираем результаты
    var results: [ChatId: Result<Void, Error>] = [:]
    while let (chatId, result) = try await group.next() {
        results[chatId] = result
    }
    return results
}
```

#### TDLib API: viewMessages

**Документация:** https://core.telegram.org/tdlib/docs/classtd_1_1td__api_1_1view_messages.html

**Параметры:**
- `chat_id` (Int53): ID чата
- `message_ids` ([Int53]): массив ID сообщений
- `source` (MessageSource?): null → auto-detect
- `force_read` (Bool): `true` → отметить даже если чат закрыт

**Поведение:**
- Идемпотентен (повторный вызов безопасен)
- Локальный API (не network request, БЕЗ timeout/retry)

**Response:** `Ok` (пустой success marker)

**Errors:** Стандартные TDLib ошибки через `TDLibErrorResponse`

#### Новые модели (TDD: Outside-In)

**1. ViewMessagesRequest: Codable**
```swift
struct ViewMessagesRequest: Codable, Sendable {
    let chatId: Int64
    let messageIds: [Int64]
    let forceRead: Bool

    enum CodingKeys: String, CodingKey {
        case type = "@type"
        case chatId = "chat_id"
        case messageIds = "message_ids"
        case forceRead = "force_read"
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode("viewMessages", forKey: .type)
        try container.encode(chatId, forKey: .chatId)
        try container.encode(messageIds, forKey: .messageIds)
        try container.encode(forceRead, forKey: .forceRead)
    }
}
```

**2. Response:** Переиспользуем существующий `Ok` (уже есть в TDLib моделях)

#### Testing стратегия

**Уровни тестирования:**

| Уровень | Mock Strategy | TSan |
|---------|---------------|------|
| **Unit** | ViewMessagesRequest encoding | ❌ |
| **Component** | MockTDLibFFI (boundary) | ✅ ОБЯЗАТЕЛЬНО |
| **E2E** | Real TDLib (manual) | ✅ |

**Edge cases (КРИТИЧНЫЕ для Component тестов):**
- ✅ Empty input (0 чатов)
- ✅ Single chat success
- ✅ Partial failure (3/5 чатов success)
- ✅ All chats failed
- ✅ Timeout (viewMessages зависает)
- ✅ Task cancellation (Task.cancel в середине)
- ✅ Large batch (100 чатов → проверка concurrency limit)

**TSan проверка:**
```bash
swift test --sanitize=thread --filter MarkAsReadServiceTests
```

#### Стратегия отметки прочитанным (v0.4.0 MVP)

**Правило:** Помечаем ВСЕ чаты, по которым получили summary от AI.

**Логика:**
1. `MessageSource.fetchUnreadMessages()` → получили сообщения из N чатов
2. `SummaryGenerator.generate()` → получили summary (успех)
3. `BotNotifier.send()` → отправили хотя бы 1 часть (успех)
4. **→ Помечаем ВСЕ N чатов как прочитанные**

**Почему не учитываем unsupported content (фото/видео) в v0.4.0:**
- Усложняет: требует metadata tracking
- Сложнее тестировать
- Отложено в v0.6.0 (добавим "⚠️ Пропущено 3 фото")

#### CLI интеграция

**ArgumentParser:**
```swift
@main
struct TgClientCommand: AsyncParsableCommand {
    @Flag(name: .long, help: "Mark messages as read after successful digest")
    var markAsRead: Bool = true // default ON

    func run() async throws {
        let orchestrator = DigestOrchestrator(
            markAsRead: markAsRead, // передаём через init
            maxParallelMarkAsRead: 20
        )
        try await orchestrator.run()
    }
}
```

**Использование:**
```bash
swift run tg-client                    # markAsRead = true (default)
swift run tg-client --mark-as-read     # markAsRead = true (явно)
swift run tg-client --no-mark-as-read  # markAsRead = false (dry-run)
```

**Документация для пользователя:**
- README.md: секция "CLI Options"
- `--help` output (автоматически через ArgumentParser)

#### Logging

**Структура логов:**

```swift
// Начало
logger.info("Marking \(chatCount) chats as read", metadata: [
    "chat_count": chatCount,
    "max_parallel": maxParallelRequests
])

// Прогресс (per chat)
logger.debug("Marking chat as read", metadata: [
    "chat_id": chatId,
    "message_count": messageIds.count
])

// Итог (summary)
logger.info("Mark-as-read completed", metadata: [
    "success_count": successCount,
    "failed_count": failedCount,
    "duration_ms": durationMs
])

// Ошибки (per chat)
logger.error("Failed to mark chat as read", metadata: [
    "chat_id": chatId,
    "error": error.localizedDescription
])
```

#### Task Breakdown (TDD: Outside-In)

**Prerequisite:**
1. ✅ Research TDLib `viewMessages` docs (WebFetch) — DONE
2. ✅ Architecture-First анализ (7 блоков) — DONE
3. [ ] TSan учения (перед реализацией) — см. BACKLOG

**Implementation (TDD order):**

1. **DocC документация** — User Story
2. **Component Test (RED)** — MarkAsReadService happy path
3. **Models** — ViewMessagesRequest: Codable + Unit Tests
4. **MarkAsReadService implementation** → Component Test GREEN
5. **Component Tests (edge cases)** — empty, partial failure, timeout, cancellation
6. **TSan validation** — `swift test --sanitize=thread`
7. **DigestOrchestrator integration** — параллельное выполнение BotNotifier + MarkAsRead
8. **CLI флаг** — `--mark-as-read` / `--no-mark-as-read`
9. **E2E manual test** — реальный TDLib на dev окружении
10. **Документация** — обновить ARCHITECTURE.md (pipeline diagram)

#### Acceptance Criteria

**Функциональные:**
- [ ] Помечает N чатов как прочитанные параллельно
- [ ] Partial failure: 1 чат failed → остальные успешно
- [ ] CLI флаг `--no-mark-as-read` → пропускает mark-as-read
- [ ] Concurrency limit 20 работает корректно

**Технические:**
- [ ] TSan: 0 data races
- [ ] Component тесты: 7 edge cases покрыты
- [ ] Логирование: начало, прогресс, итог, ошибки
- [ ] ARCHITECTURE.md: диаграмма pipeline обновлена

**Non-functional:**
- [ ] Performance: mark-as-read для 50 чатов < 5 секунд
- [ ] Параллельное выполнение с BotNotifier → ускорение ~2-5 сек

---

### v0.5.0: BotNotifier (Telegram Bot API)

**Статус:** 📝 Planned (scope определён 2025-12-15)

**Scope:** ТОЛЬКО BotNotifier — send-only для MVP

**Цель:** Отправка дайджеста пользователю через Telegram бота.

**Must Have:**
- [ ] BotNotifier service (отправка дайджеста через Telegram Bot API)
- [ ] Spike research: библиотека vs HTTP calls
- [ ] Минимальный scope: send-only (`sendMessage`)
- [ ] **Plain text формат** (БЕЗ `parse_mode`, без MarkdownV2 escape)
- [ ] Retry strategy: переиспользовать `withRetry` + `withTimeout` из FoundationExtensions
- [ ] **Message >4096 chars: fail-fast** (throw error, пользователь сократит AI prompt)
- [ ] Интеграция в DigestOrchestrator pipeline:
  ```
  fetch → digest → BotNotifier → markAsRead
  ```
- [ ] Env vars: `TELEGRAM_BOT_TOKEN`, `TELEGRAM_BOT_CHAT_ID`
- [ ] Документация: README.md (как получить `chat_id`, `/start` в боте)

**Отложено в v0.6.0:**
- ❌ **Message split (>4096 chars)** — transactional (all-or-nothing)
- ❌ CLI флаг `--mark-as-read` / `--no-mark-as-read`
- ❌ Улучшение ссылок на сообщения ("саммари per chat")
- ❌ Команды бота (`/digest`, `/start`)
- ❌ Webhook / Long Polling (interactive bot)

**Обоснование:**
BotNotifier — сложная задача (~5-7 дней), сравнима с TDLibClient. Нужен отдельный клиент для Telegram Bot API. Для MVP достаточно send-only (без команд).

**Spike research:**
✅ DONE — См. `.claude/archived/spike-telegram-bot-api-2025-12-15.md`

**Рекомендация:** HTTP calls (URLSession) без библиотеки — проще для send-only

**Критичные вопросы:**
1. Библиотека ([swift-telegram-sdk](https://github.com/nerzh/swift-telegram-sdk)) vs HTTP calls?
2. Как получить `chat_id`? (пользователь должен начать диалог `/start`)
3. Send-only достаточно для v0.5.0?
4. Webhook setup для новых пользователей?

---

### v0.6.0: Message Split + Unsupported Content Tracking

**Статус:** 📝 Planned

**Scope:**

#### 1. Message Split (>4096 chars) — Transactional

**Цель:** Если дайджест >4096 символов → разбить на части и отправить последовательно.

**Архитектура:**
```swift
func send(parts: [String]) async throws {
    for (index, part) in parts.enumerated() {
        logger.info("Sending part \(index+1)/\(parts.count)")

        do {
            try await sendSingleMessage(part) // retry внутри
        } catch {
            logger.error("Failed to send part \(index+1), stopping")
            throw BotNotifierError.partialFailure(
                sent: index,
                total: parts.count,
                underlyingError: error
            )
        }
    }
}
```

**Правило:** All-or-nothing (если part 2 failed → НЕ отправляем part 3).

**Логика split:**
- Разбить по параграфам (сохранить MarkdownV2 форматирование)
- Numbered parts: "Дайджест (1/3)", "Дайджест (2/3)", "Дайджест (3/3)"
- Лимит: 4096 chars per part

**⚠️ Rate Limits (Bot API):**
- **1 msg/sec для одного чата** → добавить delay 1 sec между частями
- Retry на 429 как fallback (если delay недостаточен)

**Acceptance Criteria:**
- [ ] Если message >4096 → split по параграфам
- [ ] Sequential отправка (part 1 → part 2 → part 3)
- [ ] **Delay 1 sec между частями** (соблюдаем rate limit 1 msg/sec)
- [ ] Fail-fast: если part N failed → throw `partialFailure(sent: N-1, total: M)`
- [ ] Логирование partial failure (сколько частей отправлено)

#### 2. Unsupported Content Tracking

**Scope:**
- "⚠️ Пропущено 3 фото, 1 видео" в summary
- Умная стратегия mark-as-read (не помечать чаты с unsupported content)

#### 3. CLI флаг `--mark-as-read` / `--no-mark-as-read`

**Scope:**
- `--no-mark-as-read` → dry-run (НЕ помечать сообщения прочитанными)

#### 4. MarkdownV2 форматирование (MarkdownV2Formatter)

**Цель:** Красивое форматирование дайджеста в Telegram.

**Scope:**
- Отдельный компонент `MarkdownV2Formatter` (между SummaryGenerator и BotNotifier)
- **Жирный:** название канала (`*Tech News*`)
- **Курсив:** метаданные (`_10:30, 15 дек_`)
- **Ссылки:** на оригинальные сообщения (`[Сообщение #123](https://t.me/c/123/456)`)
- **Код:** выделение ключевых фраз (`` `релиз` ``)

**MarkdownV2 Escape:**
- Спецсимволы требуют escape: `()[]{}.-!+=#|`
- Пример: `"Tech News (5 новых)"` → `"Tech News \\(5 новых\\)"`
- Функция: `escapeMarkdownV2(_ text: String) -> String`

**Архитектура:**
```swift
protocol MessageFormatter: Sendable {
    func format(_ summary: String) -> String
}

struct MarkdownV2Formatter: MessageFormatter {
    func format(_ summary: String) -> String {
        // Применяет форматирование + escape
    }
}

struct PlainTextFormatter: MessageFormatter {
    func format(_ summary: String) -> String {
        return summary // pass-through
    }
}
```

**BotNotifier integration:**
```swift
actor TelegramBotNotifier {
    private let formatter: MessageFormatter

    func send(_ message: String) async throws {
        let formatted = formatter.format(message)
        // sendMessage с parse_mode из formatter
    }
}
```

**Acceptance Criteria:**
- [ ] MarkdownV2Formatter: escape всех спецсимволов
- [ ] Форматирование: жирный (каналы), курсив (метаданные), ссылки
- [ ] Unit тесты: edge cases escape (вложенные скобки, смешанные символы)
- [ ] PlainTextFormatter: pass-through (для v0.5.0 обратная совместимость)

**Примечание v0.5.0:** Plain text (БЕЗ `parse_mode`) → escape НЕ нужен, форматирование отсутствует.

---

### v0.7.0: Voice & Video Note Transcription

**Статус:** 📝 Planned

**Цель:** Добавить текст из голосовых сообщений и видео-кружков в дайджест.

**Prerequisites:**
- ✅ v0.4.0: messageVoice/messageAudio/messagePhoto/messageVideo с caption

**Scope:**

1. **Premium Status Check:**
   - Проверка `user.isPremium` через `getMe()`
   - Логирование Premium статуса при старте
   - Если НЕ Premium → skip транскрипция (fallback: caption или пустая строка)

2. **Telegram Premium Transcription API:**
   - Метод: `messages.transcribeAudio` (TDLib)
   - Стоимость: **бесплатно для Premium** (без лимитов)
   - Поддержка: messageVoice + messageVideoNote
   - Cache: Telegram server-side (повторные запросы мгновенные)

3. **MessageContent Enum Update:**
   ```swift
   case voice(caption: FormattedText?, transcription: String?)
   case videoNote(transcription: String?)  // NEW: video circles
   ```

4. **ChannelMessageSource Logic:**
   - Если `isPremium` && messageVoice → `transcribeAudio()`
   - Если `isPremium` && messageVideoNote → `transcribeAudio()`
   - Иначе → caption или ""

5. **Error Handling:**
   - Если `transcribeAudio` fails → content = caption ?? ""
   - Логирование: "Transcription failed: chatId=X, messageId=Y, error=Z"
   - Retry: нет (TDLib кэширует, повторный вызов быстрый)

**User Story:**
- Как пользователь с Telegram Premium
- Я хочу видеть текст из голосовых сообщений в дайджесте
- Чтобы не слушать каждое голосовое вручную

**Acceptance Criteria:**
- [ ] Premium статус проверяется через `getMe()` при старте
- [ ] Voice messages транскрибируются если Premium
- [ ] VideoNote messages транскрибируются если Premium
- [ ] Транскрипция добавляется в `SourceMessage.content`
- [ ] Логирование: "Transcribing voice: chatId=X, messageId=Y, duration=Z sec"
- [ ] Error handling: если transcribeAudio fails → fallback на caption
- [ ] Component тест с mock transcription response

**Alternative (Fallback для non-Premium):**
- OpenAI Whisper API: $0.006/минута
- Процесс: download .ogg/.mp4 → Whisper API → transcription
- Настройка через env: `OPENAI_WHISPER_ENABLED=true`
- **Decision:** Отложено, приоритет на Premium пользователей

**Technical Notes:**
- Accuracy: ~85% (Google Speech Recognition)
- Telegram кэширует транскрипцию навсегда (повторные запросы бесплатны)
- Rate limits: Premium без лимитов

---

## 📋 После релиза новой версии

- [ ] Ревизия BACKLOG.md — актуализировать после каждого релиза
- [ ] Выбрать задачи для следующей версии из [BACKLOG.md](BACKLOG.md)
- [ ] Провести ретроспективу: оценить гипотезы из [предыдущего ретро](archived/RETRO-RESULT.md)

**Future Features:** См. [BACKLOG.md](BACKLOG.md)
