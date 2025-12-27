import Foundation

/// Ошибки Telegram Bot API.
///
/// **Документация:** https://core.telegram.org/bots/api#making-requests
public enum BotAPIError: Error, Sendable {
    /// Ошибка API с кодом и описанием.
    case apiError(code: Int, description: String)

    /// Сообщение превышает лимит Bot API (4096 chars).
    case messageTooLong(length: Int, limit: Int)

    /// Ошибка конфигурации (невалидный URL, token).
    case invalidConfiguration(message: String)

    /// Проверка нужен ли retry для ошибки.
    ///
    /// **Retry (3 попытки, exponential backoff):**
    /// - 429 — rate limit
    /// - 5xx — server error
    ///
    /// **Fail-fast (НЕ retry):**
    /// - 400 — invalid request (баг в коде)
    /// - 401 — invalid token (проблема конфигурации)
    /// - 404 — chat not found (неверный chat_id)
    public var isRetryable: Bool {
        switch self {
        case .apiError(let code, _):
            return code == 429 || (500...599).contains(code)
        case .messageTooLong, .invalidConfiguration:
            return false
        }
    }
}
