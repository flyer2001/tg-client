import Foundation

/// Запрос для получения полной информации о чате.
///
/// **TDLib API:** https://core.telegram.org/tdlib/docs/classtd_1_1td__api_1_1get_chat.html
public struct GetChatRequest: TDLibRequest {
    public let type = "getChat"
    public let chatId: Int64

    enum CodingKeys: String, CodingKey {
        case type = "@type"
        case chatId
    }

    public init(chatId: Int64) {
        self.chatId = chatId
    }
}
