import TGClientInterfaces
import Foundation
import FoundationExtensions

/// Темы форума. У каждой темы своя граница прочитанного; чатовый `unread_count` форума = сумма тем
/// (спайк 2026-10-16 на реальном форуме).
///
/// **TDLib API:** https://core.telegram.org/tdlib/docs/classtd_1_1td__api_1_1forum_topics.html
public struct ForumTopicsResponse: TDLibResponse, Sendable, Equatable {
    public let type = "forumTopics"
    public let totalCount: Int32
    public let topics: [ForumTopic]

    enum CodingKeys: String, CodingKey {
        case type = "@type"
        case totalCount, topics
    }

    #if DEBUG
    public init(totalCount: Int32, topics: [ForumTopic]) {
        self.totalCount = totalCount
        self.topics = topics
    }
    #endif
}

/// **TDLib API:** https://core.telegram.org/tdlib/docs/classtd_1_1td__api_1_1forum_topic.html
public struct ForumTopic: Codable, Sendable, Equatable {
    public let info: ForumTopicInfo
    /// Последнее сообщение темы; TDLib: «may be null if unknown».
    public let lastMessage: MessageRef?
    public let unreadCount: Int32
    public let lastReadInboxMessageId: Int64

    public init(info: ForumTopicInfo, lastMessage: MessageRef?, unreadCount: Int32, lastReadInboxMessageId: Int64) {
        self.info = info
        self.lastMessage = lastMessage
        self.unreadCount = unreadCount
        self.lastReadInboxMessageId = lastReadInboxMessageId
    }
}

/// **TDLib API:** https://core.telegram.org/tdlib/docs/classtd_1_1td__api_1_1forum_topic_info.html
public struct ForumTopicInfo: Codable, Sendable, Equatable {
    public let chatId: Int64
    public let forumTopicId: Int32
    public let name: String
    /// Тема General (`forum_topic_id` = 1), её нельзя удалить.
    public let isGeneral: Bool

    public init(chatId: Int64, forumTopicId: Int32, name: String, isGeneral: Bool) {
        self.chatId = chatId
        self.forumTopicId = forumTopicId
        self.name = name
        self.isGeneral = isGeneral
    }

    enum CodingKeys: String, CodingKey { case chatId, forumTopicId, name, isGeneral }

    /// Bool через `decodeBool`: TDLibClient перегоняет ответ через JSONSerialization, на Linux true/false → 1/0.
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        chatId = try c.decode(Int64.self, forKey: .chatId)
        forumTopicId = try c.decode(Int32.self, forKey: .forumTopicId)
        name = try c.decode(String.self, forKey: .name)
        isGeneral = try c.decodeBool(forKey: .isGeneral)
    }
}

/// Только id сообщения — где полное сообщение не нужно (последнее сообщение темы).
public struct MessageRef: Codable, Sendable, Equatable {
    public let id: Int64
    public init(id: Int64) { self.id = id }
}
