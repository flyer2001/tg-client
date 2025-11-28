import TGClientInterfaces
import Foundation

/// Модель чата TDLib с полной информацией.
///
/// **TDLib API:** https://core.telegram.org/tdlib/docs/classtd_1_1td__api_1_1chat.html
public struct ChatResponse: TDLibResponse, Sendable, Equatable {
    public let type = "chat"

    /// Уникальный идентификатор чата
    public let id: Int64

    /// Тип чата (private, basicGroup, supergroup/channel, secret)
    public let chatType: ChatType

    /// Название чата
    public let title: String

    /// Количество непрочитанных сообщений
    public let unreadCount: Int32

    /// ID последнего прочитанного входящего сообщения
    public let lastReadInboxMessageId: Int64

    enum CodingKeys: String, CodingKey {
        case type = "@type"
        case id
        case chatType = "type"
        case title
        case unreadCount
        case lastReadInboxMessageId
    }

    #if DEBUG
    /// Инициализатор для создания чата программно (например, в тестах).
    public init(id: Int64, type: ChatType, title: String, unreadCount: Int32, lastReadInboxMessageId: Int64) {
        self.id = id
        self.chatType = type
        self.title = title
        self.unreadCount = unreadCount
        self.lastReadInboxMessageId = lastReadInboxMessageId
    }
    #endif
}
