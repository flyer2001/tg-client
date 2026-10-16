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

    /// Форум (чат с темами): у каждой темы своя граница прочитанного (спайк 2026-10-16). Сбор — по темам
    /// с непрочитанным, только сообщения новее `last_read` темы; курсор — запись на тему.
    @Test("форум: сообщения тем с непрочитанным, у сообщения тема; курсор — запись на тему; прочитанное не попадает")
    func collectsForumByTopics() async throws {
        let tg = TDLibScenario()
        tg.givenForum(500, title: "Podlodka AI Crew", topics: [
            .init(id: 1, name: "General", unread: 1, lastRead: 10, history: [.text(10, "уже прочитано"), .text(12, "новое")]),
            .init(id: 7, name: "Sharing", unread: 2, lastRead: 20, history: [.text(21, "ссылка"), .photo(23)]),
            .init(id: 9, name: "Pains", unread: 0, lastRead: 30, history: [.text(30, "прочитано")]),
        ])

        let snapshot = try await tg.makeCollector().collect(now: now)

        let chat = try #require(snapshot.chats.first)
        #expect(chat.kind == .group)
        #expect(chat.unreadCount == 3)
        #expect(chat.messages == [SummaryMessage(messageId: 12, text: "новое", topic: SummaryTopic(id: 1, name: "General")),
                                  SummaryMessage(messageId: 21, text: "ссылка", topic: SummaryTopic(id: 7, name: "Sharing"))])
        #expect(chat.lastMessageId == 23)
        #expect(snapshot.cursor == [CursorEntry(chatId: 500, upToMessageId: 12, forumTopicId: 1),
                                    CursorEntry(chatId: 500, upToMessageId: 23, forumTopicId: 7)])
        tg.expectNothingViewed()
    }

    /// Счётчики TDLib отстают (спайк 2026-10-16: чатовый unread обновился не сразу). Если `unread` темы больше,
    /// чем реально новых сообщений, прочитанные (до `last_read` темы) в сводку не попадают.
    @Test("форум: счётчик темы отстаёт (unread 2, новое одно) → прочитанное не попадает")
    func forumStaleUnreadCount() async throws {
        let tg = TDLibScenario()
        tg.givenForum(500, topics: [.init(id: 1, name: "General", unread: 2, lastRead: 10,
                                          history: [.text(10, "уже прочитано"), .text(12, "новое")])])

        let snapshot = try await tg.makeCollector().collect(now: now)

        #expect(snapshot.chats.first?.messages.map(\.messageId) == [12])
        #expect(snapshot.cursor == [CursorEntry(chatId: 500, upToMessageId: 12, forumTopicId: 1)])
    }

    /// E2E 2026-10-16: после пометки тем чатовый `unread_count` форума ещё ~минуту показывает старое (8),
    /// а у тем непрочитанного уже нет. Правда — в темах: пустой форум в сводку не попадает.
    @Test("форум: у тем непрочитанного нет, чатовый счётчик отстаёт → форума нет в сводке")
    func forumWithoutUnreadTopicsIsSkipped() async throws {
        let tg = TDLibScenario()
        tg.givenForum(500, chatUnread: 8, topics: [.init(id: 1, name: "General", unread: 0, lastRead: 12, history: [.text(12, "прочитано")])])
        tg.givenChat(123, unread: 1)
        tg.givenHistory(123, [.text(101, "Hi")])

        let snapshot = try await tg.makeCollector().collect(now: now)

        #expect(snapshot.chats.map(\.chatId) == [123])
        #expect(snapshot.cursor == [CursorEntry(chatId: 123, upToMessageId: 101)])
    }

    @Test("обычная группа (не форум) → сбор как раньше, курсор без темы")
    func plainGroupIsNotForum() async throws {
        let tg = TDLibScenario()
        tg.givenChat(600, title: "Team", kind: .group, unread: 1)
        tg.givenHistory(600, [.text(41, "привет")])

        let snapshot = try await tg.makeCollector().collect(now: now)

        #expect(snapshot.chats.first?.messages == [SummaryMessage(messageId: 41, text: "привет")])
        #expect(snapshot.cursor == [CursorEntry(chatId: 600, upToMessageId: 41)])
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
