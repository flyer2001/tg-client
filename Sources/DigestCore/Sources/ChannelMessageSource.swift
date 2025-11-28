import Foundation
import Logging
import TGClientInterfaces
import TgClientModels

/// Источник сообщений из Telegram каналов.
///
/// **Реализация:** Stateless подход для MVP (без realtime кеша).
///
/// **Stateless дизайн:**
/// - Нет внутреннего состояния между вызовами
/// - Все данные живут только внутри `fetchUnreadMessages()`
/// - Поэтому используем `final class` вместо `actor` (нет shared mutable state)
/// - Sendable conformance через immutable properties (`let`)
///
/// **Алгоритм:**
/// 1. loadChats() в цикле (pagination до 404)
/// 2. Слушаем updates stream → получаем updateNewChat для каждого чата
/// 3. Фильтруем: только каналы (type=.supergroup(isChannel: true)) с unreadCount > 0
/// 4. getChatHistory() для каждого канала (параллельно через TaskGroup)
/// 5. Формируем SourceMessage[] с ссылками
///
/// **Отказоустойчивость:** Partial success - если один канал упал, продолжаем с остальными.
///
/// **Производительность:**
/// - `maxParallelHistoryRequests = 5` — консервативный лимит для TDLib rate limits
/// - `loadChatsPaginationDelay = 2 сек` — задержка между loadChats() вызовами
/// - `updatesCollectionTimeout = 5 сек` — ожидание после последнего loadChats()
///
/// **Post-MVP оптимизации:** См. BACKLOG.md → "Адаптивная pagination для loadChats"
///
/// **Связанная документация:**
/// - E2E сценарий: <doc:FetchUnreadMessages>
/// - Component тест: `ChannelMessageSourceTests.swift`
public final class ChannelMessageSource: MessageSourceProtocol, Sendable {
    private let tdlib: TDLibClientProtocol
    private let logger: Logger

    // Конфигурационные параметры
    private let loadChatsPaginationDelay: Duration
    private let updatesCollectionTimeout: Duration
    private let maxParallelHistoryRequests: Int
    private let maxLoadChatsBatches: Int

    /// Инициализирует ChannelMessageSource с настраиваемыми параметрами производительности.
    ///
    /// - Parameters:
    ///   - tdlib: TDLib клиент
    ///   - logger: Logger для structured logging
    ///   - loadChatsPaginationDelay: Задержка между вызовами loadChats() при pagination (default: 2 сек)
    ///   - updatesCollectionTimeout: Время ожидания updates после последнего loadChats() (default: 5 сек)
    ///   - maxParallelHistoryRequests: Лимит параллельных getChatHistory() запросов (default: 5)
    ///   - maxLoadChatsBatches: Максимальное количество batches для loadChats (защита от зависания, default: 20 = 2000 чатов)
    public init(
        tdlib: TDLibClientProtocol,
        logger: Logger,
        loadChatsPaginationDelay: Duration = .seconds(2),
        updatesCollectionTimeout: Duration = .seconds(5),
        maxParallelHistoryRequests: Int = 5,
        maxLoadChatsBatches: Int = 20
    ) {
        self.tdlib = tdlib
        self.logger = logger
        self.loadChatsPaginationDelay = loadChatsPaginationDelay
        self.updatesCollectionTimeout = updatesCollectionTimeout
        self.maxParallelHistoryRequests = maxParallelHistoryRequests
        self.maxLoadChatsBatches = maxLoadChatsBatches
    }

    public func fetchUnreadMessages() async throws -> [SourceMessage] {
        logger.info("fetchUnreadMessages() started")

        // Шаг 1: Загружаем все чаты через loadChats + updates stream
        let allChats = try await loadAllChats()

        logger.info("Loaded \(allChats.count) chats from TDLib")

        // Шаг 2: Фильтруем каналы с непрочитанными
        let unreadChannels = allChats.filter { chat in
            guard case .supergroup(_, let isChannel) = chat.chatType else {
                return false
            }
            return isChannel && chat.unreadCount > 0
        }

        logger.info("Found \(unreadChannels.count) unread channels")

        // Шаг 3: Получаем сообщения параллельно через TaskGroup
        return try await withThrowingTaskGroup(of: [SourceMessage].self) { group in
            var activeTasksCount = 0

            for channel in unreadChannels {
                // Ограничиваем параллелизм
                while activeTasksCount >= maxParallelHistoryRequests {
                    // Ждём завершения хотя бы одной задачи
                    _ = try await group.next()
                    activeTasksCount -= 1
                }

                // Добавляем новую задачу
                group.addTask {
                    do {
                        let messagesResponse = try await self.tdlib.getChatHistory(
                            chatId: channel.id,
                            fromMessageId: 0,
                            offset: 0,
                            limit: 100
                        )

                        // Конвертируем TDLib Message → SourceMessage
                        return messagesResponse.messages.compactMap { message -> SourceMessage? in
                            guard case .text(let formattedText) = message.content else {
                                return nil  // Пропускаем неподдерживаемые типы
                            }

                            return SourceMessage(
                                chatId: message.chatId,
                                messageId: message.id,
                                content: formattedText.text,
                                channelTitle: channel.title,
                                link: nil  // TODO: формирование ссылок (username из Supergroup info)
                            )
                        }
                    } catch {
                        // Partial success: логируем ошибку, продолжаем с остальными
                        self.logger.error("Failed to fetch history for chat \(channel.id): \(error)")
                        return []
                    }
                }
                activeTasksCount += 1
            }

            // Собираем результаты
            var allMessages: [SourceMessage] = []
            while let channelMessages = try await group.next() {
                allMessages.append(contentsOf: channelMessages)
            }

            self.logger.info("Fetched \(allMessages.count) unread messages from \(unreadChannels.count) channels")
            return allMessages
        }
    }

    public func markAsRead(messages: [SourceMessage]) async throws {
        // TODO: Реализовать viewMessages группировкой по chatId
        fatalError("Not implemented yet - RED phase")
    }

    // MARK: - Private Helpers

    /// Загружает все чаты через loadChats() + updates stream.
    ///
    /// **Алгоритм:**
    /// 1. Подписываемся на updates stream (Task 1)
    /// 2. Вызываем loadChats() (Task 2)
    /// 3. Ждём `updatesCollectionTimeout` после loadChats()
    /// 4. Собираем все updateNewChat
    ///
    /// - Returns: Массив ChatResponse из updateNewChat
    private func loadAllChats() async throws -> [ChatResponse] {
        let collector = ChatCollector()

        // Начинаем слушать updates в фоне (ПЕРЕД loadChats)
        let collectionTask = Task {
            for await update in self.tdlib.updates {
                if case .newChat(let chat) = update {
                    await collector.add(chat)
                }
            }
        }

        // Pagination loop с защитой от зависания
        var loadedBatches = 0

        while loadedBatches < maxLoadChatsBatches {
            do {
                logger.info("loadChats batch \(loadedBatches + 1)...")
                _ = try await tdlib.loadChats(chatList: .main, limit: 100)
                loadedBatches += 1
                logger.info("loadChats batch \(loadedBatches) completed")

                // Ждём перед следующим вызовом
                try await Task.sleep(for: loadChatsPaginationDelay)

            } catch let error as TDLibErrorResponse where error.isAllChatsLoaded {
                // 404 → все чаты загружены (успех)
                logger.info("All chats loaded after \(loadedBatches) batches")
                break

            } catch {
                // Любая другая ошибка → логируем, НО ПРОДОЛЖАЕМ работу (partial success)
                logger.error("loadChats failed at batch \(loadedBatches): \(error)")
                break
            }
        }

        if loadedBatches >= maxLoadChatsBatches {
            logger.warning("Reached max batches limit (\(maxLoadChatsBatches)), stopping pagination")
        }

        // Ждём финальные updates
        try await Task.sleep(for: updatesCollectionTimeout)

        // Останавливаем сбор
        collectionTask.cancel()

        let chats = await collector.getAll()
        logger.info("Collected \(chats.count) chats from \(loadedBatches) batches")

        return chats
    }
}

// MARK: - Helper Actor

/// Thread-safe accumulator для сбора чатов из updates stream.
///
/// Используется в `loadAllChats()` для безопасной мутации из разных Task'ов.
private actor ChatCollector {
    private var chats: [ChatResponse] = []

    func add(_ chat: ChatResponse) {
        chats.append(chat)
    }

    func getAll() -> [ChatResponse] {
        return chats
    }
}
