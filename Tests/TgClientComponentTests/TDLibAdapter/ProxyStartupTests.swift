import TgClientModels
import TGClientInterfaces
import Foundation
import Testing
import Logging
@testable import TDLibAdapter
@testable import TestHelpers

/// Component тест: `TDLibClient.start` включает прокси, если он задан в `TDConfig`.
///
/// **Контракт:** `addProxy` уходит сразу после `setTdlibParameters` (TDLib: «Can be called before authorization»),
/// до запроса номера — иначе TDLib не дойдёт до серверов и авторизация зависнет (симптом из России).
///
/// **Mock:** `MockTDLibFFI` — эмитим `authorizationStateWaitTdlibParameters`, затем `authorizationStateReady`.
/// См. <doc:AddProxyRequestTests>.
@Suite("TDLibClient.start: прокси", .serialized, .timeLimit(.minutes(1)))
struct ProxyStartupTests {

    @Test("прокси в конфиге → addProxy после setTdlibParameters")
    func addsProxyAfterParameters() async throws {
        let ffi = try await startClient(proxy: TDProxy(server: "127.0.0.1", port: 1080))

        let types = ffi.sentRequestTypes()
        let params = types.firstIndex(of: "setTdlibParameters")
        let proxy = types.firstIndex(of: "addProxy")
        #expect(params != nil && proxy != nil)
        if let params, let proxy { #expect(params < proxy) }
        let sent = ffi.sentRequests(ofType: "addProxy").first?["proxy"] as? [String: Any]
        #expect(sent?["server"] as? String == "127.0.0.1")
        #expect(sent?["port"] as? Int == 1080)
    }

    @Test("без прокси → addProxy не отправляется")
    func noProxyNoRequest() async throws {
        let ffi = try await startClient(proxy: nil)
        #expect(ffi.sentRequests(ofType: "addProxy").isEmpty)
    }

    /// Оба состояния подаются заранее: ранний `updateAuthorizationState` буферизуется в `ResponseWaiters`
    /// (до фикса 2026-10-07 терялся, и `start()` висел — этот тест был бы вечным).
    private func startClient(proxy: TDProxy?) async throws -> MockTDLibFFI {
        let ffi = MockTDLibFFI()
        let client = TDLibClient(ffi: ffi, appLogger: Logger(label: "test") { _ in SwiftLogNoOpLogHandler() })
        ffi.mockUpdate(AuthorizationStateUpdateResponse(authorizationState: AuthorizationStateInfo(type: "authorizationStateWaitTdlibParameters")))
        ffi.mockUpdate(AuthorizationStateUpdateResponse.ready)
        let config = TDConfig(apiId: 1, apiHash: "h", stateDir: NSTemporaryDirectory() + "proxy-test", logPath: "/dev/null", proxy: proxy)
        try await client.start(config: config) { _ in "" }
        return ffi
    }
}
