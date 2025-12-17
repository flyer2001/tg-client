import Testing
import Foundation
import FoundationExtensions
@testable import DigestCore

/// Unit тесты для Telegram Bot API моделей (sendMessage).
///
/// **Документация Telegram Bot API:**
/// - sendMessage: https://core.telegram.org/bots/api#sendmessage
/// - Message Object: https://core.telegram.org/bots/api#message
/// - Error Response: https://core.telegram.org/bots/api#making-requests
///
/// **Реальные JSON responses:**
/// Все JSON примеры взяты из live эксперимента (spike research):
/// `.claude/archived/spike-telegram-bot-api-2025-12-15.md` (секция "Live Experiment Results")
///
/// **Scope:** Тестируем encoding/decoding моделей с реальными JSON из Bot API.
@Suite("Telegram Bot API Models Encoding/Decoding")
struct TelegramBotAPIModelsTests {

    // MARK: - SendMessageRequest Encoding

    /// SendMessageRequest: encoding plain text (БЕЗ parse_mode).
    ///
    /// **v0.5.0:** Plain text ТОЛЬКО (БЕЗ форматирования).
    @Test("SendMessageRequest: encoding plain text (v0.5.0)")
    func encodePlainTextRequest() throws {
        let request = SendMessageRequest(
            chatId: 566335622,
            text: "Spike test: простое сообщение"
        )

        let encoder = JSONEncoder.telegramBot()
        let data = try encoder.encode(request)
        let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]

        // Проверяем что encoding работает (chat_id в snake_case)
        #expect(json["chat_id"] as? Int64 == 566335622)
        #expect(json["text"] as? String == "Spike test: простое сообщение")
        // v0.5.0: parse_mode отсутствует (plain text)
        #expect(json["parse_mode"] == nil)
    }

    // MARK: - SendMessageResponse Decoding (Success)

    /// SendMessageResponse: decoding success (простое сообщение).
    ///
    /// **Реальный JSON из live эксперимента (spike research):**
    /// Тест "Success (простое сообщение)" — строки 27-50 spike документа.
    @Test("SendMessageResponse: decoding success (plain text)")
    func decodeSuccessResponse() throws {
        // Реальный JSON из spike research (success case)
        let jsonString = """
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
        """

        let data = jsonString.data(using: .utf8)!
        let decoder = JSONDecoder.telegramBot()
        let response = try decoder.decode(SendMessageResponse.self, from: data)

        // Проверяем success response
        #expect(response.ok == true)
        #expect(response.result != nil)
        #expect(response.result?.messageId == 2)
        #expect(response.result?.text == "Spike test: простое сообщение")
        #expect(response.result?.from.isBot == true)
        #expect(response.result?.from.username == "private_digest_summary_bot")
        #expect(response.result?.chat.id == 566335622)
        #expect(response.result?.chat.type == "private")

        // v0.5.0: ошибка должна быть nil
        #expect(response.errorCode == nil)
        #expect(response.description == nil)
    }

    // MARK: - SendMessageResponse Decoding (Error)

    /// SendMessageResponse: decoding error (invalid chat_id).
    ///
    /// **Реальный JSON из live эксперимента (spike research):**
    /// Тест "Error (invalid chat_id)" — строки 69-75 spike документа.
    @Test("SendMessageResponse: decoding error (invalid chat_id)")
    func decodeErrorInvalidChatId() throws {
        // Реальный JSON из spike research (error case: 400)
        let jsonString = """
        {
          "ok": false,
          "error_code": 400,
          "description": "Bad Request: chat not found"
        }
        """

        let data = jsonString.data(using: .utf8)!
        let decoder = JSONDecoder.telegramBot()
        let response = try decoder.decode(SendMessageResponse.self, from: data)

        // Проверяем error response
        #expect(response.ok == false)
        #expect(response.result == nil)
        #expect(response.errorCode == 400)
        #expect(response.description == "Bad Request: chat not found")
    }

    /// SendMessageResponse: decoding error (empty text).
    ///
    /// **Реальный JSON из live эксперимента (spike research):**
    /// Тест "Error (empty text)" — строки 77-83 spike документа.
    @Test("SendMessageResponse: decoding error (empty text)")
    func decodeErrorEmptyText() throws {
        // Реальный JSON из spike research (error case: 400)
        let jsonString = """
        {
          "ok": false,
          "error_code": 400,
          "description": "Bad Request: message text is empty"
        }
        """

        let data = jsonString.data(using: .utf8)!
        let decoder = JSONDecoder.telegramBot()
        let response = try decoder.decode(SendMessageResponse.self, from: data)

        #expect(response.ok == false)
        #expect(response.errorCode == 400)
        #expect(response.description == "Bad Request: message text is empty")
    }

    /// SendMessageResponse: decoding error (message too long >4096).
    ///
    /// **Реальный JSON из live эксперимента (spike research):**
    /// Тест "Error (message too long > 4096)" — строки 85-91 spike документа.
    @Test("SendMessageResponse: decoding error (message too long)")
    func decodeErrorMessageTooLong() throws {
        // Реальный JSON из spike research (error case: 400)
        let jsonString = """
        {
          "ok": false,
          "error_code": 400,
          "description": "Bad Request: message is too long"
        }
        """

        let data = jsonString.data(using: .utf8)!
        let decoder = JSONDecoder.telegramBot()
        let response = try decoder.decode(SendMessageResponse.self, from: data)

        #expect(response.ok == false)
        #expect(response.errorCode == 400)
        #expect(response.description == "Bad Request: message is too long")
    }

    // MARK: - BotAPIError Tests

    /// BotAPIError: проверка isRetryable для 429 rate limit.
    @Test("BotAPIError.isRetryable: 429 Rate Limited")
    func isRetryableRateLimited() {
        let error = BotAPIError.apiError(code: 429, description: "Too Many Requests")
        #expect(error.isRetryable == true)
    }

    /// BotAPIError: проверка isRetryable для 500 server error.
    @Test("BotAPIError.isRetryable: 500 Internal Server Error")
    func isRetryableServerError() {
        let error = BotAPIError.apiError(code: 500, description: "Internal Server Error")
        #expect(error.isRetryable == true)
    }

    /// BotAPIError: проверка isRetryable для 503 service unavailable.
    @Test("BotAPIError.isRetryable: 503 Service Unavailable")
    func isRetryableServiceUnavailable() {
        let error = BotAPIError.apiError(code: 503, description: "Service Unavailable")
        #expect(error.isRetryable == true)
    }

    /// BotAPIError: НЕ retryable для 400 bad request.
    @Test("BotAPIError.isRetryable: 400 Bad Request (fail-fast)")
    func isRetryableBadRequest() {
        let error = BotAPIError.apiError(code: 400, description: "Bad Request")
        #expect(error.isRetryable == false)
    }

    /// BotAPIError: НЕ retryable для 401 unauthorized.
    @Test("BotAPIError.isRetryable: 401 Unauthorized (fail-fast)")
    func isRetryableUnauthorized() {
        let error = BotAPIError.apiError(code: 401, description: "Unauthorized")
        #expect(error.isRetryable == false)
    }

    /// BotAPIError: НЕ retryable для 404 chat not found.
    @Test("BotAPIError.isRetryable: 404 Not Found (fail-fast)")
    func isRetryableNotFound() {
        let error = BotAPIError.apiError(code: 404, description: "Not Found")
        #expect(error.isRetryable == false)
    }

    /// BotAPIError: messageTooLong case.
    @Test("BotAPIError: messageTooLong case")
    func messageTooLongError() {
        let error = BotAPIError.messageTooLong(length: 5000, limit: 4096)
        #expect(error.isRetryable == false)
    }
}
