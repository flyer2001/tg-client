import TGClientInterfaces
import Foundation

/// Сообщение из Telegram (из TDLib getChatHistory).
///
/// **TDLib API:** https://core.telegram.org/tdlib/docs/classtd_1_1td__api_1_1message.html
public struct Message: Sendable, Codable, Equatable {
    /// ID сообщения (уникален в рамках чата).
    public let id: Int64

    /// ID чата которому принадлежит сообщение.
    public let chatId: Int64

    /// Дата отправки сообщения (Unix timestamp).
    public let date: Int32

    /// Содержимое сообщения.
    public let content: MessageContent

    #if DEBUG
    /// Инициализатор для тестов (создание mock-данных).
    public init(id: Int64, chatId: Int64, date: Int32, content: MessageContent) {
        self.id = id
        self.chatId = chatId
        self.date = date
        self.content = content
    }
    #endif

    private enum CodingKeys: String, CodingKey {
        case type = "@type"
        case id
        case chatId
        case date
        case content
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decode(Int64.self, forKey: .id)
        self.chatId = try container.decode(Int64.self, forKey: .chatId)
        self.date = try container.decode(Int32.self, forKey: .date)
        self.content = try container.decode(MessageContent.self, forKey: .content)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode("message", forKey: .type)
        try container.encode(id, forKey: .id)
        try container.encode(chatId, forKey: .chatId)
        try container.encode(date, forKey: .date)
        try container.encode(content, forKey: .content)
    }
}
