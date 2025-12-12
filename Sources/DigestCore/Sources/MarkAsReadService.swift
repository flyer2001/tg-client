import TgClientModels
import TGClientInterfaces
import Foundation
import Logging

// MARK: - MarkAsReadService

/// Сервис для отметки сообщений как прочитанных.
///
/// **Concurrency:**
/// - Parallel mark-as-read для N чатов (TaskGroup)
/// - Concurrency limit: `maxParallelRequests` (по умолчанию 20)
/// - Partial failure handling: продолжаем при ошибках
///
/// **Связанная документация:**
/// - E2E сценарий: <doc:MarkAsRead>
/// - Component тест: `MarkAsReadFlowTests.swift`
/// - RFC: MVP.md § v0.4.0
public actor MarkAsReadService {
    private let tdlib: TDLibClientProtocol
    private let logger: Logger
    private let maxParallelRequests: Int
    private let timeout: Duration

    public init(
        tdlib: TDLibClientProtocol,
        logger: Logger,
        maxParallelRequests: Int = 20,
        timeout: Duration = .seconds(2)
    ) {
        self.tdlib = tdlib
        self.logger = logger
        self.maxParallelRequests = maxParallelRequests
        self.timeout = timeout
    }

    /// Отмечает сообщения как прочитанные для указанных чатов.
    ///
    /// - Parameter messages: Словарь [chatId: [messageIds]]
    /// - Returns: Словарь [chatId: Result<Void, Error>] — успех/ошибка для каждого чата
    public func markAsRead(_ messages: [Int64: [Int64]]) async -> [Int64: Result<Void, Error>] {
        guard !messages.isEmpty else {
            return [:]
        }

        logger.info("Starting mark-as-read for \(messages.count) chats")

        return await withTaskGroup(of: (Int64, Result<Void, Error>).self) { group in
            var activeTasksCount = 0
            var results: [Int64: Result<Void, Error>] = [:]

            for (chatId, messageIds) in messages {
                // Ограничиваем параллелизм
                while activeTasksCount >= maxParallelRequests {
                    if let (completedChatId, result) = await group.next() {
                        results[completedChatId] = result
                        activeTasksCount -= 1
                    }
                }

                // Добавляем новую задачу
                group.addTask {
                    await self.logStart(chatId: chatId, messageIds: messageIds)

                    do {
                        // SPIKE TEST VARIANT B: viewMessages с максимальным messageId
                        // Из документации: "If you want to read ALL messages, pass chat.last_message.id"
                        // Используем max(messageIds) как последнее сообщение из полученных
                        // Источник: https://github.com/tdlib/td/issues/46

                        guard let maxMessageId = messageIds.max() else {
                            self.logger.warning("Empty messageIds for chat \(chatId), skipping")
                            return (chatId, .success(()))
                        }

                        // Помечаем ВСЕ сообщения до maxMessageId прочитанными
                        self.logger.debug("Marking ALL messages as read up to maxMessageId=\(maxMessageId)")
                        try await self.tdlib.viewMessages(
                            chatId: chatId,
                            messageIds: [maxMessageId],
                            forceRead: true
                        )

                        await self.logSuccess(chatId: chatId, messageCount: messageIds.count)
                        return (chatId, .success(()))

                    } catch {
                        await self.logError(chatId: chatId, error: error)
                        return (chatId, .failure(error))
                    }
                }
                activeTasksCount += 1
            }

            // Собираем оставшиеся результаты
            while let (chatId, result) = await group.next() {
                results[chatId] = result
            }

            self.logSummary(results: results)
            return results
        }
    }

    // MARK: - Private Logging

    private func logStart(chatId: Int64, messageIds: [Int64]) {
        logger.info("→ viewMessages with max(messageIds) (chatId: \(chatId), \(messageIds.count) messages to mark)")
    }

    private func logSuccess(chatId: Int64, messageCount: Int) {
        logger.info("✅ Chat \(chatId) marked as read (\(messageCount) messages)")
    }

    private func logError(chatId: Int64, error: Error) {
        logger.error("❌ Failed to mark chat \(chatId) as read: \(error)")
    }

    private func logSummary(results: [Int64: Result<Void, Error>]) {
        let successCount = results.values.filter {
            if case .success = $0 { return true }
            return false
        }.count

        logger.info("Marked \(successCount)/\(results.count) chats as read")
    }
}
