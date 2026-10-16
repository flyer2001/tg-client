import TgClientModels
import TGClientInterfaces
import Foundation
import Testing
@testable import DigestCore
@testable import TestHelpers
import CustomDump

/// Component тесты `Broker` — обработка запросов CLI к службе через сокет (<doc:GetSummary>, вариант (b)).
///
/// **User Story:** агент зовёт `get-summary`/`read`, служба моста не останавливается: служба — единственный
/// владелец сессии TDLib, CLI шлёт ей одну JSON-строку запроса и получает одну JSON-строку ответа.
///
/// **Классы операций:** разрешены только R0 (`get-summary`) и R1 (`read`); всё остальное — отказ.
///
/// **Подменено:** FFI TDLib — `TDLibScenario`; логика сбора/пометки — настоящая. Запрос в брокер — сырая
/// JSON-строка: это и есть протокол сокета.
@Suite("Broker: запросы CLI к службе (R0/R1)", .timeLimit(.minutes(1)))
struct BrokerTests {

    @Test("get-summary → ok + снапшот с курсором, viewMessages НЕ зовётся")
    func getSummary() async throws {
        let tg = TDLibScenario()
        tg.givenChat(123, title: "Tech", unread: 1)
        tg.givenHistory(123, [.text(101, "Hi")])

        let response = try await request(tg, #"{"op":"get-summary"}"#, as: SummarySnapshot.self)

        let snapshot = try #require(response.result)
        #expect(snapshot.chats.map(\.chatId) == [123])
        #expect(snapshot.cursor == [CursorEntry(chatId: 123, upToMessageId: 101)])
        tg.expectNothingViewed()
    }

    @Test("read → ok + отчёт по чатам, viewMessages до up_to_message_id")
    func read() async throws {
        let tg = TDLibScenario()
        tg.givenMarkAsReadSucceeds()

        let response = try await request(tg, #"{"op":"read","cursor":[{"chat_id":123,"up_to_message_id":105}]}"#, as: ReadReport.self)

        expectNoDifference(response.result, ReadReport(marked: 1, chats: [ReadReport.Chat(chatId: 123, ok: true, error: nil)]))
        tg.expectViewed([123: [105]])
    }

    @Test("read без cursor → schema_validation, TDLib не трогаем")
    func readWithoutCursor() async throws {
        let tg = TDLibScenario()

        let response = try await request(tg, #"{"op":"read"}"#, as: ReadReport.self)

        expectError(response, type: "schema_validation", field: "cursor")
        tg.expectNothingViewed()
    }

    @Test("op вне R0/R1 (send) → permission_denied")
    func forbiddenOp() async throws {
        let response = try await request(TDLibScenario(), #"{"op":"send","text":"x"}"#, as: ReadReport.self)

        expectError(response, type: "permission_denied", field: "op")
    }

    @Test("битый JSON → parse_error")
    func malformed() async throws {
        let response = try await request(TDLibScenario(), "not json", as: ReadReport.self)

        expectError(response, type: "parse_error", field: nil)
    }

    // MARK: - DSL

    private func request<T: Codable>(_ tg: TDLibScenario, _ line: String, as: T.Type) async throws -> BrokerResponse<T> {
        let raw = await tg.makeBroker().handle(Data(line.utf8))
        return try JSONDecoder.broker().decode(BrokerResponse<T>.self, from: raw)
    }

    private func expectError<T>(_ response: BrokerResponse<T>, type: String, field: String?,
                                sourceLocation: SourceLocation = #_sourceLocation) {
        #expect(!response.ok, sourceLocation: sourceLocation)
        #expect(response.error?.errorType == type, sourceLocation: sourceLocation)
        #expect(response.error?.field == field, sourceLocation: sourceLocation)
    }
}
