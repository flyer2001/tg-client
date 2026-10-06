import Foundation
import Testing
import Logging
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
@testable import BotBridge
@testable import DigestCore
@testable import TDLibAdapter
@testable import TestHelpers

/// Component тест защиты `CommandProcessor` от параллельных команд (флаг `isBusy`).
///
/// **User Story:** <doc:VKBridge> — «любая команда, пока предыдущая ещё выполняется → `⚠️ Уже обрабатываю…`».
///
/// **Почему гонка реальна:** `CommandProcessor` — actor, но actor **реентерабелен**: пока первая команда ждёт
/// сеть (`await` внутри `handle`), в actor входит вторая. Без `isBusy` обе выполнялись бы одновременно
/// (два `/digest` параллельно дёргают TDLib и путают меню в `BotSessionState`).
///
/// **Детерминизм без `sleep` (HYP-057, «шпион и затвор»):** `GatedHTTPClient` держит первый запрос к VK
/// до явного сигнала теста. Пока первая команда стоит на затворе — точно известно, что она «в процессе».
///
/// Характеризующий тест (код spike написан до теста — с разрешения владельца, v0.5.0).
/// Проверка силы теста — мутация: убрать `isBusy` → тест обязан упасть (HYP-057, эксперимент 2).
@Suite("CommandProcessor: одна команда за раз", .timeLimit(.minutes(1)))
struct CommandProcessorConcurrencyTests {

    @Test("вторая команда во время выполнения первой → «Уже обрабатываю»")
    func secondCommandWhileBusyIsRejected() async throws {
        let http = GatedHTTPClient()
        let processor = makeProcessor(http: http, owner: 1)

        // Первая команда: доходит до ответа в VK и встаёт на затворе
        let first = Task { await processor.handle(message: .owner(1, text: "/test")) }
        await http.waitForFirstRequest()

        // Вторая команда, пока первая «в процессе»
        await processor.handle(message: .owner(1, text: "/test"))

        await http.openGate()
        await first.value

        let texts = await http.sentTexts
        #expect(texts.count == 2)
        #expect(texts.filter { $0.contains("Уже обрабатываю") }.count == 1, "Ожидали ровно один отказ «занят», получили: \(texts.map { $0.prefix(30) })")
        #expect(texts.filter { $0.contains("alive") }.count == 1)
    }

    static func makeProcessorForExperiment(http: GatedHTTPClient) -> CommandProcessor {
        CommandProcessorConcurrencyTests().makeProcessor(http: http, owner: 1)
    }

    private func makeProcessor(http: GatedHTTPClient, owner: Int) -> CommandProcessor {
        let tdlib = TDLibClient(ffi: MockTDLibFFI(), appLogger: .noop)  // /test не обращается к TDLib
        return CommandProcessor(
            messageSource: ChannelMessageSource(tdlib: tdlib, logger: .noop),
            tdlib: tdlib,
            vkClient: VKAPIClient(token: "T", httpClient: http, logger: .noop),
            allowedOwners: [owner],
            logger: .noop
        )
    }
}

extension VKMessage {
    static func owner(_ id: Int64, text: String) -> VKMessage {
        VKMessage(id: 1, date: 0, peerId: id, fromId: id, text: text)
    }
}

/// HTTP-шпион с затвором: **первый** запрос ждёт `openGate()`, остальные отвечают сразу.
/// Отвечает как `messages.send`: `{"response": <id>}`; запоминает тексты отправленных сообщений.
actor GatedHTTPClient: HTTPClientProtocol {
    private(set) var sentTexts: [String] = []
    private var gateOpen = false
    private var gateWaiters: [CheckedContinuation<Void, Never>] = []
    private var firstRequestWaiters: [CheckedContinuation<Void, Never>] = []
    private var requestCount = 0

    func send(request: URLRequest) async throws -> Data {
        requestCount += 1
        let isFirst = requestCount == 1
        let text = request.formValue("message") ?? ""
        if isFirst {
            firstRequestWaiters.forEach { $0.resume() }
            firstRequestWaiters.removeAll()
            if !gateOpen { await withCheckedContinuation { gateWaiters.append($0) } }
        }
        sentTexts.append(text)
        return Data(#"{"response":\#(requestCount)}"#.utf8)
    }

    func waitForFirstRequest() async {
        if requestCount > 0 { return }
        await withCheckedContinuation { firstRequestWaiters.append($0) }
    }

    func openGate() {
        gateOpen = true
        gateWaiters.forEach { $0.resume() }
        gateWaiters.removeAll()
    }
}

extension URLRequest {
    /// Значение поля из тела `application/x-www-form-urlencoded`.
    func formValue(_ name: String) -> String? {
        guard let body = httpBody, let string = String(data: body, encoding: .utf8) else { return nil }
        return URLComponents(string: "?" + string)?.queryItems?.first { $0.name == name }?.value
    }
}
