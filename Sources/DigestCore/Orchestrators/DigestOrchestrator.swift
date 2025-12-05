import Foundation
import TgClientModels
import Logging

/// Координатор pipeline для генерации дайджестов.
///
/// **Ответственность:**
/// - Координация вызовов к SummaryGenerator
/// - Логирование начала/конца/ошибок
/// - Валидация входных данных
///
/// **Будущие версии:**
/// - Интеграция с MessageSource (получение сообщений)
/// - Интеграция с BotNotifier (отправка результата)
/// - Интеграция с StateManager (сохранение состояния)
/// - Retry logic для transient errors
/// - Metrics collection
public actor DigestOrchestrator {
    private let summaryGenerator: SummaryGeneratorProtocol
    private let logger: Logger

    /// Создаёт новый orchestrator.
    ///
    /// - Parameters:
    ///   - summaryGenerator: Генератор AI-саммари
    ///   - logger: Logger для трассировки
    public init(
        summaryGenerator: SummaryGeneratorProtocol,
        logger: Logger
    ) {
        self.summaryGenerator = summaryGenerator
        self.logger = logger
    }

    /// Генерирует дайджест из массива сообщений.
    ///
    /// **v0.3.0 Scope:** Простая координация с логированием.
    ///
    /// - Parameter messages: Массив сообщений для обработки
    /// - Returns: Дайджест в формате Telegram MarkdownV2
    /// - Throws: OpenAIError или другие ошибки от SummaryGenerator
    public func generateDigest(from messages: [SourceMessage]) async throws -> String {
        logger.info("Начало генерации дайджеста", metadata: [
            "messages_count": .stringConvertible(messages.count)
        ])

        // Early return для пустого массива
        guard !messages.isEmpty else {
            logger.info("Пустой массив сообщений, возвращаем пустой дайджест")
            return ""
        }

        do {
            let digest = try await summaryGenerator.generate(messages: messages)

            logger.info("Дайджест успешно сгенерирован", metadata: [
                "digest_length": .stringConvertible(digest.count)
            ])

            return digest
        } catch {
            logger.error("Ошибка при генерации дайджеста", metadata: [
                "error": .string(error.localizedDescription)
            ])
            throw error
        }
    }
}
