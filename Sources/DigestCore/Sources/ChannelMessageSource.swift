import Foundation
import TDLibAdapter

/// Источник сообщений из Telegram каналов.
///
/// **Архитектура:**
/// - Coordinator pattern: координирует работу подкомпонентов
/// - Декомпозиция по SRP: ChannelCache, UpdatesHandler, MessageFetcher
///
/// **Алгоритм:**
/// 1. Запускает UpdatesHandler для получения updates от TDLib
/// 2. Вызывает loadChats() для загрузки списка чатов
/// 3. Получает детали каждого чата через getChat()
/// 4. Фильтрует: только каналы (type=.supergroup(isChannel: true)) с unreadCount > 0
/// 5. Использует MessageFetcher для получения сообщений из каналов
/// 6. Формирует SourceMessage[] с ссылками
///
/// **Связанная документация:**
/// - E2E сценарий: <doc:FetchUnreadMessages>
/// - Component тест: `ChannelMessageSourceTests.swift`
public final class ChannelMessageSource: MessageSourceProtocol, Sendable {
    private let tdlib: TDLibClient

    // TODO: Добавить зависимости:
    // private let cache: ChannelCache
    // private let updatesHandler: UpdatesHandler
    // private let messageFetcher: MessageFetcher

    public init(tdlib: TDLibClient) {
        self.tdlib = tdlib
    }

    public func fetchUnreadMessages() async throws -> [SourceMessage] {
        // TODO: Реализовать через декомпозицию
        // 1. updatesHandler.start()
        // 2. loadChats loop (pagination)
        // 3. getChat для каждого чата → cache.add()
        // 4. cache.getUnreadChannels()
        // 5. messageFetcher.fetch(from: channels)
        fatalError("Not implemented yet - RED phase")
    }

    public func markAsRead(messages: [SourceMessage]) async throws {
        // TODO: Реализовать viewMessages группировкой по chatId
        fatalError("Not implemented yet - RED phase")
    }
}
