import TGClientInterfaces
import Foundation
import FoundationExtensions

/// Сообщение из Telegram (из TDLib getChatHistory или sendMessage).
///
/// **TDLib API:** https://core.telegram.org/tdlib/docs/classtd_1_1td__api_1_1message.html
public struct Message: TDLibResponse, Sendable, Codable, Equatable {
    public let type = "message"

    /// ID сообщения (уникален в рамках чата).
    public let id: Int64

    /// ID чата которому принадлежит сообщение.
    public let chatId: Int64

    /// Дата отправки сообщения (Unix timestamp).
    public let date: Int32

    /// Содержимое сообщения.
    public let content: MessageContent

    /// ID отправителя: user_id для `messageSenderUser`, chat_id для `messageSenderChat`.
    ///
    /// `nil` если TDLib не прислал `sender_id` (старые сервисные сообщения).
    public let senderId: Int64?

    /// Исходящее ли сообщение (отправлено текущим аккаунтом).
    public let isOutgoing: Bool

    #if DEBUG
    /// Инициализатор для тестов (создание mock-данных).
    public init(
        id: Int64,
        chatId: Int64,
        date: Int32,
        content: MessageContent,
        senderId: Int64? = nil,
        isOutgoing: Bool = false
    ) {
        self.id = id
        self.chatId = chatId
        self.date = date
        self.content = content
        self.senderId = senderId
        self.isOutgoing = isOutgoing
    }
    #endif

    private enum CodingKeys: String, CodingKey {
        case type = "@type"
        case id
        case chatId
        case date
        case content
        case senderId
        case isOutgoing
    }

    /// Ключи вложенного объекта `sender_id` (messageSenderUser / messageSenderChat).
    private enum SenderKeys: String, CodingKey {
        case userId
        case chatId
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decodeInt64(forKey: .id)
        self.chatId = try container.decodeInt64(forKey: .chatId)
        self.date = try container.decode(Int32.self, forKey: .date)
        self.content = try container.decode(MessageContent.self, forKey: .content)
        // На Linux Bool теряет тип при round-trip через JSONSerialization (становится числом),
        // поэтому принимаем и true/false, и 0/1.
        if let flag = try? container.decodeIfPresent(Bool.self, forKey: .isOutgoing) {
            self.isOutgoing = flag ?? false
        } else if let number = try? container.decodeIfPresent(Int.self, forKey: .isOutgoing) {
            self.isOutgoing = number != 0
        } else {
            self.isOutgoing = false
        }

        if let sender = try? container.nestedContainer(keyedBy: SenderKeys.self, forKey: .senderId) {
            self.senderId = (try? sender.decodeInt64(forKey: .userId)) ?? (try? sender.decodeInt64(forKey: .chatId))
        } else {
            self.senderId = nil
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode("message", forKey: .type)
        try container.encode(id, forKey: .id)
        try container.encode(chatId, forKey: .chatId)
        try container.encode(date, forKey: .date)
        try container.encode(content, forKey: .content)
        try container.encode(isOutgoing, forKey: .isOutgoing)
        if let senderId {
            var sender = container.nestedContainer(keyedBy: SenderKeys.self, forKey: .senderId)
            try sender.encode(senderId, forKey: .userId)
        }
    }
}
