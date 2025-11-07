import Foundation

/// Тип списка чатов в TDLib.
///
/// **TDLib API:** https://core.telegram.org/tdlib/docs/classtd_1_1td__api_1_1chat_list.html
public enum ChatList: Sendable, Equatable {
    /// Основной список чатов (все чаты кроме архивных)
    case main

    /// Архивные чаты
    case archive
}

extension ChatList: Encodable {
    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()

        switch self {
        case .main:
            try container.encode(ChatListMain())
        case .archive:
            try container.encode(ChatListArchive())
        }
    }
}

/// Вспомогательная структура для кодирования chatListMain
private struct ChatListMain: Encodable {
    let type = "chatListMain"

    enum CodingKeys: String, CodingKey {
        case type = "@type"
    }
}

/// Вспомогательная структура для кодирования chatListArchive
private struct ChatListArchive: Encodable {
    let type = "chatListArchive"

    enum CodingKeys: String, CodingKey {
        case type = "@type"
    }
}

public struct GetChatsRequest: TDLibRequest {
    public let type = "getChats"
    public let chatList: ChatList
    public let limit: Int

    enum CodingKeys: String, CodingKey {
        case type = "@type"
        case chatList = "chat_list"
        case limit
    }

    public init(chatList: ChatList, limit: Int) {
        self.chatList = chatList
        self.limit = limit
    }
}
