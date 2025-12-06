import TgClientModels
import TGClientInterfaces
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

    // MARK: - updateChatPosition тесты

    /// Тест декодирования updateChatPosition с chatListMain.
    @Test("Декодирование updateChatPosition с chatListMain")
    func decodeUpdateChatPositionMain() throws {
        // Реальный JSON от TDLib
        let json = """
        {
            "@type": "updateChatPosition",
            "chat_id": 123456789,
            "position": {
                "list": {"@type": "chatListMain"},
                "order": "9221294784512000005",
                "is_pinned": false
            }
        }
        """

        let data = json.data(using: .utf8)!
        let decoded = try JSONDecoder.tdlib().decode(Update.self, from: data)

        // Проверяем что декодировалось правильно
        guard case .chatPosition(let chatId, let position) = decoded else {
            Issue.record("Expected .chatPosition, got \(decoded)")
            return
        }

        #expect(chatId == 123456789)
        #expect(position.list == .main)
        #expect(position.order == 9221294784512000005)
        #expect(position.isPinned == false)
    }

    /// Тест декодирования updateChatPosition с chatListArchive.
    @Test("Декодирование updateChatPosition с chatListArchive")
    func decodeUpdateChatPositionArchive() throws {
        let json = """
        {
            "@type": "updateChatPosition",
            "chat_id": "987654321",
            "position": {
                "list": {"@type": "chatListArchive"},
                "order": "9221294784512000000",
                "is_pinned": true
            }
        }
        """

        let data = json.data(using: .utf8)!
        let decoded = try JSONDecoder.tdlib().decode(Update.self, from: data)

        guard case .chatPosition(let chatId, let position) = decoded else {
            Issue.record("Expected .chatPosition, got \(decoded)")
            return
        }

        #expect(chatId == 987654321)
        #expect(position.list == .archive)
        #expect(position.order == 9221294784512000000)
        #expect(position.isPinned == true)
    }

    /// Тест декодирования updateChatPosition с chatListFolder.
    @Test("Декодирование updateChatPosition с chatListFolder")
    func decodeUpdateChatPositionFolder() throws {
        let json = """
        {
            "@type": "updateChatPosition",
            "chat_id": "111222333",
            "position": {
                "list": {"@type": "chatListFolder", "chat_folder_id": 456},
                "order": "9221294784512000001",
                "is_pinned": false
            }
        }
        """

        let data = json.data(using: .utf8)!
        let decoded = try JSONDecoder.tdlib().decode(Update.self, from: data)

        guard case .chatPosition(let chatId, let position) = decoded else {
            Issue.record("Expected .chatPosition, got \(decoded)")
            return
        }

        #expect(chatId == 111222333)
        #expect(position.list == .folder(id: 456))
        #expect(position.order == 9221294784512000001)
        #expect(position.isPinned == false)
    }

    /// Тест edge case: updateChatPosition с order=0 (чат удалён из списка).
    @Test("Edge case: updateChatPosition с order=0")
    func decodeUpdateChatPositionOrderZero() throws {
        let json = """
        {
            "@type": "updateChatPosition",
            "chat_id": "444555666",
            "position": {
                "list": {"@type": "chatListMain"},
                "order": "0",
                "is_pinned": false
            }
        }
        """

        let data = json.data(using: .utf8)!
        let decoded = try JSONDecoder.tdlib().decode(Update.self, from: data)

        guard case .chatPosition(let chatId, let position) = decoded else {
            Issue.record("Expected .chatPosition, got \(decoded)")
            return
        }

        #expect(chatId == 444555666)
        #expect(position.order == 0)
        #expect(position.list == .main)
    }

    /// Тест edge case: updateChatPosition с chatListFolder БЕЗ chat_folder_id → должен бросить error.
    @Test("Edge case: updateChatPosition с chatListFolder без folder_id → fail")
    func decodeUpdateChatPositionFolderMissingId() throws {
        // TDLib присылает chatListFolder без chat_folder_id для удалённых папок
        let json = """
        {
            "@type": "updateChatPosition",
            "chat_id": "777888999",
            "position": {
                "list": {"@type": "chatListFolder"},
                "order": "0",
                "is_pinned": false
            }
        }
        """

        let data = json.data(using: .utf8)!

        #expect(throws: DecodingError.self) {
            try JSONDecoder.tdlib().decode(Update.self, from: data)
        }
    }

    /// Roundtrip тест для updateChatPosition.
    @Test("Roundtrip: updateChatPosition")
    func roundtripUpdateChatPosition() throws {
        // Создаём ChatPosition через JSON (т.к. нет публичного init)
        let positionJSON = """
        {
            "list": {"@type": "chatListMain"},
            "order": "9221294784512000005",
            "is_pinned": false
        }
        """
        let positionData = positionJSON.data(using: .utf8)!
        let position = try JSONDecoder.tdlib().decode(ChatPosition.self, from: positionData)

        let original = Update.chatPosition(chatId: 123456789, position: position)

        // Roundtrip: encode → decode
        let data = try original.toTDLibData()
        let decoded = try JSONDecoder.tdlib().decode(Update.self, from: data)

        guard case .chatPosition(let chatId, let decodedPosition) = decoded else {
            Issue.record("Expected .chatPosition, got \(decoded)")
            return
        }

        #expect(chatId == 123456789)
        #expect(decodedPosition.list == position.list)
        #expect(decodedPosition.order == position.order)
        #expect(decodedPosition.isPinned == position.isPinned)
    }
}
