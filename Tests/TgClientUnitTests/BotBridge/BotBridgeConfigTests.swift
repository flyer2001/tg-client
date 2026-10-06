import Testing
@testable import BotBridge

/// Unit тесты `BotBridgeConfig.fromEnvironment` — конфиг VK-моста из переменных окружения.
///
/// **Контракт v0.5.0 (Long Poll):** обязательны только `VK_BOT_TOKEN`, `VK_BOT_GROUP_ID`, `VK_BOT_OWNER_IDS`.
/// `VK_CALLBACK_SECRET` / `VK_CONFIRMATION_TOKEN` (Callback API webhook spike) больше не нужны.
@Suite("BotBridgeConfig: конфиг VK-моста из окружения")
struct BotBridgeConfigTests {

    private let minimalEnv = [
        "VK_BOT_TOKEN": "vk1.a.token",
        "VK_BOT_GROUP_ID": "242065128",
        "VK_BOT_OWNER_IDS": "360258728, 42",
    ]

    /// Для Long Poll достаточно ключа, id сообщества и владельцев — без секретов webhook.
    @Test("минимальный набор переменных для Long Poll — без VK_CALLBACK_SECRET")
    func minimalLongPollEnv() throws {
        let config = try BotBridgeConfig.fromEnvironment(minimalEnv)

        #expect(config.vkBotToken == "vk1.a.token")
        #expect(config.vkBotGroupId == 242065128)
        #expect(config.vkBotOwnerIds == [360258728, 42])
        #expect(config.vkApiVersion == "5.199")
    }

    @Test("нет VK_BOT_TOKEN — ошибка missing")
    func missingToken() {
        var env = minimalEnv
        env["VK_BOT_TOKEN"] = nil
        #expect(throws: BotBridgeConfigError.self) { try BotBridgeConfig.fromEnvironment(env) }
    }

    @Test("VK_BOT_GROUP_ID не число — ошибка invalidValue")
    func invalidGroupId() {
        var env = minimalEnv
        env["VK_BOT_GROUP_ID"] = "club242065128"
        #expect(throws: BotBridgeConfigError.self) { try BotBridgeConfig.fromEnvironment(env) }
    }
}
