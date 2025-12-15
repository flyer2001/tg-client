# Architecture Design: BotNotifier v0.5.0

**Дата:** 2025-12-16
**Роль:** Senior Swift Architect
**Компонент:** TelegramBotNotifier (send-only для MVP)

---

## 📚 Контекст из Spike Research

**Spike документ:** `.claude/archived/spike-telegram-bot-api-2025-12-15.md`

### Ключевые выводы spike research:

1. **HTTP calls (URLSession)** вместо библиотеки — проще для send-only
2. **Bot API лимиты:**
   - 4096 chars — точный лимит (НЕ байты)
   - 30 msg/sec для разных чатов, 1 msg/sec для одного чата
3. **Live эксперимент выполнен:** 10 тестов с реальным ботом
4. **Критичные находки:**
   - MarkdownV2 escape требует `\\` для `()[]{}.-!` и других
   - Response содержит `entities` поле (НЕ в docs, найдено в live)
   - Error format: `{"ok": false, "error_code": 400, "description": "..."}`
5. **Retry стратегия:** 429 rate limit, 5xx server error
6. **Fail-fast:** 400 invalid request, 401 invalid token

---

## 🏗️ Architecture-First (7 блоков)

### 1. Concurrency

**Решение:** Actor (TelegramBotNotifier) — sequential retry внутри send().

- **Actor isolation:** sequential retry через `withRetry`
- **URLSession:** НЕ TDLib (Bot API = отдельный HTTP протокол)
- **Retry:** 3 попытки, exponential backoff (1s, 2s, 4s)
- **Deadlock риски:** НЕТ (нет circular dependencies)

### 2. Performance

**Решение:** Rate limit через error handling (429), backpressure НЕ нужен.

- **MVP:** Single-user, 1 дайджест раз в 30-60 минут → никогда не достигнем rate limit
- **Retry на 429:** `withRetry` обработает автоматически (exponential backoff)
- **v0.6.0 split:** Delay 1 sec между частями (соблюдаем 1 msg/sec limit)

### 3. Memory

**Решение:** Fail-fast если >4096 chars (throw error).

- **v0.5.0:** `guard message.count <= 4096 else { throw .messageTooLong }`
- **Лимит:** 4096 **chars** (НЕ байты) — подтверждено в live эксперименте
- **Почему fail-fast:** Пользователь увидит ошибку → скорректирует AI prompt
- **v0.6.0:** Intelligent split (разбить по параграфам, сохранить форматирование)

### 4. Отказоустойчивость

**Решение:** Retry на 429/5xx (3 попытки), fail-fast на 400/401.

**Retry (через `withRetry`):**
- `429` — rate limit
- `5xx` — server error
- `TimeoutError` — network timeout

**Fail-fast (НЕ retry):**
- `400` — invalid request (баг в коде)
- `401` — invalid token (проблема конфигурации)
- `404` — chat not found (неверный chat_id в env)

**Timeout:** 30 sec per attempt

**shouldRetry логика:**
```swift
shouldRetry: { error, attempt in
    if let apiError = error as? BotAPIError {
        return apiError.code == 429 || (500...599).contains(apiError.code)
    }
    return error is TimeoutError
}
```

### 5. Pipeline integration

**Решение:** Sequential: fetch → digest → **BotNotifier** → markAsRead.

```swift
actor DigestOrchestrator {
    func run() async throws {
        // 1. Fetch
        let messages = try await messageSource.fetchUnreadMessages()

        // 2. Digest (retry 3x)
        let summary = try await summaryGenerator.generate(messages: messages)

        // 3. BotNotifier (retry 3x)
        try await botNotifier.send(summary)

        // 4. Mark as read (ТОЛЬКО после успешной отправки)
        let chatIds = messages.groupedByChatId()
        try await markAsReadService.markAsRead(chatIds)
    }
}
```

**Критично:** markAsRead ПОСЛЕ BotNotifier.send() — если send() упадёт → сообщения останутся unread.

### 6. Наблюдаемость

**Решение:** Логи на каждом шаге (начало, retry, success/error).

```swift
// Начало
logger.info("Sending message to Telegram bot", metadata: [
    "chat_id": "\(chatId)",
    "message_length": "\(message.count)"
])

// Retry (автоматически из withRetry)
logger.warning("Retrying after delay", metadata: [
    "attempt": "2/3",
    "error": "\(error)"
])

// Success
logger.info("Message sent successfully", metadata: [
    "message_id": "\(messageId)"
])

// Error
logger.error("Failed to send message", metadata: [
    "error_code": "\(code)",
    "description": "\(description)"
])
```

**Debug level:** Request/response body (для отладки).

### 7. Testing стратегия

**Решение:** MockHTTPClient (boundary mock), TSan НЕ критичен.

**Mock стратегия:**
- **Mock:** MockHTTPClient (переиспользуем из Tests/TestHelpers)
- **НЕ mock:** BotNotifier logic (реальная логика)

**Edge cases (Component тесты):**
- ✅ Success (200 OK)
- ✅ Retry на 429 → success после 2й попытки
- ✅ Retry на 5xx → success после 3й попытки
- ✅ Fail-fast на 400 (invalid request)
- ✅ Fail-fast на 401 (invalid token)
- ✅ Message length = 4096 (граница)
- ✅ Message length > 4096 → throw error
- ✅ Timeout (30 sec)

**Unit тесты:**
- SendMessageRequest encoding → реальный JSON
- SendMessageResponse decoding (success + error cases)

**TSan:** НЕ критичен (actor isolation, sequential retry, нет shared mutable state).

---

## 🎯 Критичные решения

### 1. MarkdownV2 escape — где?

**Решение:** Plain text для v0.5.0, MarkdownV2Formatter в v0.6.0.

- **v0.5.0:** БЕЗ `parse_mode` → escape НЕ нужен
- **v0.6.0:** Отдельный `MarkdownV2Formatter` компонент (между SummaryGenerator и BotNotifier)

**Обоснование:** Простота для MVP, форматирование не критично на старте.

### 2. Message >4096 — truncate или split?

**Решение:** Fail-fast для v0.5.0, transactional split в v0.6.0.

- **v0.5.0:** `throw BotNotifierError.messageTooLong(length, limit: 4096)`
- **v0.6.0:** Transactional split (all-or-nothing):
  - Разбить по параграфам (сохранить форматирование)
  - Sequential отправка (part 1 → part 2 → part 3)
  - Delay 1 sec между частями (rate limit 1 msg/sec)
  - Fail-fast: если part N failed → throw `partialFailure(sent: N-1, total: M)`

**Обоснование:** Пользователь получит feedback → скорректирует AI prompt. Split усложняет MVP.

### 3. HTTPClient — переиспользовать?

**Решение:** Переиспользуем `HTTPClientProtocol` + `URLSessionHTTPClient` + `MockHTTPClient`.

**Обоснование:**
- ✅ Уже есть готовый код (Sources/DigestCore/HTTP/)
- ✅ Consistency: как OpenAISummaryGenerator
- ✅ Меньше кода (не дублируем HTTP логику)

---

## 🚀 Handoff в TDD (Testing Architect)

### Prerequisite

- ✅ Spike research DONE: `.claude/archived/spike-telegram-bot-api-2025-12-15.md`
- ✅ Architecture-First DONE: этот документ
- ✅ Live эксперимент выполнен (10 тестов, реальные JSON)

### TDD Order (Outside-In)

**Роль:** Senior Testing Architect

**Читать перед началом:**
- TESTING.md (Outside-In TDD workflow)
- TESTING-PATTERNS.md (паттерны моков, async тесты)
- Этот документ (Architecture Design)
- Spike research (реальные JSON для Unit тестов)

**Порядок TDD:**

1. **DocC документация** — User Story (пользователь получает дайджест в Telegram)
2. **E2E тест (RED)** — DigestOrchestrator → BotNotifier integration
3. **Протокол** — BotNotifierProtocol:
   ```swift
   protocol BotNotifierProtocol: Sendable {
       func send(_ message: String) async throws
   }
   ```
4. **Unit Tests (RED)** — SendMessageRequest/Response encoding/decoding
   - Использовать реальные JSON из spike research (секция "Live Experiment Results")
5. **Models → GREEN** — SendMessageRequest, SendMessageResponse, BotAPIError
6. **Component тест (RED)** — TelegramBotNotifier + MockHTTPClient (happy path)
7. **Implementation → GREEN** — TelegramBotNotifier (actor + withRetry)
8. **Component Tests (edge cases)** — retry 429, fail-fast 400/401, >4096 limit, timeout
9. **DigestOrchestrator integration** — добавить BotNotifier в pipeline
10. **E2E manual test** — реальный Telegram бот (отправка дайджеста)
11. **Документация** — README.md (как получить token + chat_id)

### Переиспользуемые компоненты

- `withRetry` + `withTimeout` — FoundationExtensions/RetryHelpers.swift
- `HTTPClientProtocol` — Sources/DigestCore/HTTP/HTTPClientProtocol.swift
- `URLSessionHTTPClient` — Sources/DigestCore/HTTP/URLSessionHTTPClient.swift
- `MockHTTPClient` — Tests/TestHelpers/MockHTTPClient.swift

### Модели для реализации

**Из spike research (реальные JSON в `.claude/archived/spike-telegram-bot-api-2025-12-15.md`):**

1. **SendMessageRequest** — request body для `/sendMessage`
2. **SendMessageResponse** — response (success/error)
3. **Message** — результат успешной отправки
4. **BotAPIError** — ошибка Bot API (error_code + description)

**⚠️ Критично:** Модели пишутся в TDD цикле (Unit Test → Implementation), НЕ заранее!

### Acceptance Criteria (v0.5.0)

**Функциональные:**
- [ ] Отправляет plain text дайджест в Telegram бота
- [ ] Fail-fast если message >4096 chars
- [ ] Retry на 429/5xx (3 попытки, exponential backoff)
- [ ] Fail-fast на 400/401 (НЕ retry)
- [ ] Timeout 30 sec per attempt
- [ ] Pipeline: fetch → digest → BotNotifier → markAsRead

**Технические:**
- [ ] Component тесты: 8 edge cases покрыты
- [ ] Unit тесты: SendMessageRequest/Response encoding/decoding
- [ ] Переиспользованы: withRetry, HTTPClientProtocol, MockHTTPClient
- [ ] Логирование: начало, retry, success, error
- [ ] E2E manual test: реальный бот получил дайджест

**Env vars:**
- `TELEGRAM_BOT_TOKEN` — bot token из @BotFather
- `TELEGRAM_BOT_CHAT_ID` — chat_id (пользователь получает через `/start` + `getUpdates`)

---

## 📋 Обновления документации

**Обновлено:**
- MVP.md — v0.5.0 scope (plain text, fail-fast >4096, retry strategy)
- MVP.md — v0.6.0 scope (split + rate limit delay, MarkdownV2Formatter)
- retro-v0.5.0.md — инцидент #3 (Architecture-First "огромная портянка текста")

**Следующие обновления (после TDD):**
- ARCHITECTURE.md — добавить BotNotifier в диаграмму pipeline
- README.md — инструкция получения bot token + chat_id
- DEPLOY.md — новые env vars (TELEGRAM_BOT_TOKEN, TELEGRAM_BOT_CHAT_ID)

---

**Готово к TDD!** 🚀
