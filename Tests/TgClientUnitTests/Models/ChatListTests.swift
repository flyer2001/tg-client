import TgClientModels
import Foundation
import Testing
import FoundationExtensions
import TestHelpers

/// Тесты для модели ChatList (типы списков чатов в TDLib).
///
/// **TDLib API:** https://core.telegram.org/tdlib/docs/classtd_1_1td__api_1_1chat_list.html
@Suite("Декодирование модели ChatList")
struct ChatListTests {

    // MARK: - Базовые тесты

    @Test("Декодирование chatListMain")
    func decodeChatListMain() throws {
        let json = """
        {"@type": "chatListMain"}
        """

        let data = json.data(using: .utf8)!
        let decoded = try JSONDecoder.tdlib().decode(ChatList.self, from: data)

        #expect(decoded == .main)

        // Roundtrip: encode → decode
        let encoded = try decoded.toTDLibData()
        let reDecoded = try JSONDecoder.tdlib().decode(ChatList.self, from: encoded)
        #expect(reDecoded == decoded)
    }

    @Test("Декодирование chatListArchive")
    func decodeChatListArchive() throws {
        let json = """
        {"@type": "chatListArchive"}
        """

        let data = json.data(using: .utf8)!
        let decoded = try JSONDecoder.tdlib().decode(ChatList.self, from: data)

        #expect(decoded == .archive)

        // Roundtrip: encode → decode
        let encoded = try decoded.toTDLibData()
        let reDecoded = try JSONDecoder.tdlib().decode(ChatList.self, from: encoded)
        #expect(reDecoded == decoded)
    }

    @Test("Декодирование chatListFolder с chat_folder_id")
    func decodeChatListFolder() throws {
        let json = """
        {"@type": "chatListFolder", "chat_folder_id": 123}
        """

        let data = json.data(using: .utf8)!
        let decoded = try JSONDecoder.tdlib().decode(ChatList.self, from: data)

        #expect(decoded == .folder(id: 123))

        // Roundtrip: encode → decode
        let encoded = try decoded.toTDLibData()
        let reDecoded = try JSONDecoder.tdlib().decode(ChatList.self, from: encoded)
        #expect(reDecoded == decoded)
    }

    // MARK: - Edge Cases

    @Test("Edge case: chatListFolder БЕЗ chat_folder_id → должен бросить DecodingError")
    func decodeChatListFolderMissingFolderId() throws {
        // TDLib присылает chatListFolder без chat_folder_id для удалённых папок
        let json = """
        {"@type": "chatListFolder"}
        """

        let data = json.data(using: .utf8)!

        #expect(throws: DecodingError.self) {
            try JSONDecoder.tdlib().decode(ChatList.self, from: data)
        }
    }

    @Test("Edge case: chatListFolder с chat_folder_id=0 (валидный ID)")
    func decodeChatListFolderZeroId() throws {
        let json = """
        {"@type": "chatListFolder", "chat_folder_id": 0}
        """

        let data = json.data(using: .utf8)!
        let decoded = try JSONDecoder.tdlib().decode(ChatList.self, from: data)

        #expect(decoded == .folder(id: 0))
    }

    @Test("Edge case: chatListFolder с отрицательным chat_folder_id")
    func decodeChatListFolderNegativeId() throws {
        let json = """
        {"@type": "chatListFolder", "chat_folder_id": -1}
        """

        let data = json.data(using: .utf8)!
        let decoded = try JSONDecoder.tdlib().decode(ChatList.self, from: data)

        #expect(decoded == .folder(id: -1))
    }

    @Test("Edge case: chatListFolder с chat_folder_id как String (helper decodeInt32)")
    func decodeChatListFolderStringId() throws {
        // Helper decodeInt32 должен поддерживать String
        let json = """
        {"@type": "chatListFolder", "chat_folder_id": "456"}
        """

        let data = json.data(using: .utf8)!
        let decoded = try JSONDecoder.tdlib().decode(ChatList.self, from: data)

        #expect(decoded == .folder(id: 456))
    }

    @Test("Edge case: неизвестный тип ChatList → должен бросить DecodingError")
    func decodeUnknownChatListType() throws {
        let json = """
        {"@type": "chatListSomethingNew"}
        """

        let data = json.data(using: .utf8)!

        #expect(throws: DecodingError.self) {
            try JSONDecoder.tdlib().decode(ChatList.self, from: data)
        }
    }

    // MARK: - Roundtrip тесты

    @Test("Roundtrip: .main")
    func roundtripMain() throws {
        let original = ChatList.main
        let data = try original.toTDLibData()
        let decoded = try JSONDecoder.tdlib().decode(ChatList.self, from: data)
        #expect(decoded == original)
    }

    @Test("Roundtrip: .archive")
    func roundtripArchive() throws {
        let original = ChatList.archive
        let data = try original.toTDLibData()
        let decoded = try JSONDecoder.tdlib().decode(ChatList.self, from: data)
        #expect(decoded == original)
    }

    @Test("Roundtrip: .folder(id: 789)")
    func roundtripFolder() throws {
        let original = ChatList.folder(id: 789)
        let data = try original.toTDLibData()
        let decoded = try JSONDecoder.tdlib().decode(ChatList.self, from: data)
        #expect(decoded == original)
    }
}
