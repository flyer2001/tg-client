import Foundation
import Testing
import FoundationExtensions
import TestHelpers
@testable import TDLibAdapter

/// Тесты для модели Update (updates от TDLib).
///
/// **TDLib API:**
/// - updateNewChat: https://core.telegram.org/tdlib/docs/classtd_1_1td__api_1_1update_new_chat.html
/// - updateChatReadInbox: https://core.telegram.org/tdlib/docs/classtd_1_1td__api_1_1update_chat_read_inbox.html
@Suite("Декодирование модели Update")
struct UpdateTests {

    /// Тест декодирования updateNewChat с полным объектом чата.
    @Test("Декодирование updateNewChat")
    func decodeUpdateNewChat() throws {
        let chat = ChatResponse(
            id: 123456789,
            type: .supergroup(supergroupId: 987, isChannel: true),
            title: "Tech News",
            unreadCount: 42,
            lastReadInboxMessageId: 999
        )

        // Создаём Update.newChat
        let original = Update.newChat(chat: chat)

        // Round-trip: encode → decode
        let data = try original.toTDLibData()
        let decoded = try JSONDecoder.tdlib().decode(Update.self, from: data)

        // Проверяем что декодировалось правильно
        guard case .newChat(let decodedChat) = decoded else {
            Issue.record("Expected .newChat, got \(decoded)")
            return
        }

        #expect(decodedChat.id == 123456789)
        #expect(decodedChat.chatType == .supergroup(supergroupId: 987, isChannel: true))
        #expect(decodedChat.title == "Tech News")
        #expect(decodedChat.unreadCount == 42)
        #expect(decodedChat.lastReadInboxMessageId == 999)
    }

    /// Тест декодирования updateChatReadInbox.
    @Test("Декодирование updateChatReadInbox")
    func decodeUpdateChatReadInbox() throws {
        let original = Update.chatReadInbox(
            chatId: 123456789,
            lastReadInboxMessageId: 555666777,
            unreadCount: 10
        )

        // Round-trip: encode → decode
        let data = try original.toTDLibData()
        let decoded = try JSONDecoder.tdlib().decode(Update.self, from: data)

        // Проверяем что декодировалось правильно
        guard case .chatReadInbox(let chatId, let lastReadId, let unreadCount) = decoded else {
            Issue.record("Expected .chatReadInbox, got \(decoded)")
            return
        }

        #expect(chatId == 123456789)
        #expect(lastReadId == 555666777)
        #expect(unreadCount == 10)
    }

    /// Тест updateChatReadInbox с нулевым счётчиком непрочитанных.
    @Test("Декодирование updateChatReadInbox с unreadCount = 0")
    func decodeUpdateChatReadInboxZeroUnread() throws {
        let original = Update.chatReadInbox(
            chatId: 111222333,
            lastReadInboxMessageId: 444555666,
            unreadCount: 0
        )

        let data = try original.toTDLibData()
        let decoded = try JSONDecoder.tdlib().decode(Update.self, from: data)

        guard case .chatReadInbox(let chatId, let lastReadId, let unreadCount) = decoded else {
            Issue.record("Expected .chatReadInbox, got \(decoded)")
            return
        }

        #expect(chatId == 111222333)
        #expect(lastReadId == 444555666)
        #expect(unreadCount == 0)
    }

    /// Тест edge cases: отрицательные ID, большие значения.
    @Test("Edge cases для updateChatReadInbox")
    func decodeUpdateChatReadInboxEdgeCases() throws {
        let original = Update.chatReadInbox(
            chatId: -100123456789,
            lastReadInboxMessageId: Int64.max,
            unreadCount: Int32.max
        )

        let data = try original.toTDLibData()
        let decoded = try JSONDecoder.tdlib().decode(Update.self, from: data)

        guard case .chatReadInbox(let chatId, let lastReadId, let unreadCount) = decoded else {
            Issue.record("Expected .chatReadInbox, got \(decoded)")
            return
        }

        #expect(chatId == -100123456789)
        #expect(lastReadId == Int64.max)
        #expect(unreadCount == Int32.max)
    }

    /// Тест декодирования неизвестного типа update (должен fallthrough в .unknown).
    @Test("Декодирование неизвестного типа update")
    func decodeUnknownUpdate() throws {
        let json = """
        {
            "@type": "updateSomethingNew",
            "someField": 123
        }
        """

        let data = json.data(using: .utf8)!
        let decoded = try JSONDecoder.tdlib().decode(Update.self, from: data)

        // Проверяем что декодировался как .unknown
        guard case .unknown(let type) = decoded else {
            Issue.record("Expected .unknown, got \(decoded)")
            return
        }

        #expect(type == "updateSomethingNew")
    }
}
