import TGClientInterfaces
import Foundation

/// Запрос `viewMessages` — помечает сообщения как просмотренные/прочитанные.
///
/// `forceRead: true` помечает диапазон от первого до последнего message_id как прочитанный
/// даже если пользователь физически не открывал чат.
///
/// **TDLib API:** https://core.telegram.org/tdlib/docs/classtd_1_1td__api_1_1view_messages.html
public struct ViewMessagesRequest: TDLibRequest {
    public let type = "viewMessages"
    public let chatId: Int64
    public let messageIds: [Int64]
    public let forceRead: Bool

    enum CodingKeys: String, CodingKey {
        case type = "@type"
        case chatId
        case messageIds
        case forceRead
    }

    public init(chatId: Int64, messageIds: [Int64], forceRead: Bool = true) {
        self.chatId = chatId
        self.messageIds = messageIds
        self.forceRead = forceRead
    }
}
