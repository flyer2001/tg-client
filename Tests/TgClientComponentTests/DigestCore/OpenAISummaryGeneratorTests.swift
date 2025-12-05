import Testing
import Foundation
import FoundationNetworking
import Logging
@testable import DigestCore
@testable import TgClientModels
@testable import TestHelpers

/// Component тесты для OpenAISummaryGenerator.
///
/// **Scope:** Тестируем взаимодействие с HTTP клиентом (mock), без реального API.
///
/// **Тестируемые сценарии:**
/// - ✅ Успешный запрос (200 OK)
/// - ❌ HTTP ошибки (401, 429, 500)
/// - ❌ JSON parsing errors
@Suite("OpenAISummaryGenerator Component Tests")
struct OpenAISummaryGeneratorTests {

    @Test("Успешная генерация саммари через OpenAI API")
    func successfulGeneration() async throws {
        // Arrange: создаем валидный OpenAI response через модель
        let response = ChatCompletionResponse(
            choices: [
                ChatCompletionResponse.Choice(
                    message: ChatCompletionResponse.Choice.Message(
                        content: "**Tech News:** Обзор новых фич Swift 6"
                    )
                )
            ]
        )
        let responseData = try JSONEncoder().encode(response)

        // Настраиваем mock HTTP client
        let mockClient = MockHTTPClient()
        await mockClient.setStubResult(.success(responseData))

        let generator = OpenAISummaryGenerator(
            apiKey: "test-api-key",
            httpClient: mockClient,
            logger: Logger(label: "test")
        )

        let messages = [
            SourceMessage(
                chatId: 1,
                messageId: 1,
                content: "Swift 6 released",
                channelTitle: "Tech News",
                link: "https://t.me/tech/1"
            ),
            SourceMessage(
                chatId: 1,
                messageId: 2,
                content: "New concurrency features",
                channelTitle: "Tech News",
                link: "https://t.me/tech/2"
            )
        ]

        // Act: генерируем саммари
        let summary = try await generator.generate(messages: messages)

        // Assert: проверяем результат
        #expect(summary == "**Tech News:** Обзор новых фич Swift 6")
    }

    @Test("HTTP 401 Unauthorized → OpenAIError.unauthorized")
    func unauthorized() async throws {
        let mockClient = MockHTTPClient()
        let errorData = """
        {
            "error": {
                "message": "Incorrect API key provided",
                "type": "invalid_request_error"
            }
        }
        """.data(using: .utf8)!

        await mockClient.setStubResult(.failure(HTTPError.clientError(statusCode: 401, data: errorData)))

        let generator = OpenAISummaryGenerator(
            apiKey: "invalid-key",
            httpClient: mockClient,
            logger: Logger(label: "test")
        )

        let messages = [
            SourceMessage(chatId: 1, messageId: 1, content: "Message", channelTitle: "Test", link: nil)
        ]

        await #expect(throws: OpenAIError.unauthorized) {
            try await generator.generate(messages: messages)
        }
    }

    @Test("HTTP 429 Rate Limited → OpenAIError.rateLimited")
    func rateLimited() async throws {
        let mockClient = MockHTTPClient()
        let errorData = """
        {
            "error": {
                "message": "Rate limit reached",
                "type": "rate_limit_exceeded"
            }
        }
        """.data(using: .utf8)!

        await mockClient.setStubResult(.failure(HTTPError.clientError(statusCode: 429, data: errorData)))

        let generator = OpenAISummaryGenerator(
            apiKey: "test-key",
            httpClient: mockClient,
            logger: Logger(label: "test")
        )

        let messages = [
            SourceMessage(chatId: 1, messageId: 1, content: "Message", channelTitle: "Test", link: nil)
        ]

        await #expect(throws: OpenAIError.rateLimited) {
            try await generator.generate(messages: messages)
        }
    }

    @Test("HTTP 500 Server Error → OpenAIError.httpError")
    func serverError() async throws {
        let mockClient = MockHTTPClient()
        await mockClient.setStubResult(.failure(HTTPError.serverError(statusCode: 500, data: Data())))

        let generator = OpenAISummaryGenerator(
            apiKey: "test-key",
            httpClient: mockClient,
            logger: Logger(label: "test")
        )

        let messages = [
            SourceMessage(chatId: 1, messageId: 1, content: "Message", channelTitle: "Test", link: nil)
        ]

        await #expect(throws: OpenAIError.httpError(statusCode: 500)) {
            try await generator.generate(messages: messages)
        }
    }

    @Test("Invalid JSON response → DecodingError")
    func invalidJSON() async throws {
        let mockClient = MockHTTPClient()
        let invalidJSON = "{ invalid json }".data(using: .utf8)!
        await mockClient.setStubResult(.success(invalidJSON))

        let generator = OpenAISummaryGenerator(
            apiKey: "test-key",
            httpClient: mockClient,
            logger: Logger(label: "test")
        )

        let messages = [
            SourceMessage(chatId: 1, messageId: 1, content: "Message", channelTitle: "Test", link: nil)
        ]

        await #expect(throws: DecodingError.self) {
            try await generator.generate(messages: messages)
        }
    }

    @Test("Empty choices array → OpenAIError.emptyResponse")
    func emptyChoices() async throws {
        let response = ChatCompletionResponse(choices: [])
        let responseData = try JSONEncoder().encode(response)

        let mockClient = MockHTTPClient()
        await mockClient.setStubResult(.success(responseData))

        let generator = OpenAISummaryGenerator(
            apiKey: "test-key",
            httpClient: mockClient,
            logger: Logger(label: "test")
        )

        let messages = [
            SourceMessage(chatId: 1, messageId: 1, content: "Message", channelTitle: "Test", link: nil)
        ]

        await #expect(throws: OpenAIError.emptyResponse) {
            try await generator.generate(messages: messages)
        }
    }
}
