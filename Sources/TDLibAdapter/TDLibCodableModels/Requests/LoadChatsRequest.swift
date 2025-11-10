import Foundation

/// Запрос loadChats для TDLib.
///
/// **TDLib API:** https://core.telegram.org/tdlib/docs/classtd_1_1td__api_1_1load_chats.html
public struct LoadChatsRequest: TDLibRequest {
    public let type = "loadChats"
    public let chatList: ChatList
    public let limit: Int

    enum CodingKeys: String, CodingKey {
        case type = "@type"
        case chatList
        case limit
    }

    public init(chatList: ChatList, limit: Int) {
        self.chatList = chatList
        self.limit = limit
    }
}
