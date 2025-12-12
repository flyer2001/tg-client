import Foundation
import TgClientModels
import Logging
import FoundationExtensions

/// Координатор pipeline для генерации дайджестов.
///
/// **Ответственность:**
/// - Координация вызовов к SummaryGenerator
/// - Логирование начала/конца/ошибок
/// - Валидация входных данных
/// - Retry logic для transient errors (v0.4.0)
///
/// **Будущие версии:**
/// - Интеграция с MessageSource (получение сообщений)
/// - Интеграция с BotNotifier (отправка результата)
/// - Интеграция с StateManager (сохранение состояния)
/// - Metrics collection
public actor DigestOrchestrator {
    private let summaryGenerator: SummaryGeneratorProtocol
    private let logger: Logger
    private let baseDelay: Duration

    /// Создаёт новый orchestrator.
    ///
    /// - Parameters:
    ///   - summaryGenerator: Генератор AI-саммари
    ///   - logger: Logger для трассировки
    ///   - baseDelay: Базовая задержка для exponential backoff retry (default: 1s для production)
    public init(
        summaryGenerator: SummaryGeneratorProtocol,
        logger: Logger,
        baseDelay: Duration = .seconds(1)
    ) {
        self.summaryGenerator = summaryGenerator
        self.logger = logger
        self.baseDelay = baseDelay
    }

    /// Генерирует дайджест из массива сообщений.
    ///
    /// **v0.4.0 Scope:** Координация с retry для временных ошибок OpenAI.
    ///
    /// **Retry Strategy:**
    /// - Max attempts: 3
    /// - Exponential backoff: 1s, 2s, 4s
    /// - Retry для: TimeoutError, 429 rate limit, 5xx server errors
    /// - Fail-fast для: 401 unauthorized, 400 bad request, empty response
    ///
    /// - Parameter messages: Массив сообщений для обработки
    /// - Returns: Дайджест в формате Telegram MarkdownV2
    /// - Throws: OpenAIError или другие ошибки от SummaryGenerator (после retry exhausted)
    public func generateDigest(from messages: [SourceMessage]) async throws -> String {
        // SPIKE FIX v0.4.0: Фильтруем только сообщения с текстом для дайджеста
        // (unsupported сообщения с content="" пропускаем, но они будут помечены прочитанными)
        let textMessages = messages.filter { !$0.content.isEmpty }

        logger.info("Начало генерации дайджеста", metadata: [
            "total_messages": .stringConvertible(messages.count),
            "text_messages": .stringConvertible(textMessages.count)
        ])

        // Early return если нет текстовых сообщений
        guard !textMessages.isEmpty else {
            logger.info("Нет текстовых сообщений для генерации дайджеста")
            return ""
        }

        // Retry логика с exponential backoff
        return try await withRetry(
            maxAttempts: 3,
            baseDelay: baseDelay,
            operation: {
                let digest = try await self.summaryGenerator.generate(messages: textMessages)

                self.logger.info("Дайджест успешно сгенерирован", metadata: [
                    "digest_length": .stringConvertible(digest.count)
                ])

                return digest
            },
            shouldRetry: { [logger] error, attempt in
                // Retry для timeout
                if error is TimeoutError {
                    logger.warning("Timeout при генерации дайджеста, retry", metadata: [
                        "attempt": .stringConvertible(attempt + 1)
                    ])
                    return true
                }

                // Retry для OpenAI временных ошибок
                if let openAIError = error as? OpenAIError {
                    let shouldRetry = openAIError == .rateLimited || openAIError.is5xx

                    if shouldRetry {
                        logger.warning("OpenAI временная ошибка, retry", metadata: [
                            "error": .string(openAIError.localizedDescription),
                            "attempt": .stringConvertible(attempt + 1)
                        ])
                    } else {
                        logger.error("OpenAI ошибка (не retry-able)", metadata: [
                            "error": .string(openAIError.localizedDescription)
                        ])
                    }

                    return shouldRetry
                }

                // Другие ошибки → не retry
                logger.error("Неизвестная ошибка при генерации дайджеста", metadata: [
                    "error": .string(error.localizedDescription)
                ])
                return false
            },
            logger: logger
        )
    }
}
