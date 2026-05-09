import Foundation
import Hummingbird
import Logging

/// Обработчик входящих POST'ов от VK Callback API.
///
/// **Контракт VK:**
/// - VK ждёт ответ ≤ 10 секунд, иначе ретраит. Поэтому `message_new` обрабатываем
///   асинхронно в `Task` — моментально возвращаем `"ok"`, фактическая работа в фоне.
/// - На любую ошибку отвечаем `"ok"` (200), чтобы избежать retry бури от VK.
///   Фактическая ошибка логируется + возможно пишется в audit лог.
/// - На `type: "confirmation"` возвращаем confirmation token (без него VK не активирует webhook).
public struct VKWebhookHandler: Sendable {
    private let config: BotBridgeConfig
    private let processor: CommandProcessor
    private let logger: Logger

    public init(config: BotBridgeConfig, processor: CommandProcessor, logger: Logger) {
        self.config = config
        self.processor = processor
        self.logger = logger
    }

    /// Регистрирует endpoint `POST /vkWebHook` на переданном Router.
    public func register(on router: Router<BasicRequestContext>) {
        router.post("vkWebHook") { request, _ -> String in
            await self.handle(request: request)
        }
    }

    // MARK: - Private

    private func handle(request: Request) async -> String {
        let bodyBuffer: ByteBuffer
        do {
            bodyBuffer = try await request.body.collect(upTo: 64 * 1024)  // 64 KB достаточно для VK события
        } catch {
            logger.error("Failed to read VK webhook body: \(error)")
            return "ok"
        }

        guard let bytes = bodyBuffer.getBytes(at: 0, length: bodyBuffer.readableBytes), !bytes.isEmpty else {
            logger.warning("VK webhook: empty body")
            return "ok"
        }
        let bodyData = Data(bytes)

        let event: VKCallbackEvent
        do {
            event = try JSONDecoder().decode(VKCallbackEvent.self, from: bodyData)
        } catch {
            logger.error("VK webhook: invalid JSON: \(error)")
            return "ok"
        }

        // Secret validation (для всех событий кроме первого confirmation:
        // VK на confirmation шлёт без secret, потому что secret ещё может быть не настроен)
        if event.type != "confirmation" {
            guard event.secret == config.vkCallbackSecret else {
                logger.warning("VK webhook: secret mismatch (or missing)", metadata: [
                    "type": .string(event.type),
                    "group_id": .stringConvertible(event.groupId ?? -1)
                ])
                return "ok"
            }
        }

        switch event.type {
        case "confirmation":
            logger.info("VK webhook: confirmation handshake", metadata: [
                "group_id": .stringConvertible(event.groupId ?? -1)
            ])
            return config.vkConfirmationToken

        case "message_new":
            guard let message = event.object?.message else {
                logger.warning("VK webhook: message_new without message object")
                return "ok"
            }

            logger.info("VK webhook: message_new", metadata: [
                "from_id": .stringConvertible(message.fromId),
                "peer_id": .stringConvertible(message.peerId),
                "text_preview": .string(message.text.prefix(80).description)
            ])

            // Fire-and-forget: обработка в фоне, чтобы вернуть VK "ok" моментально
            Task {
                await processor.handle(message: message)
            }
            return "ok"

        default:
            logger.debug("VK webhook: ignoring event type '\(event.type)'")
            return "ok"
        }
    }
}
