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
                        // Вычисляем параметры getChatHistory в зависимости от lastReadInboxMessageId
                        let (fromMessageId, offset, limit): (Int64, Int32, Int32) = if channel.lastReadInboxMessageId == 0 {
                            // Канал никогда не читали → берём последние N сообщений
                            (0, 0, min(channel.unreadCount, Int32(self.maxChatHistoryLimit)))
                        } else {
                            // Берём N сообщений ПОСЛЕ lastRead
                            (channel.lastReadInboxMessageId, -min(channel.unreadCount, Int32(self.maxChatHistoryLimit) - 1), min(channel.unreadCount, Int32(self.maxChatHistoryLimit)))
                        }

                        let messagesResponse = try await self.tdlib.getChatHistory(
                            chatId: channel.id,
                            fromMessageId: fromMessageId,
                            offset: offset,
                            limit: limit
                        )

                        // Конвертируем TDLib Message → SourceMessage
                        let sourceMessages = messagesResponse.messages.compactMap { message -> SourceMessage? in
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
            return allMessages
        }
    }

    public func markAsRead(messages: [SourceMessage]) async throws {
        // TODO: Реализовать viewMessages группировкой по chatId
        fatalError("Not implemented yet - RED phase")
    }

    // MARK: - Public API: per-chat fetch (для VK Bot Bridge меню)

    /// Возвращает список ВСЕХ непрочитанных чатов всех типов (каналы, группы, ЛС).
    ///
    /// Не подгружает сами сообщения — это для построения меню. Для получения текста
    /// конкретного чата используй `fetchMessages(for:)`.
    ///
    /// **Фильтры:**
    /// - Архивные чаты исключаются (как и в `fetchUnreadMessages()`)
    /// - Secret чаты (E2E) пропускаются
    /// - Только чаты с unreadCount > 0
    public func fetchUnreadChats() async throws -> [UnreadChatInfo] {
        logger.info("fetchUnreadChats() started")
        let allChats = try await loadAllChats()

        let unread = allChats.compactMap { chat -> UnreadChatInfo? in
            guard chat.unreadCount > 0 else { return nil }
            guard let kind = Self.classify(chat.chatType) else { return nil }
            return UnreadChatInfo(
                id: chat.id,
                title: chat.title,
                kind: kind,
                unreadCount: chat.unreadCount,
                lastReadInboxMessageId: chat.lastReadInboxMessageId
            )
        }

        logger.info("Found \(unread.count) unread chats (channels: \(unread.filter { $0.kind == .channel }.count), groups: \(unread.filter { $0.kind == .group }.count), dm: \(unread.filter { $0.kind == .dm }.count))")
        return unread
    }

    /// Подгружает текстовые сообщения для одного чата из меню.
    ///
    /// **Стратегия:** всегда берём последние N сообщений `getChatHistory(fromMessageId:0, offset:0, limit:N)`.
    /// Это самый предсказуемый формат TDLib — без манипуляций offset'ами.
    ///
    /// **N зависит от типа чата:**
    /// - Канал: `unreadCount` (дайджест за период)
    /// - Группа/ЛС: `max(unreadCount, 30)` — даём контекст разговора, не только непрочитанные
    /// - Cap: `maxChatHistoryLimit` (default 100)
    ///
    /// **Порядок:** TDLib возвращает newest-first, мы реверсируем — old→new как в Telegram чате.
    public func fetchMessages(for chat: UnreadChatInfo) async throws -> [SourceMessage] {
        let target: Int
        switch chat.kind {
        case .channel:
            target = max(Int(chat.unreadCount), 1)
        case .group, .dm:
            target = max(Int(chat.unreadCount), 30)
        }
        return try await fetchLastMessages(for: chat, count: target)
    }

    /// Подгружает последние `count` сообщений чата (включая прочитанные).
    ///
    /// **TDLib quirk:** `getChatHistory(from=0, offset=0, limit=N)` берёт только из локального
    /// кэша. Если в кэше меньше N — TDLib НЕ дотягивает с сервера автоматически.
    /// Стандартный обход: итеративные запросы с `from=<id_самого_старого_из_прошлого_ответа>`.
    /// На таком запросе TDLib понимает "нужны старее" и тянет с сервера.
    ///
    /// Безопасный лимит итераций — 5, чтобы случайно не зациклиться.
    public func fetchLastMessages(for chat: UnreadChatInfo, count: Int) async throws -> [SourceMessage] {
        let target = min(max(count, 1), maxChatHistoryLimit)
        let perRequest = Int32(target)

        logger.info("fetchLastMessages: requesting chat=\(chat.id) (\(chat.title)) target=\(target)")

        var collected: [Message] = []
        var seenIds = Set<Int64>()
        var fromMessageId: Int64 = 0
        let maxAttempts = 5

        for attempt in 1...maxAttempts {
            let resp = try await tdlib.getChatHistory(
                chatId: chat.id,
                fromMessageId: fromMessageId,
                offset: 0,
                limit: perRequest
            )
            if resp.messages.isEmpty {
                logger.info("fetchLastMessages: empty response on attempt \(attempt), stopping")
                break
            }
            var newCount = 0
            for m in resp.messages where !seenIds.contains(m.id) {
                seenIds.insert(m.id)
                collected.append(m)
                newCount += 1
            }
            logger.info("fetchLastMessages: attempt \(attempt) → \(resp.messages.count) raw, \(newCount) new (collected: \(collected.count)/\(target))")
            if newCount == 0 { break }
            if collected.count >= target { break }
            // newest-first → самый старый = последний в массиве
            fromMessageId = resp.messages.last?.id ?? 0
        }

        let textCount = collected.filter { if case .text = $0.content { return true } else { return false } }.count
        logger.info("fetchLastMessages: total collected \(collected.count), text \(textCount), non-text \(collected.count - textCount)")

        // Берём ровно target (не больше) и реверсируем для отображения oldest→newest
        let trimmed = Array(collected.prefix(target))
        return trimmed.reversed().compactMap { message -> SourceMessage? in
            guard case .text(let formattedText) = message.content else {
                return nil
            }
            return SourceMessage(
                chatId: message.chatId,
                messageId: message.id,
                content: formattedText.text,
                channelTitle: chat.title,
                link: nil
            )
        }
    }

    private static func classify(_ type: ChatType) -> ChatKind? {
        switch type {
        case .supergroup(_, let isChannel):
            return isChannel ? .channel : .group
        case .basicGroup:
            return .group
        case .private:
            return .dm
        case .secret:
            return nil
        }
    }

    // MARK: - Private Helpers

    /// Загружает все чаты через loadChats() (для pull данных с сервера) + getChats() (snapshot in-memory).
    ///
    /// **Почему не updateNewChat events:** TDLib шлёт `updateNewChat` только при первой
    /// подгрузке чата (initial load или новый чат). В long-running сервисе после первого
    /// `/digest` events уже не приходят — повторный `loadChats` сразу возвращает 404
    /// "All chats loaded", а наш collector локальный → пустой результат.
    ///
    /// **Решение:** `getChats(...)` возвращает chat_ids уже подгруженные TDLib в память.
    /// Затем для каждого id — `getChat(id)` (cached, быстрый).
    ///
    /// **Алгоритм:**
    /// 1. `loadChats` в цикле до 404 — гарантирует pull свежих данных с сервера
    /// 2. `getChats` — snapshot всех известных chat_ids
    /// 3. Параллельный `getChat(id)` для каждого (с лимитом)
    /// 4. Фильтрация archive (positions содержит main или folder)
    private func loadAllChats() async throws -> [ChatResponse] {
        // Шаг 1: pull данных с сервера (loadChats до 404 — на свежем cache отрабатывает быстро)
        var loadedBatches = 0
        while loadedBatches < maxLoadChatsBatches {
            do {
                _ = try await tdlib.loadChats(chatList: .main, limit: 100)
                loadedBatches += 1
                if loadedBatches < maxLoadChatsBatches {
                    try await Task.sleep(for: loadChatsPaginationDelay)
                }
            } catch let error as TDLibErrorResponse where error.isAllChatsLoaded {
                logger.info("loadChats: all chats loaded after \(loadedBatches) batches")
                break
            } catch {
                logger.warning("loadChats failed at batch \(loadedBatches): \(error)")
                break
            }
        }
        if loadedBatches >= maxLoadChatsBatches {
            logger.warning("Reached max batches limit (\(maxLoadChatsBatches)), stopping pagination")
        }

        // Шаг 2: snapshot из in-memory cache (без зависимости от updateNewChat)
        let chatsResp = try await tdlib.getChats(chatList: .main, limit: 1000)
        logger.info("getChats returned \(chatsResp.chatIds.count) chat ids (totalCount: \(chatsResp.totalCount))")

        // Шаг 3: getChat(id) для каждого, параллельно с лимитом
        var allChats: [ChatResponse] = []
        try await withThrowingTaskGroup(of: ChatResponse?.self) { group in
            var activeTasks = 0
            for chatId in chatsResp.chatIds {
                while activeTasks >= maxParallelHistoryRequests {
                    if let result = try await group.next() {
                        if let chat = result { allChats.append(chat) }
                        activeTasks -= 1
                    }
                }
                group.addTask {
                    do {
                        return try await self.tdlib.getChat(chatId: chatId)
                    } catch {
                        self.logger.warning("getChat(\(chatId)) failed: \(error)")
                        return nil
                    }
                }
                activeTasks += 1
            }
            while let result = try await group.next() {
                if let chat = result { allChats.append(chat) }
            }
        }
        logger.info("Hydrated \(allChats.count) ChatResponse from \(chatsResp.chatIds.count) ids")

        // Шаг 4: фильтрация — оставляем только main или folder (отсекаем archive-only)
        let relevantChats = allChats.filter { chat in
            let hasFolder = chat.positions.contains { if case .folder = $0.list { return true } else { return false } }
            let hasMain = chat.positions.contains { $0.list == .main }
            return hasFolder || hasMain
        }
        logger.info("Filtered to \(relevantChats.count) relevant chats (removed \(allChats.count - relevantChats.count) archive-only)")

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
