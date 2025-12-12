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
    private let maxChatHistoryLimit: Int

    /// Инициализирует ChannelMessageSource с настраиваемыми параметрами производительности.
    ///
    /// - Parameters:
    ///   - tdlib: TDLib клиент
    ///   - logger: Logger для structured logging
    ///   - loadChatsPaginationDelay: Задержка между вызовами loadChats() при pagination (default: 2 сек)
    ///   - updatesCollectionTimeout: Время ожидания updates после последнего loadChats() (default: 5 сек)
    ///   - maxParallelHistoryRequests: Лимит параллельных getChatHistory() запросов (default: 5)
    ///   - maxLoadChatsBatches: Максимальное количество batches для loadChats (защита от зависания, default: 20 = 2000 чатов)
    ///   - maxChatHistoryLimit: Максимальное количество сообщений для getChatHistory (default: 100)
    public init(
        tdlib: TDLibClientProtocol,
        logger: Logger,
        loadChatsPaginationDelay: Duration = .seconds(2),
        updatesCollectionTimeout: Duration = .seconds(5),
        maxParallelHistoryRequests: Int = 5,
        maxLoadChatsBatches: Int = 20,
        maxChatHistoryLimit: Int = 100
    ) {
        self.tdlib = tdlib
        self.logger = logger
        self.loadChatsPaginationDelay = loadChatsPaginationDelay
        self.updatesCollectionTimeout = updatesCollectionTimeout
        self.maxParallelHistoryRequests = maxParallelHistoryRequests
        self.maxLoadChatsBatches = maxLoadChatsBatches
        self.maxChatHistoryLimit = maxChatHistoryLimit
    }

    public func fetchUnreadMessages() async throws -> [SourceMessage] {
        logger.info("fetchUnreadMessages() started")

        // Шаг 1: Загружаем все чаты через loadChats + updates stream
        let allChats = try await loadAllChats()

        logger.info("Loaded \(allChats.count) chats from TDLib")

        // Шаг 2: Фильтруем каналы с непрочитанными
        logger.info("🔍 Filtering unread channels from \(allChats.count) chats...")

        // DEBUG: Анализ типов чатов
        let chatsByType = Dictionary(grouping: allChats, by: { chat -> String in
            switch chat.chatType {
            case .supergroup(_, let isChannel):
                return isChannel ? "channel" : "supergroup"
            case .basicGroup:
                return "basicGroup"
            case .private:
                return "private"
            case .secret:
                return "secret"
            }
        })

        for (type, chats) in chatsByType {
            let unreadCount = chats.filter { $0.unreadCount > 0 }.count
            logger.info("   - \(type): \(chats.count) total, \(unreadCount) with unread")
        }

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
                        // FIX v0.4.0: ВСЕГДА используем fromMessageId=0 для получения последних N сообщений
                        // Причина: fromMessageId=lastRead с offset=-N возвращает УЖЕ прочитанные сообщения
                        // после того как lastRead обновился через viewMessages
                        let limit = min(channel.unreadCount, Int32(self.maxChatHistoryLimit))
                        let (fromMessageId, offset): (Int64, Int32) = (0, 0)

                        // 🔍 ЛОГИРОВАНИЕ: запрос getChatHistory
                        self.logger.info("→ getChatHistory", metadata: [
                            "chatId": .stringConvertible(channel.id),
                            "title": .string(channel.title),
                            "unreadCount": .stringConvertible(channel.unreadCount),
                            "lastRead": .stringConvertible(channel.lastReadInboxMessageId),
                            "fromMessageId": .stringConvertible(fromMessageId),
                            "offset": .stringConvertible(offset),
                            "limit": .stringConvertible(limit)
                        ])

                        let messagesResponse = try await self.tdlib.getChatHistory(
                            chatId: channel.id,
                            fromMessageId: fromMessageId,
                            offset: offset,
                            limit: limit
                        )

                        // 🔍 ЛОГИРОВАНИЕ: ответ getChatHistory
                        self.logger.info("← getChatHistory", metadata: [
                            "chatId": .stringConvertible(channel.id),
                            "totalMessages": .stringConvertible(messagesResponse.messages.count),
                            "messageIds": .string(messagesResponse.messages.map { String($0.id) }.joined(separator: ", "))
                        ])

                        // 🔍 ЛОГИРОВАНИЕ: типы контента для ВСЕХ сообщений
                        let contentTypes = messagesResponse.messages.map { msg -> String in
                            switch msg.content {
                            case .text: return "text"
                            case .photo: return "photo"
                            case .video: return "video"
                            case .voice: return "voice"
                            case .audio: return "audio"
                            case .unsupported: return "unsupported"
                            }
                        }.joined(separator: ", ")
                        self.logger.info("📦 Content types", metadata: [
                            "chatId": .stringConvertible(channel.id),
                            "types": .string(contentTypes)
                        ])

                        // Конвертируем TDLib Message → SourceMessage
                        // SPIKE FIX v0.4.0: Возвращаем ВСЕ сообщения (включая unsupported) для viewMessages
                        let sourceMessages = messagesResponse.messages.map { message -> SourceMessage in
                            // Извлекаем текст из text или caption (photo/video/voice/audio)
                            let content: String
                            switch message.content {
                            case .text(let formattedText):
                                content = formattedText.text

                            case .photo(let caption),
                                 .video(let caption),
                                 .voice(let caption),
                                 .audio(let caption):
                                // Извлекаем caption если есть, иначе пустая строка
                                content = caption?.text ?? ""

                            case .unsupported:
                                // Unsupported: пустой content (для viewMessages, но НЕ для дайджеста)
                                self.logger.debug("Unsupported message will be marked as read but skipped in digest", metadata: [
                                    "chatId": .stringConvertible(channel.id),
                                    "messageId": .stringConvertible(message.id)
                                ])
                                content = ""
                            }

                            return SourceMessage(
                                chatId: message.chatId,
                                messageId: message.id,
                                content: content,
                                channelTitle: channel.title,
                                link: nil  // TODO: формирование ссылок (username из Supergroup info)
                            )
                        }

                        return sourceMessages
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

            // 🔍 ДЕТАЛЬНОЕ ЛОГИРОВАНИЕ: какие сообщения получили
            let messagesByChannel = Dictionary(grouping: allMessages) { $0.channelTitle }
            logger.info("📨 Messages by channel:")
            for (channelTitle, messages) in messagesByChannel.sorted(by: { $0.value.count > $1.value.count }) {
                let chatId = messages.first?.chatId ?? 0
                logger.info("  [\(chatId)] \(channelTitle): \(messages.count) messages")
            }

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
                switch update {
                case .newChat(let chat):
                    await collector.add(chat)

                case .chatPosition(let chatId, let position):
                    await collector.updatePosition(chatId: chatId, position: position)

                default:
                    break
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

        let allChats = await collector.getAll()
        logger.info("Collected \(allChats.count) chats from \(loadedBatches) batches")

        // Фильтруем каналы для дайджеста
        // ЛОГИКА: Включаем каналы из .main и .folder, исключаем только .archive (без folder/main)
        // Приоритет: folder > archive (чат в folder + archive → ВКЛЮЧИТЬ)
        let relevantChats = allChats.filter { chat in
            let hasFolder = chat.positions.contains { if case .folder = $0.list { return true } else { return false } }
            let hasMain = chat.positions.contains { $0.list == .main }
            return hasFolder || hasMain
        }

        logger.info("Filtered to \(relevantChats.count) relevant chats (removed \(allChats.count - relevantChats.count) archive-only)")

        // 🔍 ДЕТАЛЬНОЕ ЛОГИРОВАНИЕ: какие каналы нашли
        let channels = relevantChats.filter {
            if case .supergroup(_, isChannel: true) = $0.chatType { return true }
            return false
        }
        let channelsWithUnread = channels.filter { $0.unreadCount > 0 }

        logger.info("📊 Channel breakdown:", metadata: [
            "total_channels": .stringConvertible(channels.count),
            "channels_with_unread": .stringConvertible(channelsWithUnread.count),
            "total_unread_count": .stringConvertible(channelsWithUnread.reduce(0) { $0 + $1.unreadCount })
        ])

        // Логируем топ-10 каналов с непрочитанными
        if !channelsWithUnread.isEmpty {
            let top10 = channelsWithUnread.sorted { $0.unreadCount > $1.unreadCount }.prefix(10)
            logger.info("📋 Top channels with unread messages:")
            for (idx, chat) in top10.enumerated() {
                logger.info("  \(idx + 1). [\(chat.id)] \(chat.title): \(chat.unreadCount) unread")
            }
        }

        // 🔍 ДЕТАЛЬНОЕ ЛОГИРОВАНИЕ: ВСЕ каналы (isChannel: true) для отладки фильтрации
        logger.info("🔍 Детальный список ВСЕХ каналов (isChannel: true):")
        let sortedChannels = channels.sorted { $0.title < $1.title }
        for channel in sortedChannels {
            let positionsStr = channel.positions.map { pos in
                switch pos.list {
                case .main: return "main"
                case .archive: return "archive"
                case .folder(let id): return "folder(\(id))"
                }
            }.joined(separator: ", ")

            logger.info("  [\(channel.id)] \(channel.title)", metadata: [
                "unread": .stringConvertible(channel.unreadCount),
                "positions": .string(positionsStr.isEmpty ? "none" : positionsStr),
                "lastRead": .stringConvertible(channel.lastReadInboxMessageId)
            ])
        }

        return relevantChats
    }
}

// MARK: - Helper Actor

/// Thread-safe accumulator для сбора чатов из updates stream.
///
/// Используется в `loadAllChats()` для безопасной мутации из разных Task'ов.
private actor ChatCollector {
    private var chats: [Int64: ChatResponse] = [:]

    func add(_ chat: ChatResponse) {
        chats[chat.id] = chat
    }

    func updatePosition(chatId: Int64, position: ChatPosition) {
        guard let chat = chats[chatId] else { return }

        // Удаляем старую позицию для этого списка (если есть)
        var updatedPositions = chat.positions.filter { $0.list != position.list }

        // Добавляем новую позицию
        updatedPositions.append(position)

        // Обновляем чат с новыми позициями
        chats[chatId] = ChatResponse(
            id: chat.id,
            type: chat.chatType,
            title: chat.title,
            unreadCount: chat.unreadCount,
            lastReadInboxMessageId: chat.lastReadInboxMessageId,
            positions: updatedPositions
        )
    }

    func getAll() -> [ChatResponse] {
        return Array(chats.values)
    }
}
