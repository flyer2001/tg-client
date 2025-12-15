# Spike Research: Telegram Bot API для v0.5.0

**Дата:** 2025-12-15
**Цель:** Определить архитектуру BotNotifier для отправки дайджестов через Telegram Bot API
**Scope v0.5.0:** Send-only бот (только отправка, без команд)

---

## 📋 Вопросы для исследования

1. ✅ Telegram Bot API: sendMessage (параметры, лимиты, ошибки)
2. ✅ chat_id получение (ограничения, /start)
3. ✅ swift-telegram-sdk обзор (нужна ли библиотека?)
4. ✅ Рекомендация: библиотека vs HTTP calls
5. ✅ **Live эксперимент:** реальные запросы к Bot API, JSON responses, MarkdownV2 escape

---

## 🧪 Live Experiment Results (2025-12-15)

**Бот:** `@private_digest_summary_bot`
**Тестов выполнено:** 10
**Статус:** ✅ Все критичные сценарии проверены

### Реальные JSON Responses

**Success (простое сообщение):**
```json
{
  "ok": true,
  "result": {
    "message_id": 2,
    "from": {
      "id": 8441950954,
      "is_bot": true,
      "first_name": "private_digest_summary_bot",
      "username": "private_digest_summary_bot"
    },
    "chat": {
      "id": 566335622,
      "first_name": "Сергей",
      "last_name": "Попыванов",
      "username": "serg_popyvanov",
      "type": "private"
    },
    "date": 1765827758,
    "text": "Spike test: простое сообщение"
  }
}
```

**Success (MarkdownV2 с форматированием):**
```json
{
  "ok": true,
  "result": {
    "message_id": 3,
    "text": "Жирный курсив код ссылка",
    "entities": [
      { "offset": 0, "length": 6, "type": "bold" },
      { "offset": 7, "length": 6, "type": "italic" },
      { "offset": 14, "length": 3, "type": "code" },
      { "offset": 18, "length": 6, "type": "text_link", "url": "https://example.com/" }
    ]
  }
}
```

**Error (invalid chat_id):**
```json
{
  "ok": false,
  "error_code": 400,
  "description": "Bad Request: chat not found"
}
```

**Error (empty text):**
```json
{
  "ok": false,
  "error_code": 400,
  "description": "Bad Request: message text is empty"
}
```

**Error (message too long > 4096):**
```json
{
  "ok": false,
  "error_code": 400,
  "description": "Bad Request: message is too long"
}
```

**Error (MarkdownV2 без escape):**
```json
{
  "ok": false,
  "error_code": 400,
  "description": "Bad Request: can't parse entities: Character '(' is reserved and must be escaped with the preceding '\\'"
}
```

### Критичные находки

1. **⚠️ MarkdownV2 escape ОБЯЗАТЕЛЕН:**
   - Символы `()` `[]` `{}` `.` `-` `!` и другие требуют `\\` escape
   - БЕЗ escape → error 400 "Character 'X' is reserved"
   - **Пример:** `"Tech News (2024)"` → `"Tech News \\(2024\\)"`

2. **✅ Лимит 4096 СИМВОЛОВ (не байт):**
   - 4096 chars → OK
   - 4097 chars → error 400 "message is too long"

3. **✅ Response содержит `entities` массив:**
   - НЕ упомянут в базовой документации
   - Полезен для проверки корректности форматирования
   - Типы: "bold", "italic", "code", "text_link"

4. **✅ getUpdates возвращает полную информацию о пользователе:**
   ```json
   {
     "from": {
       "id": 566335622,
       "is_premium": true,
       "language_code": "ru"
     }
   }
   ```
   - `is_premium: true` — критично для будущей транскрипции голосовых (v0.7.0)

---

## 1. Telegram Bot API: sendMessage

**Документация:** https://core.telegram.org/bots/api#sendmessage

### Параметры

**Обязательные:**
- `chat_id` (Int64 или String) — ID чата или @username канала
- `text` (String) — текст сообщения

**Опциональные (для MVP):**
- `parse_mode` (String) — форматирование: "Markdown", "HTML", "MarkdownV2"
- `disable_notification` (Bool) — отправить без звука

### Формат запроса

```http
POST https://api.telegram.org/bot<TOKEN>/sendMessage
Content-Type: application/json

{
  "chat_id": 123456789,
  "text": "Дайджест непрочитанных сообщений...",
  "parse_mode": "MarkdownV2"
}
```

### Лимиты

- **Размер сообщения:** 4096 символов (UTF-8)
- **Rate limits:** ~30 сообщений/секунду для разных чатов, 1 сообщение/секунду в один чат

### Ошибки

**Формат ответа (успех):**
```json
{
  "ok": true,
  "result": {
    "message_id": 123,
    "chat": { "id": 123456789 },
    "text": "..."
  }
}
```

**Формат ответа (ошибка):**
```json
{
  "ok": false,
  "error_code": 400,
  "description": "Bad Request: message text is empty"
}
```

**Типичные ошибки:**
- `400` — невалидные параметры (fail-fast, НЕ retry)
- `401` — невалидный bot token (fail-fast)
- `429` — rate limit (retry с exponential backoff)
- `5xx` — server error (retry)

### Форматирование (MarkdownV2)

**Рекомендовано:** MarkdownV2 (более строгий, предсказуемый)

**Escape символы:** `_`, `*`, `[`, `]`, `(`, `)`, `~`, `` ` ``, `>`, `#`, `+`, `-`, `=`, `|`, `{`, `}`, `.`, `!`

**Синтаксис:**
- **Жирный:** `*bold*`
- **Курсив:** `_italic_`
- **Моноширинный:** `` `code` ``
- **Ссылка:** `[text](https://example.com)`

---

## 2. Получение chat_id

**Критичный вопрос:** Как бот узнаёт chat_id для отправки первого сообщения?

### Ограничение Telegram

⚠️ **Бот НЕ может отправить первое сообщение пользователю.**

**Правило:** Пользователь ОБЯЗАН начать диалог первым (команда `/start` в Telegram UI).

### Решение для v0.5.0: Ручное получение

**Шаги для пользователя:**

1. Найти бота в Telegram: `@your_bot_name`
2. Отправить команду: `/start`
3. Получить chat_id через curl:
   ```bash
   curl -s "https://api.telegram.org/bot<TOKEN>/getUpdates" | jq '.result[0].message.chat.id'
   # Ответ: 123456789
   ```
4. Добавить в `.env`:
   ```bash
   TELEGRAM_BOT_CHAT_ID=123456789
   ```

**Обоснование:**
- ✅ Просто для single-user MVP
- ✅ Не нужен getUpdates / webhook в коде
- ✅ Меньше кода, быстрее реализация

**Для v0.6.0:** Автоматическое получение через getUpdates/webhook + StateManager

---

## 3. swift-telegram-sdk обзор

**GitHub:** https://github.com/nerzh/swift-telegram-sdk

### Статистика

- **Последний коммит:** 27 января 2025 (активная поддержка ✅)
- **Open issues:** 1
- **Лицензия:** MIT
- **Swift version:** 6.0+
- **Platform:** macOS 12+

### Зависимости

```swift
dependencies: [
    .package(url: "https://github.com/nerzh/swift-regular-expression.git", from: "0.2.4"),
    .package(url: "https://github.com/nerzh/swift-custom-logger.git", from: "1.1.0")
]
```

### API Coverage

- ✅ sendMessage
- ✅ getUpdates
- ✅ Обработка команд ботов
- ✅ Webhook support

### Оценка для v0.5.0

**Плюсы:**
- ✅ Полное покрытие Bot API
- ✅ Swift 6 support

**Минусы:**
- ⚠️ Избыточна для send-only (нужна для команд)
- ⚠️ +2 зависимости (регулярки + логгер)

**Когда использовать:**
- v0.6.0+ — если добавляем команды бота (`/start`, `/digest`)
- v0.6.0+ — если нужен webhook / long polling

---

## 🎯 Рекомендация для v0.5.0

### Решение: Прямые HTTP calls (URLSession)

**Обоснование:**

1. **Send-only = 1 метод:** Для отправки дайджеста нужен только `sendMessage`
2. **Переиспользование паттерна:** Аналогично OpenAISummaryGenerator (URLSession + retry)
3. **Меньше зависимостей:** Не нужна библиотека (избегаем +2 зависимости)
4. **Быстрее реализация:** ~2-3 дня vs ~4-5 дней с библиотекой
5. **Проще для MVP:** Понятный код, полный контроль

**Когда перейти на библиотеку:**
- v0.6.0+ — если добавляем команды бота
- v0.6.0+ — если нужны >3 методов Bot API

---

## 4. Архитектура BotNotifier (v0.5.0)

### Protocol

```swift
/// Отправка уведомлений через Telegram Bot
protocol BotNotifierProtocol: Sendable {
    /// Отправить сообщение пользователю
    /// - Parameter message: текст сообщения (MarkdownV2, max 4096 chars)
    /// - Throws: BotNotifierError
    func send(_ message: String) async throws
}
```

### Implementation

```swift
/// Реализация отправки через Telegram Bot API
actor TelegramBotNotifier: BotNotifierProtocol {
    private let token: String
    private let chatId: Int64
    private let httpClient: HTTPClient  // URLSession wrapper
    private let logger: Logger

    init(token: String, chatId: Int64, httpClient: HTTPClient, logger: Logger) {
        self.token = token
        self.chatId = chatId
        self.httpClient = httpClient
        self.logger = logger
    }

    func send(_ message: String) async throws {
        logger.info("Sending message to Telegram bot", metadata: [
            "chat_id": .stringConvertible(chatId),
            "message_length": .stringConvertible(message.count)
        ])

        let url = URL(string: "https://api.telegram.org/bot\(token)/sendMessage")!
        let body = SendMessageRequest(
            chatId: chatId,
            text: message,
            parseMode: "MarkdownV2"
        )

        // Retry logic: 3 attempts, exponential backoff (1s, 2s, 4s)
        let response: SendMessageResponse = try await withRetry(maxAttempts: 3) {
            try await httpClient.post(url, body: body)
        }

        guard response.ok else {
            throw BotNotifierError.sendFailed(
                code: response.errorCode ?? 0,
                description: response.description ?? "Unknown error"
            )
        }

        logger.info("Message sent successfully", metadata: [
            "message_id": .stringConvertible(response.result?.messageId ?? 0)
        ])
    }
}
```

### Модели (будут написаны в TDD)

**⚠️ Production модели пишутся в TDD цикле (Unit Test → Implementation).**

**На основе реальных JSON из секции "Live Experiment Results" нужно создать:**

1. **SendMessageRequest** — request body для `/sendMessage`
2. **SendMessageResponse** — response (success/error)
3. **Message** — результат успешной отправки
   - ⚠️ **Критично:** поле `entities` (найдено в live эксперименте, НЕ упомянуто в docs!)
4. **User** — информация о боте/пользователе
5. **Chat** — информация о чате
6. **MessageEntity** — форматирование (bold, italic, code, text_link)

**TDD порядок (TESTING.md):**
```
1. Unit Test для SendMessageRequest encoding (реальный JSON из live эксперимента)
2. Unit Test для SendMessageResponse decoding (success + error cases)
3. Unit Test для Message/User/Chat/MessageEntity decoding
4. Implementation → GREEN
```

**Реальные JSON для тестов:** см. секцию "Live Experiment Results" выше.

### Errors

```swift
enum BotNotifierError: Error, Sendable {
    case sendFailed(code: Int, description: String)
    case invalidToken
    case chatNotFound
    case messageTooLong(length: Int, limit: Int)
}
```

### Retry Strategy

**Переиспользуем паттерн из OpenAISummaryGenerator:**

- **Max attempts:** 3
- **Backoff:** 1s, 2s, 4s
- **Retry на:**
  - `429` — rate limit
  - `5xx` — server error
  - Network timeout
- **Fail-fast на:**
  - `400` — invalid parameters
  - `401` — invalid token
  - `404` — chat not found

---

## 5. Environment Variables

```bash
# Telegram Bot API
TELEGRAM_BOT_TOKEN=123456:ABC-DEF1234ghIkl-zyx57W2v1u123ew11
TELEGRAM_BOT_CHAT_ID=123456789
```

**Получение токена:**
1. Найти `@BotFather` в Telegram
2. Отправить `/newbot`
3. Следовать инструкциям
4. Скопировать токен

**Получение chat_id:**
1. Найти бота: `@your_bot_name`
2. Отправить `/start`
3. `curl -s "https://api.telegram.org/bot<TOKEN>/getUpdates" | jq '.result[0].message.chat.id'`

---

## 6. Testing Strategy

| Уровень | Mock Strategy | Цель |
|---------|---------------|------|
| **Unit** | - | SendMessageRequest encoding/decoding |
| **Component** | MockHTTPClient | TelegramBotNotifier + retry logic |
| **E2E** | Real Bot API | Manual test (реальный бот) |

### Edge Cases

**Component тесты:**
- ✅ Успешная отправка (200 OK)
- ✅ Retry на 429 (rate limit) → success после 2й попытки
- ✅ Retry на 5xx → success после 3й попытки
- ✅ Fail-fast на 400 (invalid request)
- ✅ Fail-fast на 401 (invalid token)
- ✅ Message length = 4096 (граница)
- ✅ Message length > 4096 → error

**E2E тест (manual):**
- Реальный Telegram бот
- Отправка дайджеста с MarkdownV2
- Проверка форматирования в Telegram UI

---

## 7. Pipeline Integration

**Целевой pipeline v0.5.0:**

```
fetch → digest → BotNotifier → markAsRead
  (1)      (2)         (3)          (4)
```

**DigestOrchestrator:**

```swift
actor DigestOrchestrator {
    private let messageSource: MessageSourceProtocol
    private let summaryGenerator: SummaryGeneratorProtocol
    private let botNotifier: BotNotifierProtocol  // NEW
    private let markAsReadService: MarkAsReadService

    func run() async throws {
        // 1. Fetch
        let messages = try await messageSource.fetchUnreadMessages()

        // 2. Digest (retry 3x)
        let summary = try await summaryGenerator.generate(messages: messages)

        // 3. BotNotifier (retry 3x)
        try await botNotifier.send(summary)

        // 4. Mark as read
        let chatIds = messages.groupedByChatId()
        try await markAsReadService.markAsRead(chatIds)
    }
}
```

---

## 🚀 Task Breakdown (Outside-In TDD)

**Prerequisite:**
1. ✅ Spike research — DONE (этот документ)
2. [ ] Architecture-First (7 блоков) — следующий шаг

**Implementation (TDD order):**

1. **DocC документация** — User Story (пользователь получает дайджест в Telegram)
2. **E2E тест (RED)** — DigestOrchestrator → BotNotifier integration
3. **Протокол** — BotNotifierProtocol
4. **Unit Tests** — SendMessageRequest/Response encoding/decoding
5. **Component тест (RED)** — TelegramBotNotifier + MockHTTPClient
6. **Implementation → GREEN** — TelegramBotNotifier
7. **Component Tests (edge cases)** — retry 429, fail-fast 400/401, 4096 limit
8. **DigestOrchestrator integration** — добавить BotNotifier в pipeline
9. **E2E manual test** — реальный Telegram бот
10. **Документация** — README.md (как получить token + chat_id)

**Estimate:** ~3-4 дня

---

## 📌 Критичные вопросы (ответы)

1. **Библиотека vs HTTP calls?**
   ✅ **HTTP calls** (URLSession) — проще для send-only

2. **Как получить chat_id?**
   ✅ Пользователь вручную: `/start` → getUpdates → env

3. **Send-only достаточно для v0.5.0?**
   ✅ **Да** — отправка дайджеста = единственная функция

4. **getUpdates нужен в коде?**
   ❌ **НЕТ** — пользователь получает chat_id через curl

5. **Команды бота нужны?**
   ❌ **НЕТ** — отложено в v0.6.0

---

## 🔄 Следующий шаг

**Передать в Senior Swift Architect:**
- Роль: Architecture-First (7 блоков)
- Компонент: TelegramBotNotifier (actor, retry, error handling)
- Детали: [ROLES.md](../ROLES.md) → Senior Swift Architect

**Файлы для обновления:**
- `MVP.md` — обновить секцию v0.5.0 (spike done ✅)
- `TASKS.md` — создать задачу "BotNotifier Architecture-First"
