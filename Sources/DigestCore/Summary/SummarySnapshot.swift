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

/// Тонкое сообщение MVP: текст + id (обогащение — BACKLOG).
public struct SummaryMessage: Codable, Equatable, Sendable {
    public let messageId: Int64
    public let text: String
    public init(messageId: Int64, text: String) { self.messageId = messageId; self.text = text }
    enum CodingKeys: String, CodingKey { case messageId = "message_id", text }
}

/// Запись курсора: пометить чат прочитанным до `upToMessageId`.
public struct CursorEntry: Codable, Equatable, Sendable {
    public let chatId: Int64
    public let upToMessageId: Int64
    public init(chatId: Int64, upToMessageId: Int64) { self.chatId = chatId; self.upToMessageId = upToMessageId }
    enum CodingKeys: String, CodingKey { case chatId = "chat_id", upToMessageId = "up_to_message_id" }
}
