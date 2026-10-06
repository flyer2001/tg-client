import Foundation

/// Конфигурация моста tg-client ↔ VK.
///
/// Читается из переменных окружения. Все обязательные поля проверяются
/// при инициализации — если что-то отсутствует, бросается `BotBridgeConfigError`.
///
/// **Источник:** обычно `/etc/tg-client.env` (mode 600), подключенный через
/// `EnvironmentFile` в systemd unit.
public struct BotBridgeConfig: Sendable {
    /// Ключ сообщества VK с правами `manage` (Long Poll) и `messages`.
    public let vkBotToken: String

    /// ID сообщества VK (число из URL вида vk.com/club<id>).
    public let vkBotGroupId: Int

    /// Whitelist пользователей VK, которым разрешено вызывать команды.
    public let vkBotOwnerIds: Set<Int>

    /// Версия VK API (например, "5.199").
    public let vkApiVersion: String

    public init(vkBotToken: String, vkBotGroupId: Int, vkBotOwnerIds: Set<Int>, vkApiVersion: String = "5.199") {
        self.vkBotToken = vkBotToken
        self.vkBotGroupId = vkBotGroupId
        self.vkBotOwnerIds = vkBotOwnerIds
        self.vkApiVersion = vkApiVersion
    }

    /// Загружает конфигурацию из переменных окружения процесса.
    ///
    /// Обязательные: `VK_BOT_TOKEN`, `VK_BOT_GROUP_ID`, `VK_BOT_OWNER_IDS`.
    /// Опциональные: `VK_API_VERSION` (5.199).
    ///
    /// `VK_BOT_OWNER_IDS` — comma-separated список целых VK user id.
    public static func fromEnvironment(_ env: [String: String] = ProcessInfo.processInfo.environment) throws -> BotBridgeConfig {
        let token = try require(env, "VK_BOT_TOKEN")
        let groupIdStr = try require(env, "VK_BOT_GROUP_ID")
        let ownerIdsStr = try require(env, "VK_BOT_OWNER_IDS")

        guard let groupId = Int(groupIdStr) else {
            throw BotBridgeConfigError.invalidValue(key: "VK_BOT_GROUP_ID", value: groupIdStr)
        }

        let ownerIds = Set(
            ownerIdsStr
                .split(separator: ",")
                .compactMap { Int($0.trimmingCharacters(in: .whitespaces)) }
        )
        guard !ownerIds.isEmpty else {
            throw BotBridgeConfigError.invalidValue(key: "VK_BOT_OWNER_IDS", value: ownerIdsStr)
        }

        return BotBridgeConfig(
            vkBotToken: token,
            vkBotGroupId: groupId,
            vkBotOwnerIds: ownerIds,
            vkApiVersion: env["VK_API_VERSION"] ?? "5.199"
        )
    }

    private static func require(_ env: [String: String], _ key: String) throws -> String {
        guard let value = env[key], !value.isEmpty else {
            throw BotBridgeConfigError.missing(key: key)
        }
        return value
    }
}

public enum BotBridgeConfigError: Error, CustomStringConvertible {
    case missing(key: String)
    case invalidValue(key: String, value: String)

    public var description: String {
        switch self {
        case .missing(let key):
            return "BotBridge config: missing required env var '\(key)'"
        case .invalidValue(let key, let value):
            return "BotBridge config: invalid value for '\(key)': '\(value)'"
        }
    }
}
