import Testing
import Foundation
#if os(Linux)
import FoundationNetworking
#endif
import Logging
@testable import DigestCore
@testable import TestHelpers

/// Component тесты для TelegramBotNotifier.
///
/// **Scope:** Тестируем взаимодействие с HTTP клиентом (mock), без реального Bot API.
///
/// **Модели:**
/// - ``SendMessageRequest`` — request body для /sendMessage
/// - ``SendMessageResponse`` — response (success/error)
@Suite("TelegramBotNotifier Component Tests")
struct TelegramBotNotifierTests {

    @Test("Успешная отправка plain text сообщения")
    func sendMessage_success() async throws {
        // Arrange: создаем валидный Bot API response через модель
        let response = SendMessageResponse(
            ok: true,
            result: Message(
                messageId: 2,
                from: User(
                    id: 8441950954,
                    isBot: true,
                    firstName: "private_digest_summary_bot",
                    username: "private_digest_summary_bot"
                ),
                chat: Chat(
                    id: 566335622,
                    firstName: "Сергей",
                    lastName: "Попыванов",
                    username: "serg_popyvanov",
                    type: "private"
                ),
                date: 1765827758,
                text: "Spike test: простое сообщение"
            )
        )
        let responseData = try JSONEncoder.telegramBot().encode(response)

        // Настраиваем mock HTTP client
        let mockClient = MockHTTPClient()
        await mockClient.setStubResult(.success(responseData))

        let notifier = TelegramBotNotifier(
            botToken: "test-token",
            chatId: 566335622,
            httpClient: mockClient,
            logger: Logger(label: "test")
        )

        // Act: отправляем сообщение
        try await notifier.send("Spike test: простое сообщение")

        // Assert: проверяем что HTTP запрос был отправлен
        let sentRequests = await mockClient.sentRequests
        #expect(sentRequests.count == 1)

        // Проверяем URL
        let request = sentRequests[0]
        #expect(request.url?.absoluteString == "https://api.telegram.org/bottest-token/sendMessage")

        // Проверяем HTTP метод
        #expect(request.httpMethod == "POST")

        // Проверяем Content-Type header
        #expect(request.value(forHTTPHeaderField: "Content-Type") == "application/json")

        // Проверяем body
        let requestBody = try #require(request.httpBody)
        let sentRequest = try JSONDecoder.telegramBot().decode(SendMessageRequest.self, from: requestBody)
        #expect(sentRequest.chatId == 566335622)
        #expect(sentRequest.text == "Spike test: простое сообщение")
    }

    @Test("Message length > 4096 chars → throw BotAPIError.messageTooLong")
    func sendMessage_messageTooLong() async throws {
        let mockClient = MockHTTPClient()
        let notifier = TelegramBotNotifier(
            botToken: "test-token",
            chatId: 566335622,
            httpClient: mockClient,
            logger: Logger(label: "test")
        )

        let longMessage = String(repeating: "a", count: 4097)

        await #expect(throws: BotAPIError.self) {
            try await notifier.send(longMessage)
        }

        // Проверяем что HTTP запрос НЕ был отправлен (fail-fast)
        let callCount = await mockClient.callCount
        #expect(callCount == 0)
    }

    @Test("Message length = 4096 chars (граница) → success")
    func sendMessage_exactLimit() async throws {
        let response = SendMessageResponse(
            ok: true,
            result: Message(
                messageId: 3,
                from: User(id: 123, isBot: true, firstName: "bot", username: nil),
                chat: Chat(id: 456, firstName: nil, lastName: nil, username: nil, type: "private"),
                date: 1765827758,
                text: String(repeating: "a", count: 4096)
            )
        )
        let responseData = try JSONEncoder.telegramBot().encode(response)

        let mockClient = MockHTTPClient()
        await mockClient.setStubResult(.success(responseData))

        let notifier = TelegramBotNotifier(
            botToken: "test-token",
            chatId: 456,
            httpClient: mockClient,
            logger: Logger(label: "test")
        )

        let exactLimitMessage = String(repeating: "a", count: 4096)
        try await notifier.send(exactLimitMessage)

        let callCount = await mockClient.callCount
        #expect(callCount == 1)
    }

    @Test("Fail-fast на 400 Bad Request")
    func sendMessage_failFast400() async throws {
        // Error response из spike research (строки 69-76)
        let errorResponse = SendMessageResponse(
            ok: false,
            errorCode: 400,
            description: "Bad Request: chat not found"
        )
        let responseData = try JSONEncoder.telegramBot().encode(errorResponse)

        let mockClient = MockHTTPClient()
        await mockClient.setStubResult(.success(responseData))

        let notifier = TelegramBotNotifier(
            botToken: "test-token",
            chatId: 999999,
            httpClient: mockClient,
            logger: Logger(label: "test")
        )

        await #expect(throws: BotAPIError.self) {
            try await notifier.send("Test message")
        }
    }

    @Test("Fail-fast на 401 Unauthorized")
    func sendMessage_failFast401() async throws {
        let errorResponse = SendMessageResponse(
            ok: false,
            errorCode: 401,
            description: "Unauthorized"
        )
        let responseData = try JSONEncoder.telegramBot().encode(errorResponse)

        let mockClient = MockHTTPClient()
        await mockClient.setStubResult(.success(responseData))

        let notifier = TelegramBotNotifier(
            botToken: "invalid-token",
            chatId: 566335622,
            httpClient: mockClient,
            logger: Logger(label: "test")
        )

        await #expect(throws: BotAPIError.self) {
            try await notifier.send("Test message")
        }
    }

    @Test("Retry на 429 Rate Limited → success после 2й попытки")
    func sendMessage_retry429() async throws {
        // Используем queue mode для retry сценария
        let errorResponse = SendMessageResponse(
            ok: false,
            errorCode: 429,
            description: "Too Many Requests: retry after 1"
        )
        let errorData = try JSONEncoder.telegramBot().encode(errorResponse)

        let successResponse = SendMessageResponse(
            ok: true,
            result: Message(
                messageId: 10,
                from: User(id: 123, isBot: true, firstName: "bot", username: nil),
                chat: Chat(id: 456, firstName: nil, lastName: nil, username: nil, type: "private"),
                date: 1765827758,
                text: "Retried message"
            )
        )
        let successData = try JSONEncoder.telegramBot().encode(successResponse)

        let mockClient = MockHTTPClient()
        // 1й вызов → 429 error, 2й вызов → success
        await mockClient.setStubQueue([
            .success(errorData),   // 1й попытка: 429 error
            .success(successData)  // 2й попытка: success
        ])

        let notifier = TelegramBotNotifier(
            botToken: "test-token",
            chatId: 456,
            httpClient: mockClient,
            logger: Logger(label: "test")
        )

        // Должен успешно отправить после retry
        try await notifier.send("Test message")

        // Проверяем что было 2 вызова
        let callCount = await mockClient.callCount
        #expect(callCount == 2)
    }

    @Test("Retry на 500 Server Error → success после 2й попытки")
    func sendMessage_retry5xx() async throws {
        let errorResponse = SendMessageResponse(
            ok: false,
            errorCode: 500,
            description: "Internal Server Error"
        )
        let errorData = try JSONEncoder.telegramBot().encode(errorResponse)

        let successResponse = SendMessageResponse(
            ok: true,
            result: Message(
                messageId: 11,
                from: User(id: 123, isBot: true, firstName: "bot", username: nil),
                chat: Chat(id: 456, firstName: nil, lastName: nil, username: nil, type: "private"),
                date: 1765827758,
                text: "Retried message"
            )
        )
        let successData = try JSONEncoder.telegramBot().encode(successResponse)

        let mockClient = MockHTTPClient()
        await mockClient.setStubQueue([
            .success(errorData),   // 1й попытка: 500 error
            .success(successData)  // 2й попытка: success
        ])

        let notifier = TelegramBotNotifier(
            botToken: "test-token",
            chatId: 456,
            httpClient: mockClient,
            logger: Logger(label: "test")
        )

        try await notifier.send("Test message")

        let callCount = await mockClient.callCount
        #expect(callCount == 2)
    }

    @Test("Retry exhausted (все 3 попытки 429) → throw BotAPIError")
    func sendMessage_retryExhausted() async throws {
        let errorResponse = SendMessageResponse(
            ok: false,
            errorCode: 429,
            description: "Too Many Requests"
        )
        let errorData = try JSONEncoder.telegramBot().encode(errorResponse)

        let mockClient = MockHTTPClient()
        // Все 3 попытки возвращают 429
        await mockClient.setStubQueue([
            .success(errorData),  // 1й попытка
            .success(errorData),  // 2й попытка
            .success(errorData)   // 3й попытка
        ])

        let notifier = TelegramBotNotifier(
            botToken: "test-token",
            chatId: 456,
            httpClient: mockClient,
            logger: Logger(label: "test")
        )

        // Должен выбросить ошибку после исчерпания попыток
        await #expect(throws: BotAPIError.self) {
            try await notifier.send("Test message")
        }

        // Проверяем что было 3 вызова
        let callCount = await mockClient.callCount
        #expect(callCount == 3)
    }

    @Test("Fail-fast на 404 Chat Not Found")
    func sendMessage_failFast404() async throws {
        let errorResponse = SendMessageResponse(
            ok: false,
            errorCode: 404,
            description: "Not Found: chat not found"
        )
        let responseData = try JSONEncoder.telegramBot().encode(errorResponse)

        let mockClient = MockHTTPClient()
        await mockClient.setStubResult(.success(responseData))

        let notifier = TelegramBotNotifier(
            botToken: "test-token",
            chatId: 999999,
            httpClient: mockClient,
            logger: Logger(label: "test")
        )

        await #expect(throws: BotAPIError.self) {
            try await notifier.send("Test message")
        }

        // Проверяем что НЕ было retry (только 1 попытка)
        let callCount = await mockClient.callCount
        #expect(callCount == 1)
    }
}
