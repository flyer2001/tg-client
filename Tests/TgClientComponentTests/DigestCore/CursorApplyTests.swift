import TgClientModels
import TGClientInterfaces
import Foundation
import Testing
import Logging
@testable import TDLibAdapter
@testable import DigestCore
@testable import TestHelpers

/// Component/Unit: применение курсора (<doc:GetSummary>, шаг `read`).
/// Курсор метит `viewMessages` до `up_to_message_id` на чат; частичный отказ не валит остальные.
@Suite("Cursor: разбор и применение (read)", .timeLimit(.minutes(1)))
struct CursorApplyTests {

    // Unit: разбор курсора из JSON (файл / --cursor)
    @Test("parse: snake_case JSON курсора → [CursorEntry]")
    func parseCursor() throws {
        let data = Data(#"[{"chat_id":123,"up_to_message_id":105},{"chat_id":-7,"up_to_message_id":9}]"#.utf8)
        let cursor = try Cursor.parse(data)
        #expect(cursor == [CursorEntry(chatId: 123, upToMessageId: 105), CursorEntry(chatId: -7, upToMessageId: 9)])
    }

    @Test("parse: пустой список")
    func parseEmpty() throws {
        #expect(try Cursor.parse(Data("[]".utf8)) == [])
    }

    // Component: применение через MarkAsReadService (MockTDLibFFI)
    @Test("apply: viewMessages до up_to_message_id на каждый чат")
    func applyMarksUpToCursor() async throws {
        let ffi = MockTDLibFFI()
        ffi.mockResponse(forRequestType: "viewMessages", return: .success(OkResponse()))
        ffi.mockResponse(forRequestType: "viewMessages", return: .success(OkResponse()))
        let logger = Logger(label: "test") { _ in SwiftLogNoOpLogHandler() }
        let tdlib = TDLibClient(ffi: ffi, appLogger: logger)
        tdlib.startUpdatesLoop()
        let service = MarkAsReadService(tdlib: tdlib, logger: logger)

        let results = await Cursor.apply([CursorEntry(chatId: 123, upToMessageId: 105), CursorEntry(chatId: 77, upToMessageId: 9)], using: service)

        #expect(results.count == 2)
        #expect(results.values.allSatisfy { if case .success = $0 { return true } else { return false } })
        let sent = ffi.sentRequests(ofType: "viewMessages")
        let byChat = Dictionary(uniqueKeysWithValues: sent.map { ($0["chat_id"] as! Int64, ($0["message_ids"] as! [NSNumber]).map(\.int64Value)) })
        #expect(byChat[123] == [105])
        #expect(byChat[77] == [9])
    }

    @Test("apply: пустой курсор → пусто, VK/TG не трогаем")
    func applyEmpty() async throws {
        let ffi = MockTDLibFFI()
        let logger = Logger(label: "test") { _ in SwiftLogNoOpLogHandler() }
        let tdlib = TDLibClient(ffi: ffi, appLogger: logger)
        tdlib.startUpdatesLoop()
        let results = await Cursor.apply([], using: MarkAsReadService(tdlib: tdlib, logger: logger))
        #expect(results.isEmpty)
        #expect(ffi.sentRequests(ofType: "viewMessages").isEmpty)
    }
}
