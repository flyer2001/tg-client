import TgClientModels
import TGClientInterfaces
import Foundation
import Testing
import Logging
@testable import TDLibAdapter
@testable import DigestCore
@testable import TestHelpers

/// Component тесты `SummaryCollector` — сбор непрочитанного в снапшот + курсор (<doc:GetSummary>).
///
/// **User Story:** <doc:GetSummary> — `get-summary` собирает данные, курсор помечает собранный диапазон,
/// **состояние не меняется** (не вызывает `viewMessages`).
///
/// **Mock:** `MockTDLibFFI` — чаты приходят updates, `getChatHistory` отдаёт замоканные сообщения.
@Suite("SummaryCollector: сбор снапшота непрочитанного", .timeLimit(.minutes(1)))
struct SummaryCollectorTests {

    private func makeSource(_ ffi: MockTDLibFFI) -> ChannelMessageSource {
        let logger = Logger(label: "test") { _ in SwiftLogNoOpLogHandler() }
        let client = TDLibClient(ffi: ffi, appLogger: logger, authorizationPollTimeout: 0.1, maxAuthorizationAttempts: 10, authorizationTimeout: 5)
        client.startUpdatesLoop()
        return ChannelMessageSource(tdlib: client, logger: logger, loadChatsPaginationDelay: .milliseconds(1), updatesCollectionTimeout: .milliseconds(20), maxParallelHistoryRequests: 5, maxLoadChatsBatches: 5)
    }

    private func addChat(_ ffi: MockTDLibFFI, id: Int64, title: String, isChannel: Bool, unread: Int32) {
        ffi.queueUpdate(.newChat(chat: ChatResponse(id: id, type: .supergroup(supergroupId: id, isChannel: isChannel), title: title, unreadCount: unread, lastReadInboxMessageId: 0)))
        ffi.queueUpdate(.chatPosition(chatId: id, position: ChatPosition(list: .main, order: 1000 + id, isPinned: false)))
    }

    @Test("собирает чат с сообщениями, курсор = последний message_id, viewMessages НЕ зовётся")
    func collectsSnapshotWithCursor() async throws {
        let ffi = MockTDLibFFI()
        addChat(ffi, id: 123, title: "Tech News", isChannel: true, unread: 2)
        ffi.mockResponse(forRequestType: "getChatHistory", return: .success(MessagesResponse(totalCount: 2, messages: [
            TgClientModels.Message(id: 102, chatId: 123, date: 2, content: .text(FormattedText(text: "Second", entities: nil))),
            TgClientModels.Message(id: 101, chatId: 123, date: 1, content: .text(FormattedText(text: "First", entities: nil))),
        ])))

        let snapshot = try await SummaryCollector(source: makeSource(ffi)).collect(now: Date(timeIntervalSince1970: 1_700_000_000))

        #expect(snapshot.chats.count == 1)
        let chat = try #require(snapshot.chats.first)
        #expect(chat.chatId == 123)
        #expect(chat.title == "Tech News")
        #expect(chat.kind == .channel)
        #expect(chat.unreadCount == 2)
        #expect(chat.messages.map(\.text) == ["First", "Second"])   // oldest→newest
        #expect(chat.lastMessageId == 102)
        #expect(snapshot.cursor == [CursorEntry(chatId: 123, upToMessageId: 102)])

        // состояние не трогаем
        #expect(ffi.sentRequests(ofType: "viewMessages").isEmpty)
    }

    /// Регрессия E2E 2026-10-15: канал, где непрочитанное — фото без подписи. Текста нет, но курсор обязан
    /// дойти до этого сообщения, иначе `read` метит до старого last_read и чат остаётся непрочитанным навсегда.
    @Test("непрочитанное без текста (фото) → messages пусто, курсор = id этого сообщения")
    func cursorCoversNonTextMessages() async throws {
        let ffi = MockTDLibFFI()
        ffi.queueUpdate(.newChat(chat: ChatResponse(id: 321, type: .supergroup(supergroupId: 321, isChannel: true), title: "Broadcast", unreadCount: 1, lastReadInboxMessageId: 200)))
        ffi.queueUpdate(.chatPosition(chatId: 321, position: ChatPosition(list: .main, order: 1321, isPinned: false)))
        ffi.mockResponse(forRequestType: "getChatHistory", return: .success(MessagesResponse(totalCount: 1, messages: [
            TgClientModels.Message(id: 205, chatId: 321, date: 5, content: .photo(caption: nil)),
        ])))

        let snapshot = try await SummaryCollector(source: makeSource(ffi)).collect(now: Date(timeIntervalSince1970: 1_700_000_000))

        let chat = try #require(snapshot.chats.first)
        #expect(chat.messages.isEmpty)
        #expect(chat.lastMessageId == 205)
        #expect(snapshot.cursor == [CursorEntry(chatId: 321, upToMessageId: 205)])
    }

    @Test("нет непрочитанных → пустой снапшот и пустой курсор")
    func emptyWhenNoUnread() async throws {
        let ffi = MockTDLibFFI()
        let snapshot = try await SummaryCollector(source: makeSource(ffi)).collect(now: Date(timeIntervalSince1970: 1_700_000_000))
        #expect(snapshot.chats.isEmpty)
        #expect(snapshot.cursor.isEmpty)
    }

    @Test("снапшот сериализуется в snake_case JSON")
    func encodesSnakeCase() throws {
        let snap = SummarySnapshot(collectedAt: Date(timeIntervalSince1970: 1_700_000_000),
                                   chats: [SummaryChat(chatId: 123, title: "T", kind: .channel, unreadCount: 2,
                                                       messages: [SummaryMessage(messageId: 101, text: "x")], lastMessageId: 101)],
                                   cursor: [CursorEntry(chatId: 123, upToMessageId: 101)])
        let json = try JSONSerialization.jsonObject(with: SummarySnapshot.encoder().encode(snap)) as! [String: Any]
        #expect(json["collected_at"] != nil)
        let chat = (json["chats"] as! [[String: Any]])[0]
        #expect(chat["chat_id"] as? Int64 == 123)
        #expect(chat["unread_count"] as? Int64 == 2)
        #expect(chat["last_message_id"] as? Int64 == 101)
        let cur = (json["cursor"] as! [[String: Any]])[0]
        #expect(cur["up_to_message_id"] as? Int64 == 101)
    }
}
