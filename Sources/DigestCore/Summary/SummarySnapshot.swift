import TgClientModels
import Foundation

/// Снапшот непрочитанного для агента (<doc:GetSummary>). Только данные, без AI-текста.
public struct SummarySnapshot: Codable, Equatable, Sendable {
    public let collectedAt: Date
    public let chats: [SummaryChat]
    public let cursor: [CursorEntry]

    public init(collectedAt: Date, chats: [SummaryChat], cursor: [CursorEntry]) {
        self.collectedAt = collectedAt
        self.chats = chats
        self.cursor = cursor
    }

    enum CodingKeys: String, CodingKey { case collectedAt = "collected_at", chats, cursor }

    /// Общий энкодер: snake_case, ISO-8601 даты, отсортированные ключи.
    public static func encoder() -> JSONEncoder {
        let e = JSONEncoder()
        e.dateEncodingStrategy = .iso8601
        e.outputFormatting = [.sortedKeys]
        return e
    }
}

public struct SummaryChat: Codable, Equatable, Sendable {
    public let chatId: Int64
    public let title: String
    public let kind: ChatKind
    public let unreadCount: Int32
    public let messages: [SummaryMessage]
    public let lastMessageId: Int64

    public init(chatId: Int64, title: String, kind: ChatKind, unreadCount: Int32, messages: [SummaryMessage], lastMessageId: Int64) {
        self.chatId = chatId; self.title = title; self.kind = kind
        self.unreadCount = unreadCount; self.messages = messages; self.lastMessageId = lastMessageId
    }

    enum CodingKeys: String, CodingKey {
        case chatId = "chat_id", title, kind, unreadCount = "unread_count", messages, lastMessageId = "last_message_id"
    }
}

/// Тонкое сообщение MVP: текст + id (обогащение — BACKLOG). В форуме — ещё тема.
public struct SummaryMessage: Codable, Equatable, Sendable {
    public let messageId: Int64
    public let text: String
    /// Тема форума; `nil` (поля нет в JSON) — обычный чат.
    public let topic: SummaryTopic?
    public init(messageId: Int64, text: String, topic: SummaryTopic? = nil) {
        self.messageId = messageId; self.text = text; self.topic = topic
    }
    enum CodingKeys: String, CodingKey { case messageId = "message_id", text, topic }
}

/// Тема форума у сообщения: `forum_topic_id` и название.
public struct SummaryTopic: Codable, Equatable, Sendable {
    public let id: Int32
    public let name: String
    public init(id: Int32, name: String) { self.id = id; self.name = name }
}

/// Запись курсора: пометить чат (или тему форума, если `forumTopicId`) прочитанным до `upToMessageId`.
public struct CursorEntry: Codable, Equatable, Sendable {
    public let chatId: Int64
    public let upToMessageId: Int64
    /// Тема форума: у каждой темы своя граница прочитанного → своя запись.
    public let forumTopicId: Int32?
    public init(chatId: Int64, upToMessageId: Int64, forumTopicId: Int32? = nil) {
        self.chatId = chatId; self.upToMessageId = upToMessageId; self.forumTopicId = forumTopicId
    }
    enum CodingKeys: String, CodingKey { case chatId = "chat_id", upToMessageId = "up_to_message_id", forumTopicId = "forum_topic_id" }
}
