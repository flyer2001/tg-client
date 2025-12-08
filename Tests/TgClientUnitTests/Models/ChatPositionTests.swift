import TgClientModels
import Foundation
import Testing
import FoundationExtensions
import TestHelpers

/// Тесты для модели ChatPosition (позиция чата в списке TDLib).
///
/// **TDLib API:** https://core.telegram.org/tdlib/docs/classtd_1_1td__api_1_1chat_position.html
@Suite("Декодирование модели ChatPosition")
struct ChatPositionTests {

    // MARK: - Базовые тесты

    @Test("Декодирование ChatPosition с chatListMain")
    func decodeBasicChatPosition() throws {
        // Реальный JSON от TDLib (order как String для больших чисел > 2^53)
        let json = """
        {
            "list": {"@type": "chatListMain"},
            "order": "9221294784512000005",
            "is_pinned": false
        }
        """

        let data = json.data(using: .utf8)!
        let decoded = try JSONDecoder.tdlib().decode(ChatPosition.self, from: data)

        #expect(decoded.list == .main)
        #expect(decoded.order == 9221294784512000005)
        #expect(decoded.isPinned == false)
    }

    @Test("Декодирование ChatPosition с chatListArchive")
    func decodeChatPositionArchive() throws {
        let json = """
        {
            "list": {"@type": "chatListArchive"},
            "order": "9221294784512000000",
            "is_pinned": true
        }
        """

        let data = json.data(using: .utf8)!
        let decoded = try JSONDecoder.tdlib().decode(ChatPosition.self, from: data)

        #expect(decoded.list == .archive)
        #expect(decoded.order == 9221294784512000000)
        #expect(decoded.isPinned == true)
    }

    @Test("Декодирование ChatPosition с chatListFolder")
    func decodeChatPositionFolder() throws {
        let json = """
        {
            "list": {"@type": "chatListFolder", "chat_folder_id": 123},
            "order": "9221294784512000001",
            "is_pinned": false
        }
        """

        let data = json.data(using: .utf8)!
        let decoded = try JSONDecoder.tdlib().decode(ChatPosition.self, from: data)

        #expect(decoded.list == .folder(id: 123))
        #expect(decoded.order == 9221294784512000001)
        #expect(decoded.isPinned == false)
    }

    // MARK: - Edge Cases: order

    @Test("Edge case: order как String (большое число > 2^53)")
    func decodeOrderAsString() throws {
        // Реальный кейс от TDLib
        let json = """
        {
            "list": {"@type": "chatListMain"},
            "order": "9223372036854775807",
            "is_pinned": false
        }
        """

        let data = json.data(using: .utf8)!
        let decoded = try JSONDecoder.tdlib().decode(ChatPosition.self, from: data)

        #expect(decoded.order == 9223372036854775807) // Int64.max
    }

    @Test("Edge case: order как Int (маленькое число для совместимости)")
    func decodeOrderAsInt() throws {
        let json = """
        {
            "list": {"@type": "chatListMain"},
            "order": 12345,
            "is_pinned": false
        }
        """

        let data = json.data(using: .utf8)!
        let decoded = try JSONDecoder.tdlib().decode(ChatPosition.self, from: data)

        #expect(decoded.order == 12345)
    }

    @Test("Edge case: order=0 (чат удалён из списка) → валидно")
    func decodeOrderZero() throws {
        // TDLib присылает order=0 когда чат удалён из списка
        let json = """
        {
            "list": {"@type": "chatListFolder", "chat_folder_id": 0},
            "order": "0",
            "is_pinned": false
        }
        """

        let data = json.data(using: .utf8)!
        let decoded = try JSONDecoder.tdlib().decode(ChatPosition.self, from: data)

        #expect(decoded.order == 0)
        #expect(decoded.list == .folder(id: 0))
    }

    @Test("Edge case: отрицательный order (технически возможен)")
    func decodeNegativeOrder() throws {
        let json = """
        {
            "list": {"@type": "chatListMain"},
            "order": "-1",
            "is_pinned": false
        }
        """

        let data = json.data(using: .utf8)!
        let decoded = try JSONDecoder.tdlib().decode(ChatPosition.self, from: data)

        #expect(decoded.order == -1)
    }

    // MARK: - Edge Cases: is_pinned

    @Test("Edge case: is_pinned отсутствует → default=false")
    func decodeIsPinnedMissing() throws {
        // По спецификации TDLib is_pinned - обязательное поле (bool, required):
        // https://core.telegram.org/tdlib/docs/classtd_1_1td__api_1_1chat_position.html
        //
        // Однако на практике TDLib может не присылать это поле.
        // В таком случае используем default=false (стандартное значение для "не закреплён").
        let json = """
        {
            "list": {"@type": "chatListMain"},
            "order": "9221294784512000005"
        }
        """

        let data = json.data(using: .utf8)!
        let decoded = try JSONDecoder.tdlib().decode(ChatPosition.self, from: data)

        #expect(decoded.isPinned == false) // default при отсутствии поля
    }

    @Test("Edge case: is_pinned = true")
    func decodeIsPinnedTrue() throws {
        let json = """
        {
            "list": {"@type": "chatListMain"},
            "order": "9221294784512000005",
            "is_pinned": true
        }
        """

        let data = json.data(using: .utf8)!
        let decoded = try JSONDecoder.tdlib().decode(ChatPosition.self, from: data)

        #expect(decoded.isPinned == true)
    }

    @Test("Edge case: is_pinned = 1 (Int format from TDLib)")
    func decodeIsPinnedAsInt1() throws {
        // Real TDLib может присылать Boolean как Int: 1 = true
        let json = """
        {
            "list": {"@type": "chatListMain"},
            "order": "9221294784512000005",
            "is_pinned": 1
        }
        """

        let data = json.data(using: .utf8)!
        let decoded = try JSONDecoder.tdlib().decode(ChatPosition.self, from: data)

        #expect(decoded.isPinned == true)
    }

    @Test("Edge case: is_pinned = 0 (Int format from TDLib)")
    func decodeIsPinnedAsInt0() throws {
        // Real TDLib может присылать Boolean как Int: 0 = false
        let json = """
        {
            "list": {"@type": "chatListMain"},
            "order": "9221294784512000005",
            "is_pinned": 0
        }
        """

        let data = json.data(using: .utf8)!
        let decoded = try JSONDecoder.tdlib().decode(ChatPosition.self, from: data)

        #expect(decoded.isPinned == false)
    }

    // MARK: - Roundtrip тесты

    @Test("Roundtrip: ChatPosition с chatListMain")
    func roundtripMain() throws {
        let original = ChatPosition(
            list: .main,
            order: 9221294784512000005,
            isPinned: false
        )

        let encoded = try original.toTDLibData()
        let decoded = try JSONDecoder.tdlib().decode(ChatPosition.self, from: encoded)

        #expect(decoded.list == original.list)
        #expect(decoded.order == original.order)
        #expect(decoded.isPinned == original.isPinned)
    }

    @Test("Roundtrip: ChatPosition с chatListArchive")
    func roundtripArchive() throws {
        let original = ChatPosition(
            list: .archive,
            order: 9221294784512000000,
            isPinned: true
        )

        let encoded = try original.toTDLibData()
        let decoded = try JSONDecoder.tdlib().decode(ChatPosition.self, from: encoded)

        #expect(decoded.list == original.list)
        #expect(decoded.order == original.order)
        #expect(decoded.isPinned == original.isPinned)
    }

    @Test("Roundtrip: ChatPosition с chatListFolder")
    func roundtripFolder() throws {
        let original = ChatPosition(
            list: .folder(id: 456),
            order: 9221294784512000001,
            isPinned: false
        )

        let encoded = try original.toTDLibData()
        let decoded = try JSONDecoder.tdlib().decode(ChatPosition.self, from: encoded)

        #expect(decoded.list == original.list)
        #expect(decoded.order == original.order)
        #expect(decoded.isPinned == original.isPinned)
    }

    @Test("Roundtrip: order должен кодироваться как String")
    func roundtripOrderAsString() throws {
        let original = ChatPosition(
            list: .main,
            order: 9223372036854775807, // Int64.max
            isPinned: false
        )

        let encoded = try original.toTDLibData()

        // Проверяем что order закодирован как String
        let json = String(data: encoded, encoding: .utf8)!
        #expect(json.contains("\"9223372036854775807\""))

        // Roundtrip
        let decoded = try JSONDecoder.tdlib().decode(ChatPosition.self, from: encoded)
        #expect(decoded.order == original.order)
    }
}
