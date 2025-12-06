import TGClientInterfaces
import Foundation
import FoundationExtensions

/// Update от TDLib (уведомления о событиях).
///
/// **TDLib API:**
/// - Base class: https://core.telegram.org/tdlib/docs/classtd_1_1td__api_1_1update.html
/// - updateNewChat: https://core.telegram.org/tdlib/docs/classtd_1_1td__api_1_1update_new_chat.html
/// - updateChatReadInbox: https://core.telegram.org/tdlib/docs/classtd_1_1td__api_1_1update_chat_read_inbox.html
public enum Update: Sendable, Equatable {
    /// Новый чат загружен/создан.
    ///
    /// Гарантируется поступление до возвращения идентификатора чата приложению.
    case newChat(chat: ChatResponse)

    /// Входящие сообщения прочитаны или изменился счётчик непрочитанных.
    case chatReadInbox(chatId: Int64, lastReadInboxMessageId: Int64, unreadCount: Int32)

    /// Позиция чата в списке изменилась.
    case chatPosition(chatId: Int64, position: ChatPosition)

    /// Неизвестный тип update (для совместимости с будущими версиями TDLib).
    case unknown(type: String)
}

// MARK: - Codable

extension Update: Codable {
    enum CodingKeys: String, CodingKey {
        case type = "@type"
        case chat
        case chatId
        case lastReadInboxMessageId
        case unreadCount
        case position
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(String.self, forKey: .type)

        switch type {
        case "updateNewChat":
            let chat = try container.decode(ChatResponse.self, forKey: .chat)
            self = .newChat(chat: chat)

        case "updateChatReadInbox":
            let chatId = try container.decodeInt64(forKey: .chatId)
            let lastReadInboxMessageId = try container.decodeInt64(forKey: .lastReadInboxMessageId)
            let unreadCount = try container.decodeInt32(forKey: .unreadCount)
            self = .chatReadInbox(
                chatId: chatId,
                lastReadInboxMessageId: lastReadInboxMessageId,
                unreadCount: unreadCount
            )

        case "updateChatPosition":
            let chatId = try container.decodeInt64(forKey: .chatId)
            let position = try container.decode(ChatPosition.self, forKey: .position)
            self = .chatPosition(chatId: chatId, position: position)

        default:
            // Неизвестный тип — сохраняем для обратной совместимости
            self = .unknown(type: type)
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        switch self {
        case .newChat(let chat):
            try container.encode("updateNewChat", forKey: .type)
            try container.encode(chat, forKey: .chat)

        case .chatReadInbox(let chatId, let lastReadInboxMessageId, let unreadCount):
            try container.encode("updateChatReadInbox", forKey: .type)
            try container.encode(chatId, forKey: .chatId)
            try container.encode(lastReadInboxMessageId, forKey: .lastReadInboxMessageId)
            try container.encode(unreadCount, forKey: .unreadCount)

        case .chatPosition(let chatId, let position):
            try container.encode("updateChatPosition", forKey: .type)
            try container.encode(chatId, forKey: .chatId)
            try container.encode(position, forKey: .position)

        case .unknown(let type):
            try container.encode(type, forKey: .type)
        }
    }
}
