import Foundation
import TDLibAdapter

/// Источник сообщений из Telegram каналов.
///
/// **Реализация:** Stateless подход для MVP (без realtime кеша).
///
/// **Алгоритм:**
/// 1. loadChats() в цикле (pagination до 404)
/// 2. Слушаем updates stream → получаем updateNewChat для каждого чата
/// 3. Фильтруем: только каналы (type=.supergroup(isChannel: true)) с unreadCount > 0
/// 4. getChatHistory() для каждого канала
/// 5. Формируем SourceMessage[] с ссылками
///
/// **Связанная документация:**
/// - E2E сценарий: <doc:FetchUnreadMessages>
/// - Component тест: `ChannelMessageSourceTests.swift`
public actor ChannelMessageSource: MessageSourceProtocol {
    private let tdlib: TDLibClientProtocol

    public init(tdlib: TDLibClientProtocol) {
        self.tdlib = tdlib
    }

    public func fetchUnreadMessages() async throws -> [SourceMessage] {
        // TODO: Реализовать after MVP-1.7 Phase 3 (loadChats + updates + getChatHistory)
        // Сейчас это заглушка для компиляции
        fatalError("Not implemented yet - waiting for MVP-1.7 completion")
    }

    public func markAsRead(messages: [SourceMessage]) async throws {
        // TODO: Реализовать viewMessages группировкой по chatId
        fatalError("Not implemented yet - RED phase")
    }
}
