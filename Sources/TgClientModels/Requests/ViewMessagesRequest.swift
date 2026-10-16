import TGClientInterfaces
import Foundation

/// Запрос для отметки сообщений как просмотренных.
///
/// Уменьшает unread count чата. Идемпотентен.
///
/// **TDLib API:** https://core.telegram.org/tdlib/docs/classtd_1_1td__api_1_1view_messages.html
public struct ViewMessagesRequest: TDLibRequest, Sendable {
    public let type = "viewMessages"

    /// ID чата.
    public let chatId: Int64

    /// Массив ID сообщений для отметки.
    public let messageIds: [Int64]

    /// Принудительная отметка (игнорировать серверный unread count).
    public let forceRead: Bool

    /// Откуда сообщения просмотрены; `nil` — TDLib угадывает. Тема форума — `.forumTopicHistory`
    /// (спайк 2026-10-16: метит ровно эту тему, остальные не трогает).
    public let source: MessageSource?

    enum CodingKeys: String, CodingKey {
        case type = "@type"
        case chatId
        case messageIds
        case forceRead
        case source
    }

    public init(chatId: Int64, messageIds: [Int64], forceRead: Bool, source: MessageSource? = nil) {
        self.chatId = chatId
        self.messageIds = messageIds
        self.forceRead = forceRead
        self.source = source
    }
}

/// Источник просмотра сообщений (`MessageSource` в TDLib).
///
/// **TDLib API:** https://core.telegram.org/tdlib/docs/classtd_1_1td__api_1_1_message_source.html
public struct MessageSource: Codable, Sendable, Equatable {
    public let type: String

    enum CodingKeys: String, CodingKey {
        case type = "@type"
    }

    /// Сообщения из истории темы форума.
    public static let forumTopicHistory = MessageSource(type: "messageSourceForumTopicHistory")
}
