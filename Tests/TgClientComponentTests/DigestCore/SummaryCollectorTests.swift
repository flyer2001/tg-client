import TgClientModels
import TGClientInterfaces
import Foundation
import Testing
@testable import DigestCore
@testable import TestHelpers

/// Component тесты `SummaryCollector` — сбор непрочитанного в снапшот + курсор (<doc:GetSummary>).
///
/// **User Story:** <doc:GetSummary> — `get-summary` собирает данные, курсор помечает собранный диапазон,
/// **состояние не меняется** (не вызывает `viewMessages`).
///
/// **Подменено:** FFI TDLib — `TDLibScenario` (DSL над `MockTDLibFFI`), сбор — настоящий.
@Suite("SummaryCollector: сбор снапшота непрочитанного", .timeLimit(.minutes(1)))
struct SummaryCollectorTests {

    private let now = Date(timeIntervalSince1970: 1_700_000_000)

    @Test("собирает чат с сообщениями, курсор = последний message_id, viewMessages НЕ зовётся")
    func collectsSnapshotWithCursor() async throws {
        let tg = TDLibScenario()
        tg.givenChat(123, title: "Tech News", kind: .channel, unread: 2)
        tg.givenHistory(123, [.text(101, "First"), .text(102, "Second")])

        let snapshot = try await tg.makeCollector().collect(now: now)

        #expect(snapshot.chats == [SummaryChat(chatId: 123, title: "Tech News", kind: .channel, unreadCount: 2,
                                               messages: [SummaryMessage(messageId: 101, text: "First"),
                                                          SummaryMessage(messageId: 102, text: "Second")],
                                               lastMessageId: 102)])
        #expect(snapshot.cursor == [CursorEntry(chatId: 123, upToMessageId: 102)])
        tg.expectNothingViewed()
    }

    /// Регрессия E2E 2026-10-15: канал, где непрочитанное — фото без подписи. Текста нет, но курсор обязан
    /// дойти до этого сообщения, иначе `read` метит до старого last_read и чат остаётся непрочитанным навсегда.
    @Test("непрочитанное без текста (фото) → messages пусто, курсор = id этого сообщения")
    func cursorCoversNonTextMessages() async throws {
        let tg = TDLibScenario()
        tg.givenChat(321, title: "Broadcast", unread: 1, lastRead: 200)
        tg.givenHistory(321, [.photo(205)])

        let snapshot = try await tg.makeCollector().collect(now: now)

        let chat = try #require(snapshot.chats.first)
        #expect(chat.messages.isEmpty)
        #expect(chat.lastMessageId == 205)
        #expect(snapshot.cursor == [CursorEntry(chatId: 321, upToMessageId: 205)])
    }

    @Test("нет непрочитанных → пустой снапшот и пустой курсор")
    func emptyWhenNoUnread() async throws {
        let tg = TDLibScenario()

        let snapshot = try await tg.makeCollector().collect(now: now)

        #expect(snapshot.chats.isEmpty)
        #expect(snapshot.cursor.isEmpty)
    }

    /// Контракт вывода для агента: ровно этот JSON (snake_case, ISO-8601, ключи по алфавиту).
    @Test("снапшот сериализуется в snake_case JSON")
    func encodesSnakeCase() throws {
        let snap = SummarySnapshot(collectedAt: now,
                                   chats: [SummaryChat(chatId: 123, title: "T", kind: .channel, unreadCount: 2,
                                                       messages: [SummaryMessage(messageId: 101, text: "x")], lastMessageId: 101)],
                                   cursor: [CursorEntry(chatId: 123, upToMessageId: 101)])

        let json = String(decoding: try SummarySnapshot.encoder().encode(snap), as: UTF8.self)

        #expect(json == #"{"chats":[{"chat_id":123,"kind":"channel","last_message_id":101,"messages":[{"message_id":101,"text":"x"}],"title":"T","unread_count":2}],"collected_at":"2023-11-14T22:13:20Z","cursor":[{"chat_id":123,"up_to_message_id":101}]}"#)
    }
}
