import Foundation

/// Тип чата в TDLib.
///
/// **TDLib API:** https://core.telegram.org/tdlib/docs/classtd_1_1td__api_1_1_chat_type.html
public enum ChatType: Sendable, Equatable {
    /// Личный чат с пользователем
    case `private`(userId: Int64)

    /// Обычная группа (до 200 участников)
    case basicGroup(basicGroupId: Int64)

    /// Супергруппа или канал (isChannel=true для каналов)
    case supergroup(supergroupId: Int64, isChannel: Bool)

    /// Секретный чат с E2E шифрованием
    case secret(secretChatId: Int64, userId: Int64)
}

// MARK: - Decodable

extension ChatType: Decodable {
    enum CodingKeys: String, CodingKey {
        case type = "@type"
        case userId = "user_id"
        case basicGroupId = "basic_group_id"
        case supergroupId = "supergroup_id"
        case isChannel = "is_channel"
        case secretChatId = "secret_chat_id"
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(String.self, forKey: .type)

        switch type {
        case "chatTypePrivate":
            let userId = try container.decode(Int64.self, forKey: .userId)
            self = .private(userId: userId)

        case "chatTypeBasicGroup":
            let basicGroupId = try container.decode(Int64.self, forKey: .basicGroupId)
            self = .basicGroup(basicGroupId: basicGroupId)

        case "chatTypeSupergroup":
            let supergroupId = try container.decode(Int64.self, forKey: .supergroupId)
            let isChannel = try container.decode(Bool.self, forKey: .isChannel)
            self = .supergroup(supergroupId: supergroupId, isChannel: isChannel)

        case "chatTypeSecret":
            let secretChatId = try container.decode(Int64.self, forKey: .secretChatId)
            let userId = try container.decode(Int64.self, forKey: .userId)
            self = .secret(secretChatId: secretChatId, userId: userId)

        default:
            throw DecodingError.dataCorruptedError(
                forKey: .type,
                in: container,
                debugDescription: "Unknown ChatType: \(type)"
            )
        }
    }
}
