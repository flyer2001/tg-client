import TGClientInterfaces
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

// MARK: - Codable

extension ChatType: Codable {
    enum CodingKeys: String, CodingKey {
        case type = "@type"
        case userId
        case basicGroupId
        case supergroupId
        case isChannel
        case secretChatId
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
            // TDLib возвращает is_channel как Int (0/1), не Bool
            let isChannel: Bool
            if let boolValue = try? container.decode(Bool.self, forKey: .isChannel) {
                isChannel = boolValue
            } else if let intValue = try? container.decode(Int.self, forKey: .isChannel) {
                isChannel = intValue != 0
            } else {
                throw DecodingError.typeMismatch(
                    Bool.self,
                    DecodingError.Context(
                        codingPath: container.codingPath + [CodingKeys.isChannel],
                        debugDescription: "isChannel must be Bool or Int"
                    )
                )
            }
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

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        switch self {
        case .private(let userId):
            try container.encode("chatTypePrivate", forKey: .type)
            try container.encode(userId, forKey: .userId)

        case .basicGroup(let basicGroupId):
            try container.encode("chatTypeBasicGroup", forKey: .type)
            try container.encode(basicGroupId, forKey: .basicGroupId)

        case .supergroup(let supergroupId, let isChannel):
            try container.encode("chatTypeSupergroup", forKey: .type)
            try container.encode(supergroupId, forKey: .supergroupId)
            try container.encode(isChannel, forKey: .isChannel)

        case .secret(let secretChatId, let userId):
            try container.encode("chatTypeSecret", forKey: .type)
            try container.encode(secretChatId, forKey: .secretChatId)
            try container.encode(userId, forKey: .userId)
        }
    }
}
