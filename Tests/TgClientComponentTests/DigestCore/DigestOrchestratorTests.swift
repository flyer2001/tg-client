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

    @Test("OpenAI unauthorized → fail-fast БЕЗ retry")
    func failFastOnUnauthorizedError() async throws {
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

        // Act & Assert: 401 → fail-fast, НЕ retry
        await #expect(throws: OpenAIError.unauthorized) {
            try await orchestrator.generateDigest(from: messages)
        }

        // Проверяем что был только 1 вызов (НЕТ retry)
        #expect(await mockHTTPClient.callCount == 1)
    }

    // MARK: - Retry Tests

    @Test("Retry: 500 на 1й попытке → success на 2й")
    func retryServerErrorThenSuccess() async throws {
        // Arrange: 500 → success
        let mockHTTPClient = MockHTTPClient()
        let successResponse = ChatCompletionResponse(
            choices: [
                ChatCompletionResponse.Choice(
                    message: ChatCompletionResponse.Choice.Message(
                        content: "Digest content"
                    )
                )
            ]
        )
        let successData = try JSONEncoder().encode(successResponse)

        await mockHTTPClient.setStubQueue([
            .failure(HTTPError.serverError(statusCode: 500, data: Data())),
            .success(successData)
        ])

        let summaryGenerator = OpenAISummaryGenerator(
            apiKey: "test-key",
            httpClient: mockHTTPClient,
            logger: Logger(label: "test")
        )

        let orchestrator = DigestOrchestrator(
            summaryGenerator: summaryGenerator,
            logger: Logger(label: "test"),
            baseDelay: .milliseconds(100)  // Быстрые тесты
        )

        let messages = [
            SourceMessage(
                chatId: 1,
                messageId: 1,
                content: "Test",
                channelTitle: "Test",
                link: nil
            )
        ]

        // Act
        let digest = try await orchestrator.generateDigest(from: messages)

        // Assert
        #expect(digest == "Digest content")
        #expect(await mockHTTPClient.callCount == 2)  // 1 fail + 1 success
    }

    @Test("Retry: 429 rate limit → success на 2й")
    func retryRateLimitThenSuccess() async throws {
        // Arrange: 429 → success
        let mockHTTPClient = MockHTTPClient()
        let successResponse = ChatCompletionResponse(
            choices: [
                ChatCompletionResponse.Choice(
                    message: ChatCompletionResponse.Choice.Message(
                        content: "Digest content"
                    )
                )
            ]
        )
        let successData = try JSONEncoder().encode(successResponse)
        let rateLimitError = """
        {"error": {"message": "Rate limit exceeded", "type": "rate_limit_error"}}
        """.data(using: .utf8)!

        await mockHTTPClient.setStubQueue([
            .failure(HTTPError.clientError(statusCode: 429, data: rateLimitError)),
            .success(successData)
        ])

        let summaryGenerator = OpenAISummaryGenerator(
            apiKey: "test-key",
            httpClient: mockHTTPClient,
            logger: Logger(label: "test")
        )

        let orchestrator = DigestOrchestrator(
            summaryGenerator: summaryGenerator,
            logger: Logger(label: "test"),
            baseDelay: .milliseconds(100)
        )

        let messages = [
            SourceMessage(
                chatId: 1,
                messageId: 1,
                content: "Test",
                channelTitle: "Test",
                link: nil
            )
        ]

        // Act
        let digest = try await orchestrator.generateDigest(from: messages)

        // Assert
        #expect(digest == "Digest content")
        #expect(await mockHTTPClient.callCount == 2)
    }

    @Test("Retry: 503 → 502 → success на 3й")
    func retryMultipleServerErrorsThenSuccess() async throws {
        // Arrange: 503 → 502 → success
        let mockHTTPClient = MockHTTPClient()
        let successResponse = ChatCompletionResponse(
            choices: [
                ChatCompletionResponse.Choice(
                    message: ChatCompletionResponse.Choice.Message(
                        content: "Digest content"
                    )
                )
            ]
        )
        let successData = try JSONEncoder().encode(successResponse)

        await mockHTTPClient.setStubQueue([
            .failure(HTTPError.serverError(statusCode: 503, data: Data())),
            .failure(HTTPError.serverError(statusCode: 502, data: Data())),
            .success(successData)
        ])

        let summaryGenerator = OpenAISummaryGenerator(
            apiKey: "test-key",
            httpClient: mockHTTPClient,
            logger: Logger(label: "test")
        )

        let orchestrator = DigestOrchestrator(
            summaryGenerator: summaryGenerator,
            logger: Logger(label: "test"),
            baseDelay: .milliseconds(100)
        )

        let messages = [
            SourceMessage(
                chatId: 1,
                messageId: 1,
                content: "Test",
                channelTitle: "Test",
                link: nil
            )
        ]

        // Act
        let digest = try await orchestrator.generateDigest(from: messages)

        // Assert
        #expect(digest == "Digest content")
        #expect(await mockHTTPClient.callCount == 3)  // 2 fails + 1 success
    }

    @Test("Retry: 400 bad request → fail-fast БЕЗ retry")
    func failFastOn400Error() async throws {
        // Arrange: 400 → НЕ retry
        let mockHTTPClient = MockHTTPClient()
        let badRequestError = """
        {"error": {"message": "Invalid request", "type": "invalid_request_error"}}
        """.data(using: .utf8)!

        await mockHTTPClient.setStubResult(.failure(HTTPError.clientError(statusCode: 400, data: badRequestError)))

        let summaryGenerator = OpenAISummaryGenerator(
            apiKey: "test-key",
            httpClient: mockHTTPClient,
            logger: Logger(label: "test")
        )

        let orchestrator = DigestOrchestrator(
            summaryGenerator: summaryGenerator,
            logger: Logger(label: "test"),
            baseDelay: .milliseconds(100)
        )

        let messages = [
            SourceMessage(
                chatId: 1,
                messageId: 1,
                content: "Test",
                channelTitle: "Test",
                link: nil
            )
        ]

        // Act & Assert
        await #expect(throws: OpenAIError.httpError(statusCode: 400)) {
            try await orchestrator.generateDigest(from: messages)
        }

        // Проверяем что был только 1 вызов (НЕТ retry для 400)
        #expect(await mockHTTPClient.callCount == 1)
    }

    @Test("Retry: 429 → 429 → 429 → exhausted")
    func rateLimitExhaustsRetries() async throws {
        // Arrange: 3 раза 429
        let mockHTTPClient = MockHTTPClient()
        let rateLimitError = """
        {"error": {"message": "Rate limit exceeded", "type": "rate_limit_error"}}
        """.data(using: .utf8)!

        await mockHTTPClient.setStubQueue([
            .failure(HTTPError.clientError(statusCode: 429, data: rateLimitError)),
            .failure(HTTPError.clientError(statusCode: 429, data: rateLimitError)),
            .failure(HTTPError.clientError(statusCode: 429, data: rateLimitError))
        ])

        let summaryGenerator = OpenAISummaryGenerator(
            apiKey: "test-key",
            httpClient: mockHTTPClient,
            logger: Logger(label: "test")
        )

        let orchestrator = DigestOrchestrator(
            summaryGenerator: summaryGenerator,
            logger: Logger(label: "test"),
            baseDelay: .milliseconds(100)
        )

        let messages = [
            SourceMessage(
                chatId: 1,
                messageId: 1,
                content: "Test",
                channelTitle: "Test",
                link: nil
            )
        ]

        // Act & Assert
        await #expect(throws: OpenAIError.rateLimited) {
            try await orchestrator.generateDigest(from: messages)
        }

        // Проверяем что было 3 попытки
        #expect(await mockHTTPClient.callCount == 3)
    }

    @Test("Retry: 500 → 500 → 500 → exhausted")
    func serverErrorExhaustsRetries() async throws {
        // Arrange: все 3 попытки → 500 error
        let mockHTTPClient = MockHTTPClient()
        await mockHTTPClient.setStubQueue([
            .failure(HTTPError.serverError(statusCode: 500, data: Data())),
            .failure(HTTPError.serverError(statusCode: 500, data: Data())),
            .failure(HTTPError.serverError(statusCode: 500, data: Data()))
        ])

        let summaryGenerator = OpenAISummaryGenerator(
            apiKey: "test-key",
            httpClient: mockHTTPClient,
            logger: Logger(label: "test")
        )

        let orchestrator = DigestOrchestrator(
            summaryGenerator: summaryGenerator,
            logger: Logger(label: "test"),
            baseDelay: .milliseconds(100)
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

        // Act & Assert: все 3 retry exhausted
        await #expect(throws: OpenAIError.httpError(statusCode: 500)) {
            try await orchestrator.generateDigest(from: messages)
        }

        // Проверяем что было 3 попытки
        #expect(await mockHTTPClient.callCount == 3)
    }
}
