import TGClientInterfaces
import Foundation
import FoundationExtensions

/// Запрос `getChats` для TDLib.
///
/// **Что делает:** возвращает список chat_ids уже подгруженных в in-memory cache.
/// Не дёргает сеть, в отличие от `loadChats` (который только догружает с сервера).
///
/// **Use case:** в long-running сервисе после initial loadChats — для повторной выборки
/// чатов без `updateNewChat` событий (TDLib шлёт их только при первой подгрузке).
///
/// **TDLib API:** https://core.telegram.org/tdlib/docs/classtd_1_1td__api_1_1get_chats.html
public struct GetChatsRequest: TDLibRequest {
    public let type = "getChats"
    public let chatList: ChatList
    public let limit: Int32

    enum CodingKeys: String, CodingKey {
        case type = "@type"
        case chatList
        case limit
    }

    public init(chatList: ChatList, limit: Int32) {
        self.chatList = chatList
        self.limit = limit
    }
}

/// Ответ от TDLib `getChats` — список chat_ids.
///
/// **Note про CodingKeys:** `JSONDecoder.tdlib()` использует `convertFromSnakeCase`,
/// поэтому `chat_ids` → `chatIds` декодером автоматически. Не указываем явный rawValue
/// для этих ключей — Swift сам подставит camelCase имя.
public struct ChatsResponse: TDLibResponse, Sendable, Codable, Equatable {
    public let type = "chats"
    public let chatIds: [Int64]
    public let totalCount: Int32

    enum CodingKeys: String, CodingKey {
        case type = "@type"
        case chatIds
        case totalCount
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.chatIds = try container.decode([Int64].self, forKey: .chatIds)
        self.totalCount = try container.decode(Int32.self, forKey: .totalCount)
    }
}
