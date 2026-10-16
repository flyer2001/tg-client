import TgClientModels
import TGClientInterfaces
import Foundation
import Testing
import Logging
@testable import TDLibAdapter
@testable import DigestCore
@testable import TestHelpers
#if os(Linux)
import FoundationNetworking
#endif

/// Незастабленный вызов фейка роняет **тест на строке создания фейка**, а не весь процесс (`fatalError`).
///
/// **Зачем:** забытый стаб — частая ошибка при написании теста. Раньше `fatalError` валил прогон целиком
/// (все остальные тесты не выполнялись), и место ошибки было внутри хелпера. Теперь — issue с именем запроса
/// на строке теста, клиент получает ошибку, тест завершается сам (testing-v1-plan.md, И2).
@Suite("Даблы: незастабленный вызов падает на строке теста", .timeLimit(.minutes(1)))
struct UnstubbedCallTests {

    @Test("MockTDLibFFI: запрос без стаба → issue на строке фейка + TDLib-ошибка клиенту")
    func tdlibUnstubbedRequest() async {
        let ffi = MockTDLibFFI(); let fakeLine = #line
        let client = TDLibClient(ffi: ffi, appLogger: Logger(label: "test") { _ in SwiftLogNoOpLogHandler() })
        client.startUpdatesLoop()

        await withKnownIssue {
            await #expect(throws: TDLibErrorResponse.self) { try await client.getMe() }
        } matching: { issue in
            issue.sourceLocation?.line == fakeLine && "\(issue)".contains("getMe")
        }
    }

    @Test("MockHTTPClient: send без стаба → issue на строке стаба + ошибка клиенту")
    func httpUnstubbedSend() async {
        let http = MockHTTPClient(); let stubLine = #line
        let request = URLRequest(url: URL(string: "https://example.com/x")!)

        await withKnownIssue {
            await #expect(throws: (any Error).self) { try await http.send(request: request) }
        } matching: { issue in
            issue.sourceLocation?.line == stubLine && "\(issue)".contains("example.com")
        }
    }
}
