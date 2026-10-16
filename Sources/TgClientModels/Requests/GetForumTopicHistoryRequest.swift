import TGClientInterfaces
import Foundation

/// История одной темы форума, newest-first (как `getChatHistory`). `getChatHistory` для форума ненадёжен:
/// спайк 2026-10-16 — вернул 1 сообщение из локального кэша.
///
/// **TDLib API:** https://core.telegram.org/tdlib/docs/classtd_1_1td__api_1_1get_forum_topic_history.html
public struct GetForumTopicHistoryRequest: TDLibRequest, Sendable, Equatable {
    public let type = "getForumTopicHistory"
    public let chatId: Int64
    public let forumTopicId: Int32
    public let fromMessageId: Int64
    public let offset: Int32
    public let limit: Int32

    enum CodingKeys: String, CodingKey {
        case type = "@type"
        case chatId, forumTopicId, fromMessageId, offset, limit
    }

    public init(chatId: Int64, forumTopicId: Int32, fromMessageId: Int64, offset: Int32, limit: Int32) {
        self.chatId = chatId
        self.forumTopicId = forumTopicId
        self.fromMessageId = fromMessageId
        self.offset = offset
        self.limit = limit
    }
}
