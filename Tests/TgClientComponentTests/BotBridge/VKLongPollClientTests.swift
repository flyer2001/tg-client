import Foundation
import Testing
import Logging
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
@testable import BotBridge
@testable import TestHelpers

/// Component тесты `VKLongPollClient` — цикл VK Bots Long Poll поверх `HTTPClientProtocol`.
///
/// **User Story:** <doc:VKBridge>
///
/// **Mock:** только сетевая граница — `MockHTTPClient` (очередь ответов VK; когда очередь пуста —
/// «висит» до отмены, как реальный long poll запрос).
///
/// **Реальные ответы VK** взяты из spike (`spikes/vk-longpoll/README.md`, `fixtures/message_new.json`):
/// - `groups.getLongPollServer` → `{"response":{"key":…,"server":…,"ts":"1"}}` — ts строкой
/// - `a_check` → `{"ts":"2","updates":[…]}` или `{"failed":2}`
///
/// **VK docs:** https://dev.vk.com/ru/api/bots-long-poll/getting-started
@Suite("VKLongPollClient: цикл VK Bots Long Poll", .timeLimit(.minutes(1)))  // бесконечный цикл: зависание = провал, не вечный прогон
struct VKLongPollClientTests {

    /// Сообщение, пришедшее через `a_check`, доходит до обработчика.
    ///
    /// **Given:** `getLongPollServer` → server/key/ts; первый `a_check` → `message_new` от владельца
    /// **When:** запускаем `run()`
    /// **Then:** обработчик получает `VKMessage` с текстом и `from_id` из события
    @Test("message_new из a_check доходит до обработчика")
    func messageReachesHandler() async throws {
        let http = MockHTTPClient()
        await http.setStubQueue([
            .success(VKFixtures.server(key: "K1", ts: "10")),
            .success(VKFixtures.poll(ts: "11", updates: [VKFixtures.messageNew(text: "/test", fromId: 360258728)])),
        ])
        await http.setHangWhenExhausted(true)

        let (messages, continuation) = AsyncStream<VKMessage>.makeStream()
        let client = VKLongPollClient(groupId: 242065128, token: "T", httpClient: http, logger: .noop) { message in
            continuation.yield(message)
        }

        let loop = Task { try await client.run() }
        let received = await messages.first { _ in true }
        loop.cancel()

        #expect(received?.text == "/test")
        #expect(received?.fromId == 360258728)
        #expect(received?.peerId == 360258728)
    }

    /// Каждый следующий `a_check` идёт с `ts` из предыдущего ответа — иначе VK повторит те же события.
    ///
    /// **Given:** server ts=10; первый `a_check` → ts=11 + сообщение; второй → ts=12 + сообщение
    /// **When:** получили два сообщения
    /// **Then:** запросы `a_check` ушли с ts=10, затем ts=11
    @Test("следующий a_check идёт с ts из предыдущего ответа")
    func pollAdvancesTs() async throws {
        let http = MockHTTPClient()
        await http.setStubQueue([
            .success(VKFixtures.server(key: "K1", ts: "10")),
            .success(VKFixtures.poll(ts: "11", updates: [VKFixtures.messageNew(text: "first", fromId: 1)])),
            .success(VKFixtures.poll(ts: "12", updates: [VKFixtures.messageNew(text: "second", fromId: 1, id: 3)])),
        ])
        await http.setHangWhenExhausted(true)

        let (messages, continuation) = AsyncStream<VKMessage>.makeStream()
        let client = VKLongPollClient(groupId: 1, token: "T", httpClient: http, logger: .noop) { continuation.yield($0) }
        let loop = Task { try await client.run() }
        let texts = await messages.prefix(2).reduce(into: []) { $0.append($1.text) }
        loop.cancel()

        #expect(texts == ["first", "second"])
        let pollTs = await http.sentRequests.dropFirst().prefix(2).map { $0.queryValue("ts") }
        #expect(pollTs == ["10", "11"])
    }

    // MARK: - failed (VK docs: Bots Long Poll → «Ошибки»)

    /// `failed:1` — история событий устарела: VK присылает новый `ts`, сервер/ключ перезапрашивать не нужно.
    ///
    /// Примечание TDD: тест зелёный сразу — обновление `ts` из ответа (тест выше) уже покрывает этот случай.
    /// Оставлен как контракт: при `failed:1` нет повторного `getLongPollServer`.
    @Test("failed:1 — продолжаем с новым ts без перезапроса сервера")
    func failed1UsesNewTs() async throws {
        let http = MockHTTPClient()
        await http.setStubQueue([
            .success(VKFixtures.server(key: "K1", ts: "10")),
            .success(VKFixtures.failed(1, ts: "30")),
            .success(VKFixtures.poll(ts: "31", updates: [VKFixtures.messageNew(text: "after", fromId: 1)])),
        ])
        await http.setHangWhenExhausted(true)

        let (messages, continuation) = AsyncStream<VKMessage>.makeStream()
        let client = VKLongPollClient(groupId: 1, token: "T", httpClient: http, logger: .noop) { continuation.yield($0) }
        let loop = Task { try await client.run() }
        _ = await messages.first { _ in true }
        loop.cancel()

        let requests = await http.sentRequests
        #expect(requests.filter { $0.isGetLongPollServer }.count == 1)
        #expect(requests[2].queryValue("ts") == "30")
    }

    /// `failed:2` — истёк `key`: перезапросить `getLongPollServer`, взять новый key, `ts` сохранить.
    @Test("failed:2 — новый key через getLongPollServer, ts сохраняется")
    func failed2RefreshesKey() async throws {
        let http = MockHTTPClient()
        await http.setStubQueue([
            .success(VKFixtures.server(key: "K1", ts: "10")),
            .success(VKFixtures.poll(ts: "11")),
            .success(VKFixtures.failed(2)),
            .success(VKFixtures.server(key: "K2", ts: "99")),
            .success(VKFixtures.poll(ts: "12", updates: [VKFixtures.messageNew(text: "after", fromId: 1)])),
        ])
        await http.setHangWhenExhausted(true)

        let (messages, continuation) = AsyncStream<VKMessage>.makeStream()
        let client = VKLongPollClient(groupId: 1, token: "T", httpClient: http, logger: .noop) { continuation.yield($0) }
        let loop = Task { try await client.run() }
        _ = await messages.first { _ in true }
        loop.cancel()

        let requests = await http.sentRequests
        #expect(requests[3].isGetLongPollServer)
        #expect(requests[4].queryValue("key") == "K2")
        #expect(requests[4].queryValue("ts") == "11")
    }

    /// `failed:3` — информация потеряна: новая сессия целиком (server, key и ts из `getLongPollServer`).
    @Test("failed:3 — новая сессия: key и ts из getLongPollServer")
    func failed3RefreshesSession() async throws {
        let http = MockHTTPClient()
        await http.setStubQueue([
            .success(VKFixtures.server(key: "K1", ts: "10")),
            .success(VKFixtures.failed(3)),
            .success(VKFixtures.server(key: "K2", ts: "50")),
            .success(VKFixtures.poll(ts: "51", updates: [VKFixtures.messageNew(text: "after", fromId: 1)])),
        ])
        await http.setHangWhenExhausted(true)

        let (messages, continuation) = AsyncStream<VKMessage>.makeStream()
        let client = VKLongPollClient(groupId: 1, token: "T", httpClient: http, logger: .noop) { continuation.yield($0) }
        let loop = Task { try await client.run() }
        _ = await messages.first { _ in true }
        loop.cancel()

        let requests = await http.sentRequests
        #expect(requests[2].isGetLongPollServer)
        #expect(requests[3].queryValue("key") == "K2")
        #expect(requests[3].queryValue("ts") == "50")
    }
}

// MARK: - Сеть и ошибки VK API

extension VKLongPollClientTests {

    /// Сетевая ошибка на `a_check` — повтор с растущей задержкой (1 c, 2 c, …), сервис не падает.
    ///
    /// **HYP-057, ось «время»:** задержка внедрена функцией `sleep`, тест не ждёт реальное время —
    /// записывает запрошенные паузы и сразу возвращается.
    @Test("сетевая ошибка на a_check — повтор с задержкой 1 c, 2 c")
    func networkErrorRetriesWithBackoff() async throws {
        let http = MockHTTPClient()
        await http.setStubQueue([
            .success(VKFixtures.server(key: "K1", ts: "10")),
            .failure(URLError(.networkConnectionLost)),
            .failure(URLError(.timedOut)),
            .success(VKFixtures.poll(ts: "11", updates: [VKFixtures.messageNew(text: "after", fromId: 1)])),
        ])
        await http.setHangWhenExhausted(true)

        let sleeps = SleepRecorder()
        let (messages, continuation) = AsyncStream<VKMessage>.makeStream()
        let client = VKLongPollClient(groupId: 1, token: "T", httpClient: http, logger: .noop, sleep: sleeps.sleep) {
            continuation.yield($0)
        }
        let loop = Task { try await client.run() }
        let received = await messages.first { _ in true }
        loop.cancel()

        #expect(received?.text == "after")
        #expect(await sleeps.durations == [.seconds(1), .seconds(2)])
    }

    /// Сетевая ошибка уже на `getLongPollServer` (сервис стартовал без сети) — тоже повтор, не падение.
    @Test("сетевая ошибка на getLongPollServer при старте — повтор")
    func networkErrorOnStartRetries() async throws {
        let http = MockHTTPClient()
        await http.setStubQueue([
            .failure(URLError(.notConnectedToInternet)),
            .success(VKFixtures.server(key: "K1", ts: "10")),
            .success(VKFixtures.poll(ts: "11", updates: [VKFixtures.messageNew(text: "online", fromId: 1)])),
        ])
        await http.setHangWhenExhausted(true)

        let sleeps = SleepRecorder()
        let (messages, continuation) = AsyncStream<VKMessage>.makeStream()
        let client = VKLongPollClient(groupId: 1, token: "T", httpClient: http, logger: .noop, sleep: sleeps.sleep) {
            continuation.yield($0)
        }
        let loop = Task { try await client.run() }
        let received = await messages.first { _ in true }
        loop.cancel()

        #expect(received?.text == "online")
        #expect(await sleeps.durations == [.seconds(1)])
    }

    /// Ошибка VK API на `getLongPollServer` (неверный ключ, нет права `manage`) — постоянная:
    /// `run()` завершается ошибкой, а не крутит повторы вечно.
    @Test("ошибка VK API на getLongPollServer — run() бросает serverRequestFailed")
    func apiErrorStopsRun() async throws {
        let http = MockHTTPClient()
        await http.setStubQueue([
            .success(Data(#"{"error":{"error_code":5,"error_msg":"User authorization failed: invalid access_token (4)."}}"#.utf8)),
        ])

        let client = VKLongPollClient(groupId: 1, token: "bad", httpClient: http, logger: .noop, sleep: SleepRecorder().sleep) { _ in }

        await #expect(throws: VKLongPollError.self) { try await client.run() }
    }
}

/// Записывает запрошенные паузы, не ожидая реального времени.
actor SleepRecorder {
    private(set) var durations: [Duration] = []

    nonisolated var sleep: @Sendable (Duration) async throws -> Void {
        { [self] duration in await self.record(duration) }
    }

    private func record(_ duration: Duration) {
        durations.append(duration)
    }
}

extension URLRequest {
    var isGetLongPollServer: Bool { url?.path.hasSuffix("groups.getLongPollServer") == true }
}

extension URLRequest {
    func queryValue(_ name: String) -> String? {
        url.flatMap { URLComponents(url: $0, resolvingAgainstBaseURL: false) }?.queryItems?.first { $0.name == name }?.value
    }
}

// MARK: - Fixtures

/// Ответы VK в том виде, как их вернул реальный API в spike v0.5.0.
enum VKFixtures {
    static func server(key: String, ts: String) -> Data {
        Data(#"{"response":{"key":"\#(key)","server":"https://lp.vk.com/whp/242065128","ts":"\#(ts)"}}"#.utf8)
    }

    static func poll(ts: String, updates: [String] = []) -> Data {
        Data(#"{"ts":"\#(ts)","updates":[\#(updates.joined(separator: ","))]}"#.utf8)
    }

    static func failed(_ code: Int, ts: String? = nil) -> Data {
        Data((ts.map { #"{"failed":\#(code),"ts":"\#($0)"}"# } ?? #"{"failed":\#(code)}"#).utf8)
    }

    /// Урезанный реальный `message_new` (полный — `spikes/vk-longpoll/fixtures/message_new.json`).
    static func messageNew(text: String, fromId: Int64, peerId: Int64? = nil, id: Int64 = 2) -> String {
        #"""
        {"group_id":242065128,"type":"message_new","event_id":"bd690001a7fabf1858605dcc81912fed07570ffb","v":"5.199",
         "object":{"client_info":{"keyboard":true,"inline_keyboard":true,"lang_id":0},
          "message":{"date":1791298667,"from_id":\#(fromId),"id":\#(id),"version":10000005,"out":0,"fwd_messages":[],
           "important":false,"is_hidden":false,"attachments":[],"conversation_message_id":\#(id),
           "text":"\#(text)","peer_id":\#(peerId ?? fromId),"random_id":0}}}
        """#
    }
}

extension Logger {
    static let noop = Logger(label: "test") { _ in SwiftLogNoOpLogHandler() }
}
