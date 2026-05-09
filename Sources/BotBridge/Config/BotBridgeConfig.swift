import Foundation

/// Конфигурация моста tg-client ↔ VK.
///
/// Читается из переменных окружения. Все обязательные поля проверяются
/// при инициализации — если что-то отсутствует, бросается `BotBridgeConfigError`.
///
/// **Источник:** обычно `/etc/tg-client.env` (mode 600), подключенный через
/// `EnvironmentFile` в systemd unit.
public struct BotBridgeConfig: Sendable {
    /// Токен сообщества VK со scope `messages`.
    public let vkBotToken: String

    /// ID сообщества VK (число из URL вида vk.com/club<id>).
    public let vkBotGroupId: Int

    /// Whitelist пользователей VK, которым разрешено вызывать команды.
    public let vkBotOwnerIds: Set<Int>

    /// Секрет, заданный в настройках VK Callback API.
    /// Приходит в каждом POST'е, валидируем чтобы фильтровать чужие запросы.
    public let vkCallbackSecret: String

    /// Confirmation token из настроек VK Callback API.
    /// Возвращается в ответ на запрос `type: "confirmation"`.
    public let vkConfirmationToken: String

    /// Версия VK API (например, "5.199").
    public let vkApiVersion: String

    /// Хост, на котором слушает Hummingbird (обычно "127.0.0.1" — наружу через nginx).
    public let httpHost: String

    /// Порт Hummingbird (по умолчанию 8082, не должен пересекаться с cashflow на 8080).
    public let httpPort: Int

    public init(
        vkBotToken: String,
        vkBotGroupId: Int,
        vkBotOwnerIds: Set<Int>,
        vkCallbackSecret: String,
        vkConfirmationToken: String,
        vkApiVersion: String = "5.199",
        httpHost: String = "127.0.0.1",
        httpPort: Int = 8082
    ) {
        self.vkBotToken = vkBotToken
        self.vkBotGroupId = vkBotGroupId
        self.vkBotOwnerIds = vkBotOwnerIds
        self.vkCallbackSecret = vkCallbackSecret
        self.vkConfirmationToken = vkConfirmationToken
        self.vkApiVersion = vkApiVersion
        self.httpHost = httpHost
        self.httpPort = httpPort
    }

    /// Загружает конфигурацию из переменных окружения процесса.
    ///
    /// Обязательные: `VK_BOT_TOKEN`, `VK_BOT_GROUP_ID`, `VK_BOT_OWNER_IDS`,
    /// `VK_CALLBACK_SECRET`, `VK_CONFIRMATION_TOKEN`.
    /// Опциональные: `VK_API_VERSION` (5.199), `BOT_BRIDGE_HOST` (127.0.0.1), `BOT_BRIDGE_PORT` (8082).
    ///
    /// `VK_BOT_OWNER_IDS` — comma-separated список целых VK user id.
    public static func fromEnvironment(_ env: [String: String] = ProcessInfo.processInfo.environment) throws -> BotBridgeConfig {
        let token = try require(env, "VK_BOT_TOKEN")
        let groupIdStr = try require(env, "VK_BOT_GROUP_ID")
        let ownerIdsStr = try require(env, "VK_BOT_OWNER_IDS")
        let secret = try require(env, "VK_CALLBACK_SECRET")
        let confirmation = try require(env, "VK_CONFIRMATION_TOKEN")

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

        let port = env["BOT_BRIDGE_PORT"].flatMap { Int($0) } ?? 8082

        return BotBridgeConfig(
            vkBotToken: token,
            vkBotGroupId: groupId,
            vkBotOwnerIds: ownerIds,
            vkCallbackSecret: secret,
            vkConfirmationToken: confirmation,
            vkApiVersion: env["VK_API_VERSION"] ?? "5.199",
            httpHost: env["BOT_BRIDGE_HOST"] ?? "127.0.0.1",
            httpPort: port
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
