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

    enum CodingKeys: String, CodingKey {
        case type = "@type"
        case chatId
        case messageIds
        case forceRead
    }

    public init(chatId: Int64, messageIds: [Int64], forceRead: Bool) {
        self.chatId = chatId
        self.messageIds = messageIds
        self.forceRead = forceRead
    }
}
