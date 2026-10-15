import TgClientModels
import TGClientInterfaces
import Foundation
import Testing
import Logging
@testable import TDLibAdapter
@testable import DigestCore
@testable import TestHelpers

/// Component тесты `Broker` — обработка запросов CLI к службе через сокет (<doc:GetSummary>, вариант (b)).
///
/// **User Story:** агент зовёт `get-summary`/`read`, служба моста не останавливается: служба — единственный
/// владелец сессии TDLib, CLI шлёт ей одну JSON-строку запроса и получает одну JSON-строку ответа.
///
/// **Классы операций:** разрешены только R0 (`get-summary`) и R1 (`read`); всё остальное — отказ.
///
/// **Mock:** `MockTDLibFFI` (boundary), логика сбора/пометки — реальная.
@Suite("Broker: запросы CLI к службе (R0/R1)", .timeLimit(.minutes(1)))
struct BrokerTests {

    private func makeBroker(_ ffi: MockTDLibFFI) -> Broker {
        let logger = Logger(label: "test") { _ in SwiftLogNoOpLogHandler() }
        let client = TDLibClient(ffi: ffi, appLogger: logger, authorizationPollTimeout: 0.1, maxAuthorizationAttempts: 10, authorizationTimeout: 5)
        client.startUpdatesLoop()
        let source = ChannelMessageSource(tdlib: client, logger: logger, loadChatsPaginationDelay: .milliseconds(1), updatesCollectionTimeout: .milliseconds(20), maxParallelHistoryRequests: 5, maxLoadChatsBatches: 5)
        return Broker(source: source, markAsRead: MarkAsReadService(tdlib: client, logger: logger), logger: logger)
    }

    private func json(_ data: Data) throws -> [String: Any] {
        try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
    }

    @Test("get-summary → ok + снапшот с курсором, viewMessages НЕ зовётся")
    func getSummary() async throws {
        let ffi = MockTDLibFFI()
        ffi.queueUpdate(.newChat(chat: ChatResponse(id: 123, type: .supergroup(supergroupId: 123, isChannel: true), title: "Tech", unreadCount: 1, lastReadInboxMessageId: 0)))
        ffi.queueUpdate(.chatPosition(chatId: 123, position: ChatPosition(list: .main, order: 1123, isPinned: false)))
        ffi.mockResponse(forRequestType: "getChatHistory", return: .success(MessagesResponse(totalCount: 1, messages: [
            TgClientModels.Message(id: 101, chatId: 123, date: 1, content: .text(FormattedText(text: "Hi", entities: nil))),
        ])))

        let response = await makeBroker(ffi).handle(Data(#"{"op":"get-summary"}"#.utf8))

        let envelope = try JSONDecoder.broker().decode(BrokerResponse<SummarySnapshot>.self, from: response)
        #expect(envelope.ok)
        let snapshot = try #require(envelope.result)
        #expect(snapshot.chats.map(\.chatId) == [123])
        #expect(snapshot.cursor == [CursorEntry(chatId: 123, upToMessageId: 101)])
        #expect(ffi.sentRequests(ofType: "viewMessages").isEmpty)
    }

    @Test("read → ok + отчёт по чатам, viewMessages до up_to_message_id")
    func read() async throws {
        let ffi = MockTDLibFFI()
        ffi.mockResponse(forRequestType: "viewMessages", return: .success(OkResponse()))

        let response = await makeBroker(ffi).handle(Data(#"{"op":"read","cursor":[{"chat_id":123,"up_to_message_id":105}]}"#.utf8))

        let envelope = try JSONDecoder.broker().decode(BrokerResponse<ReadReport>.self, from: response)
        #expect(envelope.ok)
        #expect(envelope.result == ReadReport(marked: 1, chats: [ReadReport.Chat(chatId: 123, ok: true, error: nil)]))
        let sent = try #require(ffi.sentRequests(ofType: "viewMessages").first)
        #expect(sent["chat_id"] as? Int64 == 123)
        #expect((sent["message_ids"] as? [NSNumber])?.map(\.int64Value) == [105])
    }

    @Test("read без cursor → schema_validation, TDLib не трогаем")
    func readWithoutCursor() async throws {
        let ffi = MockTDLibFFI()
        let out = try json(await makeBroker(ffi).handle(Data(#"{"op":"read"}"#.utf8)))
        #expect(out["ok"] as? Bool == false)
        #expect((out["error"] as? [String: Any])?["error_type"] as? String == "schema_validation")
        #expect(ffi.sentRequests(ofType: "viewMessages").isEmpty)
    }

    @Test("op вне R0/R1 (send) → permission_denied")
    func forbiddenOp() async throws {
        let out = try json(await makeBroker(MockTDLibFFI()).handle(Data(#"{"op":"send","text":"x"}"#.utf8)))
        #expect(out["ok"] as? Bool == false)
        let error = try #require(out["error"] as? [String: Any])
        #expect(error["error_type"] as? String == "permission_denied")
        #expect(error["field"] as? String == "op")
    }

    @Test("битый JSON → parse_error")
    func malformed() async throws {
        let out = try json(await makeBroker(MockTDLibFFI()).handle(Data("not json".utf8)))
        #expect(out["ok"] as? Bool == false)
        #expect((out["error"] as? [String: Any])?["error_type"] as? String == "parse_error")
    }
}
