import Testing
import Foundation
#if os(Linux)
import FoundationNetworking
#endif
import Logging
@testable import DigestCore
@testable import TgClientModels
@testable import TestHelpers

/// Component тесты для DigestOrchestrator.
///
/// **Scope:** Тестируем координацию pipeline через SummaryGenerator.
///
/// **Правило мокирования:** Используем реальный OpenAISummaryGenerator + MockHTTPClient.
/// НЕ создаём MockSummaryGenerator (см. TESTING.md#правила-мокирования).
///
/// **Тестируемые сценарии:**
/// - ✅ Успешная генерация дайджеста
/// - ✅ Пустой массив сообщений
/// - ❌ Пробрасывание ошибок от SummaryGenerator
@Suite("DigestOrchestrator Component Tests")
struct DigestOrchestratorTests {

    @Test("Успешная генерация дайджеста")
    func successfulDigestGeneration() async throws {
        // Arrange: мокируем OpenAI response
        let response = ChatCompletionResponse(
            choices: [
                ChatCompletionResponse.Choice(
                    message: ChatCompletionResponse.Choice.Message(
                        content: """
                        **Tech News:**
                        Swift 6 released with new concurrency features

                        **Dev Updates:**
                        Xcode 16 beta available
                        """
                    )
                )
            ]
        )
        let responseData = try JSONEncoder().encode(response)

        let mockHTTPClient = MockHTTPClient()
        await mockHTTPClient.setStubResult(.success(responseData))

        let summaryGenerator = OpenAISummaryGenerator(
            apiKey: "test-api-key",
            httpClient: mockHTTPClient,
            logger: Logger(label: "test")
        )

        let orchestrator = DigestOrchestrator(
            summaryGenerator: summaryGenerator,
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
                chatId: 2,
                messageId: 2,
                content: "Xcode 16 beta",
                channelTitle: "Dev Updates",
                link: "https://t.me/dev/2"
            )
        ]

        // Act
        let digest = try await orchestrator.generateDigest(from: messages)

        // Assert
        #expect(digest.contains("Tech News"))
        #expect(digest.contains("Dev Updates"))
    }

    @Test("Пустой массив сообщений → пустой дайджест")
    func emptyMessages() async throws {
        // Arrange
        let mockHTTPClient = MockHTTPClient()
        let summaryGenerator = OpenAISummaryGenerator(
            apiKey: "test-api-key",
            httpClient: mockHTTPClient,
            logger: Logger(label: "test")
        )

        let orchestrator = DigestOrchestrator(
            summaryGenerator: summaryGenerator,
            logger: Logger(label: "test")
        )

        // Act
        let digest = try await orchestrator.generateDigest(from: [])

        // Assert
        #expect(digest.isEmpty)
    }

    @Test("OpenAI unauthorized → пробрасывает OpenAIError.unauthorized")
    func propagatesUnauthorizedError() async throws {
        // Arrange
        let mockHTTPClient = MockHTTPClient()
        let errorData = """
        {
            "error": {
                "message": "Invalid API key",
                "type": "invalid_request_error"
            }
        }
        """.data(using: .utf8)!

        await mockHTTPClient.setStubResult(.failure(HTTPError.clientError(statusCode: 401, data: errorData)))

        let summaryGenerator = OpenAISummaryGenerator(
            apiKey: "invalid-key",
            httpClient: mockHTTPClient,
            logger: Logger(label: "test")
        )

        let orchestrator = DigestOrchestrator(
            summaryGenerator: summaryGenerator,
            logger: Logger(label: "test")
        )

        let messages = [
            SourceMessage(
                chatId: 1,
                messageId: 1,
                content: "Test message",
                channelTitle: "Test",
                link: nil
            )
        ]

        // Act & Assert
        await #expect(throws: OpenAIError.unauthorized) {
            try await orchestrator.generateDigest(from: messages)
        }
    }

    @Test("OpenAI rate limited → пробрасывает OpenAIError.rateLimited")
    func propagatesRateLimitError() async throws {
        // Arrange
        let mockHTTPClient = MockHTTPClient()
        let errorData = """
        {
            "error": {
                "message": "Rate limit exceeded",
                "type": "rate_limit_exceeded"
            }
        }
        """.data(using: .utf8)!

        await mockHTTPClient.setStubResult(.failure(HTTPError.clientError(statusCode: 429, data: errorData)))

        let summaryGenerator = OpenAISummaryGenerator(
            apiKey: "test-key",
            httpClient: mockHTTPClient,
            logger: Logger(label: "test")
        )

        let orchestrator = DigestOrchestrator(
            summaryGenerator: summaryGenerator,
            logger: Logger(label: "test")
        )

        let messages = [
            SourceMessage(
                chatId: 1,
                messageId: 1,
                content: "Test message",
                channelTitle: "Test",
                link: nil
            )
        ]

        // Act & Assert
        await #expect(throws: OpenAIError.rateLimited) {
            try await orchestrator.generateDigest(from: messages)
        }
    }

    @Test("OpenAI server error → пробрасывает OpenAIError.httpError")
    func propagatesServerError() async throws {
        // Arrange
        let mockHTTPClient = MockHTTPClient()
        await mockHTTPClient.setStubResult(.failure(HTTPError.serverError(statusCode: 500, data: Data())))

        let summaryGenerator = OpenAISummaryGenerator(
            apiKey: "test-key",
            httpClient: mockHTTPClient,
            logger: Logger(label: "test")
        )

        let orchestrator = DigestOrchestrator(
            summaryGenerator: summaryGenerator,
            logger: Logger(label: "test")
        )

        let messages = [
            SourceMessage(
                chatId: 1,
                messageId: 1,
                content: "Test message",
                channelTitle: "Test",
                link: nil
            )
        ]

        // Act & Assert
        await #expect(throws: OpenAIError.httpError(statusCode: 500)) {
            try await orchestrator.generateDigest(from: messages)
        }
    }
}
