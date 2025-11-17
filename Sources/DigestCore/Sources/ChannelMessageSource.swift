import Foundation
import Logging
import TDLibAdapter

/// Источник сообщений из Telegram каналов.
///
/// **Реализация:** Stateless подход для MVP (без realtime кеша).
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
/// **Связанная документация:**
/// - E2E сценарий: <doc:FetchUnreadMessages>
/// - Component тест: `ChannelMessageSourceTests.swift`
public actor ChannelMessageSource: MessageSourceProtocol {
    private let tdlib: TDLibClientProtocol
    private let logger: Logger

    public init(tdlib: TDLibClientProtocol, logger: Logger) {
        self.tdlib = tdlib
        self.logger = logger
    }

    public func fetchUnreadMessages() async throws -> [SourceMessage] {
        logger.info("fetchUnreadMessages() started")

        // Шаг 1: Загружаем все чаты через loadChats + updates stream
        var allChats: [ChatResponse] = []

        // TODO: Здесь проблема — как синхронизировать два таска?
        // Task 1 слушает updates бесконечно
        // Task 2 делает loadChats() до 404
        // Когда Task 2 завершился → как остановить Task 1?
        //
        // ВОПРОС: Нужен ли отдельный метод для синхронизации?
        // Или можно использовать withTimeout + cancel?

        logger.info("Loaded \(allChats.count) chats from TDLib")

        // Шаг 2: Фильтруем каналы с непрочитанными
        let unreadChannels = allChats.filter { chat in
            // TODO: Как проверить что это канал?
            // chat.chatType — это enum, нужно case .supergroup(_, isChannel: true)
            // Но нужна ли нам модель ChatType? Она уже есть?
            return false
        }

        logger.info("Found \(unreadChannels.count) unread channels")

        // Шаг 3: Получаем сообщения из каждого канала параллельно
        // TODO: getChatHistory() ещё не реализован
        // TODO: Нужна конвертация TDLib Message → SourceMessage

        return []
    }

    public func markAsRead(messages: [SourceMessage]) async throws {
        // TODO: Реализовать viewMessages группировкой по chatId
        fatalError("Not implemented yet - RED phase")
    }
}
