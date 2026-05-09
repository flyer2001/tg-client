import Foundation
import Hummingbird
import Logging

/// HTTP сервер моста tg-client ↔ VK.
///
/// Слушает на `127.0.0.1:<port>`, наружу выставляется через nginx
/// (`location /vkWebHook` → `proxy_pass http://127.0.0.1:<port>`).
///
/// **Endpoints:**
/// - `GET /health` — диагностика для мониторинга и команды `/test`. Возвращает `"ok"`.
/// - `POST /vkWebHook` — приём событий от VK Callback API.
public struct BotBridgeServer: Sendable {
    private let config: BotBridgeConfig
    private let webhookHandler: VKWebhookHandler
    private let logger: Logger

    public init(config: BotBridgeConfig, webhookHandler: VKWebhookHandler, logger: Logger) {
        self.config = config
        self.webhookHandler = webhookHandler
        self.logger = logger
    }

    /// Запускает HTTP сервер. Блокирует до отмены Task / SIGTERM.
    public func run() async throws {
        let router = Router()

        router.get("health") { _, _ -> String in
            return "ok"
        }

        webhookHandler.register(on: router)

        let app = Application(
            router: router,
            configuration: .init(
                address: .hostname(config.httpHost, port: config.httpPort),
                serverName: "tg-client-bot-bridge"
            ),
            logger: logger
        )

        logger.info("BotBridge HTTP server starting", metadata: [
            "host": .string(config.httpHost),
            "port": .stringConvertible(config.httpPort)
        ])
        try await app.runService()
    }
}
