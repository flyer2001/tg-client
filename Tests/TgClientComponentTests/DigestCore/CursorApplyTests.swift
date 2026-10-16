import TgClientModels
import TGClientInterfaces
import Foundation
import Testing
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

        #expect(try Cursor.parse(data) == [CursorEntry(chatId: 123, upToMessageId: 105), CursorEntry(chatId: -7, upToMessageId: 9)])
    }

    @Test("parse: запись темы форума — forum_topic_id")
    func parseForumTopic() throws {
        let data = Data(#"[{"chat_id":-5,"forum_topic_id":7,"up_to_message_id":23}]"#.utf8)

        #expect(try Cursor.parse(data) == [CursorEntry(chatId: -5, upToMessageId: 23, forumTopicId: 7)])
    }

    @Test("parse: пустой список")
    func parseEmpty() throws {
        #expect(try Cursor.parse(Data("[]".utf8)) == [])
    }

    // Component: применение через MarkAsReadService (TDLibScenario)
    @Test("apply: viewMessages до up_to_message_id на каждый чат")
    func applyMarksUpToCursor() async throws {
        let tg = TDLibScenario()
        tg.givenMarkAsReadSucceeds(times: 2)

        let results = await Cursor.apply([CursorEntry(chatId: 123, upToMessageId: 105), CursorEntry(chatId: 77, upToMessageId: 9)],
                                         using: tg.markAsRead)

        #expect(ReadReport(results) == ReadReport(marked: 2, chats: [ReadReport.Chat(chatId: 77, ok: true, error: nil),
                                                                     ReadReport.Chat(chatId: 123, ok: true, error: nil)]))
        tg.expectViewed([123: [105], 77: [9]])
    }

    /// Тема форума метится `viewMessages` с источником темы (спайк 2026-10-16: метит ровно эту тему).
    @Test("apply: запись темы → viewMessages с источником темы; обычная — без источника; отчёт по темам")
    func applyForumTopics() async throws {
        let tg = TDLibScenario()
        tg.givenMarkAsReadSucceeds(times: 3)

        let results = await Cursor.apply([CursorEntry(chatId: 500, upToMessageId: 12, forumTopicId: 1),
                                          CursorEntry(chatId: 500, upToMessageId: 23, forumTopicId: 7),
                                          CursorEntry(chatId: 77, upToMessageId: 9)], using: tg.markAsRead)

        #expect(ReadReport(results) == ReadReport(marked: 3, chats: [ReadReport.Chat(chatId: 77, ok: true, error: nil),
                                                                     ReadReport.Chat(chatId: 500, forumTopicId: 1, ok: true, error: nil),
                                                                     ReadReport.Chat(chatId: 500, forumTopicId: 7, ok: true, error: nil)]))
        tg.expectViewed([77: [9]])
        tg.expectViewedInTopics([500: [12, 23]])
    }

    @Test("apply: пустой курсор → пусто, TDLib не трогаем")
    func applyEmpty() async throws {
        let tg = TDLibScenario()

        let results = await Cursor.apply([], using: tg.markAsRead)

        #expect(results.isEmpty)
        tg.expectNothingViewed()
    }
}
