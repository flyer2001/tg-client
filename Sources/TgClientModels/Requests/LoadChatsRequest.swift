import TGClientInterfaces
import Foundation
import FoundationExtensions

/// Тип списка чатов в TDLib.
///
/// **TDLib API:** https://core.telegram.org/tdlib/docs/classtd_1_1td__api_1_1chat_list.html
public enum ChatList: Sendable, Equatable, Hashable {
    /// Основной список чатов (все чаты кроме архивных)
    case main

    /// Архивные чаты
    case archive

    /// Папка чатов с указанным ID
    case folder(id: Int32)
}

extension ChatList: Encodable {
    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()

        switch self {
        case .main:
            try container.encode(ChatListMain())
        case .archive:
            try container.encode(ChatListArchive())
        case .folder(let id):
            try container.encode(ChatListFolder(chatFolderId: id))
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

/// Вспомогательная структура для кодирования chatListFolder
private struct ChatListFolder: Encodable {
    let type = "chatListFolder"
    let chatFolderId: Int32

    enum CodingKeys: String, CodingKey {
        case type = "@type"
        case chatFolderId = "chat_folder_id"
    }
}

extension ChatList: Decodable {
    enum CodingKeys: String, CodingKey {
        case type = "@type"
        case chatFolderId  // convertFromSnakeCase: chat_folder_id → chatFolderId
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(String.self, forKey: .type)

        switch type {
        case "chatListMain":
            self = .main

        case "chatListArchive":
            self = .archive

        case "chatListFolder":
            // chatFolderId может быть String или Int (используем helper)
            let folderId = try container.decodeInt32(forKey: .chatFolderId)
            self = .folder(id: folderId)

        default:
            throw DecodingError.dataCorruptedError(
                forKey: .type,
                in: container,
                debugDescription: "Unknown ChatList type: \(type)"
            )
        }
    }
}

/// Запрос loadChats для TDLib.
///
/// **TDLib API:** https://core.telegram.org/tdlib/docs/classtd_1_1td__api_1_1load_chats.html
public struct LoadChatsRequest: TDLibRequest {
    public let type = "loadChats"
    public let chatList: ChatList
    public let limit: Int

    enum CodingKeys: String, CodingKey {
        case type = "@type"
        case chatList
        case limit
    }

    public init(chatList: ChatList, limit: Int) {
        self.chatList = chatList
        self.limit = limit
    }
}
