import TGClientInterfaces
import Foundation

/// Список тем форума (первая страница, до `limit` ≤ 100), с per-topic `unread_count` / `last_read_inbox_message_id`.
///
/// **TDLib API:** https://core.telegram.org/tdlib/docs/classtd_1_1td__api_1_1get_forum_topics.html
public struct GetForumTopicsRequest: TDLibRequest, Sendable, Equatable {
    public let type = "getForumTopics"
    public let chatId: Int64
    public let query: String
    public let offsetDate: Int32
    public let offsetMessageId: Int64
    public let offsetForumTopicId: Int32
    public let limit: Int32

    enum CodingKeys: String, CodingKey {
        case type = "@type"
        case chatId, query, offsetDate, offsetMessageId, offsetForumTopicId, limit
    }

    // ponytail: только первая страница (≤ 100 тем); пагинация по offset_* — если встретится форум больше
    public init(chatId: Int64, limit: Int32) {
        self.chatId = chatId
        self.query = ""
        self.offsetDate = 0
        self.offsetMessageId = 0
        self.offsetForumTopicId = 0
        self.limit = limit
    }
}
