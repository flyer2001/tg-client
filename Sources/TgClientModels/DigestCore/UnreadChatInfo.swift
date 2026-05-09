import Foundation

/// Категория Telegram чата для группировки в UI бота.
public enum ChatKind: String, Sendable, Codable {
    /// Каналы (broadcast): supergroup с isChannel=true.
    case channel

    /// Группы: basicGroup + supergroup с isChannel=false.
    case group

    /// Личные чаты, включая ботов (тип private).
    case dm

    public var emoji: String {
        switch self {
        case .channel: return "📢"
        case .group: return "👥"
        case .dm: return "💬"
        }
    }

    public var displayName: String {
        switch self {
        case .channel: return "Каналы"
        case .group: return "Группы"
        case .dm: return "ЛС"
        }
    }
}

/// Информация о Telegram чате с непрочитанными сообщениями.
///
/// **Не содержит сообщений** — для подгрузки используется отдельный метод
/// `ChannelMessageSource.fetchMessages(for:)`. Это разделение позволяет показать
/// пользователю меню без дорогих `getChatHistory` вызовов на каждый чат.
public struct UnreadChatInfo: Sendable, Codable, Equatable {
    public let id: Int64
    public let title: String
    public let kind: ChatKind
    public let unreadCount: Int32
    public let lastReadInboxMessageId: Int64

    public init(id: Int64, title: String, kind: ChatKind, unreadCount: Int32, lastReadInboxMessageId: Int64) {
        self.id = id
        self.title = title
        self.kind = kind
        self.unreadCount = unreadCount
        self.lastReadInboxMessageId = lastReadInboxMessageId
    }
}
