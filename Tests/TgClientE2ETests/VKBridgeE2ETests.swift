import TgClientModels
import Foundation
import Testing
import Logging
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
@testable import TDLibAdapter
@testable import DigestCore
@testable import BotBridge

// MARK: - E2E Tests

/// E2E тест для сценария управления Telegram-клиентом через VK-сообщество.
///
/// **User Story:** <doc:VKBridge>
///
/// **Что проверяется:**
/// - VK Bots Long Poll доставляет сообщение владельца в сервис (без webhook, домена и nginx)
/// - Команда `/test` проходит путь Long Poll → `CommandProcessor` → `messages.send`
/// - Остановка: отмена задачи цикла завершает `run()` (spike: отмена URLSession на Linux работает)
///
/// **Предусловия:**
/// - VK-сообщество: сообщения + «Возможности ботов» + Long Poll API (5.199, «Входящее сообщение»)
/// - Ключ сообщества с правами `manage` + `messages`
/// - Окружение: `VK_BOT_TOKEN`, `VK_BOT_GROUP_ID`, `VK_BOT_OWNER_IDS` (`set -a; source .env; set +a`)
/// - TDLib для `/test` не нужен (команда не обращается к Telegram)
@Suite("E2E: Управление через VK-сообщество (Long Poll)")
struct VKBridgeE2ETests {

    /// E2E тест: владелец пишет `/test` в сообщество → получает ответ о статусе.
    ///
    /// **Результат spike v0.5.0** (`spikes/vk-longpoll/README.md`): `wait=25` → ответ VK ~22 c,
    /// `ts` строкой, `failed:2` на битом ключе, `Task.cancel()` прерывает запрос за 2 c.
    ///
    /// **Сценарий:**
    /// 1. Запустить Long Poll на реальном сообществе
    /// 2. В течение 2 минут владелец пишет `/test` в сообщество
    /// 3. Сервис отвечает в тот же диалог
    /// 4. Проверить через `messages.getHistory`: последнее исходящее сообщение сообщества — отчёт `alive`
    /// 5. Отменить цикл → `run()` завершается
    ///
    /// **Как запустить:** убрать `.disabled(...)`, затем
    /// `set -a; source .env; set +a; swift test --filter VKBridgeE2ETests`
    @Test("E2E: /test через VK Long Poll → ответ владельцу", .disabled("E2E: реальное VK-сообщество, запускать вручную"))
    func testCommandRoundTrip() async throws {
        let env = ProcessInfo.processInfo.environment
        let config = try BotBridgeConfig.fromEnvironment(env)
        let logger = Logger(label: "tg-client.e2e.vk-bridge")
        let http = URLSessionHTTPClient()

        let vkClient = VKAPIClient(token: config.vkBotToken, apiVersion: config.vkApiVersion, httpClient: http, logger: logger)
        let tdlib = TDLibClient(appLogger: logger)  // /test не трогает TDLib — авторизация не нужна
        let processor = CommandProcessor(
            messageSource: ChannelMessageSource(tdlib: tdlib, logger: logger),
            tdlib: tdlib,
            vkClient: vkClient,
            allowedOwners: config.vkBotOwnerIds,
            logger: logger
        )

        let (handled, handledContinuation) = AsyncStream<VKMessage>.makeStream()
        let poller = VKLongPollClient(
            groupId: config.vkBotGroupId,
            token: config.vkBotToken,
            apiVersion: config.vkApiVersion,
            httpClient: http,
            logger: logger
        ) { message in
            await processor.handle(message: message)
            handledContinuation.yield(message)
        }

        let loop = Task { try await poller.run() }
        print("👉 Напиши /test в VK-сообщество (club\(config.vkBotGroupId)) в течение 2 минут")

        let message = try await firstElement(of: handled, timeout: .seconds(120))
        #expect(message.text.lowercased().contains("test"))

        let lastOut = try await lastOutgoingText(groupId: config.vkBotGroupId, peerId: message.peerId, config: config, http: http)
        #expect(lastOut.contains("alive"), "Ожидали отчёт /test в диалоге, получили: \(lastOut.prefix(80))")

        loop.cancel()
        _ = await loop.result  // run() обязан завершиться после отмены
    }

    // MARK: - Helpers

    private func firstElement<T: Sendable>(of stream: AsyncStream<T>, timeout: Duration) async throws -> T {
        try await withThrowingTaskGroup(of: T?.self) { group in
            group.addTask { await stream.first { _ in true } }
            group.addTask { try await Task.sleep(for: timeout); return nil }
            defer { group.cancelAll() }
            guard let value = try await group.next() ?? nil else {
                throw E2EError.timeout("сообщение владельца не пришло за \(timeout)")
            }
            return value
        }
    }

    /// Последнее исходящее сообщение сообщества в диалоге — через `messages.getHistory` (ключ сообщества).
    private func lastOutgoingText(groupId: Int, peerId: Int64, config: BotBridgeConfig, http: URLSessionHTTPClient) async throws -> String {
        var components = URLComponents(string: "https://api.vk.com/method/messages.getHistory")!
        components.queryItems = [
            .init(name: "group_id", value: String(groupId)),
            .init(name: "peer_id", value: String(peerId)),
            .init(name: "count", value: "5"),
            .init(name: "access_token", value: config.vkBotToken),
            .init(name: "v", value: config.vkApiVersion),
        ]
        let data = try await http.send(request: URLRequest(url: components.url!))
        struct History: Decodable { let response: R; struct R: Decodable { let items: [Item] }; struct Item: Decodable { let out: Int; let text: String } }
        let history = try JSONDecoder().decode(History.self, from: data)
        return history.response.items.first { $0.out == 1 }?.text ?? ""
    }

    private enum E2EError: Error { case timeout(String) }
}
