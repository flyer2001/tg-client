import Foundation

/// Протокол для отправки уведомлений через Telegram бота.
///
/// **Scope v0.5.0:** Send-only (только отправка дайджестов, БЕЗ команд).
///
/// ## Использование
///
/// ```swift
/// let notifier = TelegramBotNotifier(
///     token: botToken,
///     chatId: chatId,
///     httpClient: httpClient,
///     logger: logger
/// )
///
/// try await notifier.send("Дайджест непрочитанных сообщений...")
/// ```
///
/// ## Ограничения (v0.5.0)
///
/// - **Plain text ТОЛЬКО** — дайджест отправляется БЕЗ `parse_mode` (без форматирования)
/// - **Fail-fast >4096 chars** — если дайджест превышает лимит Bot API, выбрасывается ошибка
/// - **Retry strategy** — 429/5xx (3 попытки, exponential backoff: 1s, 2s, 4s)
/// - **Fail-fast errors** — 400/401 (НЕ retry, проблема конфигурации или бага)
///
/// ## Future enhancements (v0.6.0+)
///
/// - **MarkdownV2 форматирование** — жирный текст, курсив, ссылки, код
/// - **Intelligent split** — разбивка >4096 chars по параграфам, transactional отправка
/// - **Rate limit handling** — delay 1 sec между частями (соблюдение 1 msg/sec limit)
///
/// ## Ссылки
///
/// - Telegram Bot API: https://core.telegram.org/bots/api#sendmessage
/// - Spike research: `.claude/archived/spike-telegram-bot-api-2025-12-15.md`
/// - Architecture: `.claude/archived/architecture-v0.5.0-botnotifier-2025-12-16.md`
public protocol BotNotifierProtocol: Sendable {
    /// Отправляет текстовое сообщение пользователю через Telegram бота.
    ///
    /// **v0.5.0:** Отправка plain text (БЕЗ `parse_mode`). Fail-fast если >4096 chars.
    ///
    /// - Parameter message: Текст дайджеста (plain text, ≤4096 chars)
    /// - Throws: `BotNotifierError` при ошибках API или превышении лимита
    ///
    /// ## Retry strategy
    ///
    /// - **Retry (3 попытки):** 429 rate limit, 5xx server error, network timeout
    /// - **Fail-fast (НЕ retry):** 400 invalid request, 401 invalid token, 404 chat not found
    ///
    /// ## Логирование
    ///
    /// - **Начало:** `logger.info("Sending message to Telegram bot")`
    /// - **Retry:** `logger.warning("Retrying after delay")` (автоматически через `withRetry`)
    /// - **Success:** `logger.info("Message sent successfully", metadata: ["message_id": ...])`
    /// - **Error:** `logger.error("Failed to send message", metadata: ["error_code": ..., "description": ...])`
    func send(_ message: String) async throws
}
