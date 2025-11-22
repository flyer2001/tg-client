import Foundation
import Testing
import FoundationExtensions
@testable import TDLibAdapter

/// Тесты для модели Chat и ChatType.
///
/// **TDLib API:** https://core.telegram.org/tdlib/docs/classtd_1_1td__api_1_1chat.html
///
/// TDLib поддерживает различные типы чатов:
/// - Private chat (личный чат с пользователем)
/// - Basic group (обычная группа, до 200 участников)
/// - Supergroup (супергруппа, до 200k участников)
/// - Channel (канал - это supergroup с is_channel=true)
/// - Secret chat (секретный чат с E2E шифрованием)
@Suite("Декодирование ChatType и Chat модели")
struct ChatTests {

    // MARK: - ChatType Tests

    /// Тест декодирования chatTypePrivate.
    ///
    /// **Пример реального JSON от TDLib:**
    ///
    /// ```json
    /// {
    ///   "@type": "chatTypePrivate",
    ///   "user_id": 123456789
    /// }
    /// ```
    ///
    /// **TDLib docs:** https://core.telegram.org/tdlib/docs/classtd_1_1td__api_1_1chat_type_private.html
    @Test("Декодирование chatTypePrivate")
    func decodeChatTypePrivate() throws {
        let json = """
        {
            "@type": "chatTypePrivate",
            "user_id": 123456789
        }
        """

        let data = Data(json.utf8)
        let decoder = JSONDecoder.tdlib()
        let chatType = try decoder.decode(ChatType.self, from: data)

        #expect(chatType == .private(userId: 123456789))
    }

    /// Тест декодирования chatTypeBasicGroup.
    ///
    /// **Пример реального JSON от TDLib:**
    ///
    /// ```json
    /// {
    ///   "@type": "chatTypeBasicGroup",
    ///   "basic_group_id": 987654321
    /// }
    /// ```
    ///
    /// **TDLib docs:** https://core.telegram.org/tdlib/docs/classtd_1_1td__api_1_1chat_type_basic_group.html
    @Test("Декодирование chatTypeBasicGroup")
    func decodeChatTypeBasicGroup() throws {
        let json = """
        {
            "@type": "chatTypeBasicGroup",
            "basic_group_id": 987654321
        }
        """

        let data = Data(json.utf8)
        let decoder = JSONDecoder.tdlib()
        let chatType = try decoder.decode(ChatType.self, from: data)

        #expect(chatType == .basicGroup(basicGroupId: 987654321))
    }

    /// Тест декодирования chatTypeSupergroup (НЕ канал).
    ///
    /// **Пример реального JSON от TDLib:**
    ///
    /// ```json
    /// {
    ///   "@type": "chatTypeSupergroup",
    ///   "supergroup_id": 555666777,
    ///   "is_channel": false
    /// }
    /// ```
    ///
    /// **TDLib docs:** https://core.telegram.org/tdlib/docs/classtd_1_1td__api_1_1chat_type_supergroup.html
    @Test("Декодирование chatTypeSupergroup (не канал)")
    func decodeChatTypeSupergroup() throws {
        let json = """
        {
            "@type": "chatTypeSupergroup",
            "supergroup_id": 555666777,
            "is_channel": false
        }
        """

        let data = Data(json.utf8)
        let decoder = JSONDecoder.tdlib()
        let chatType = try decoder.decode(ChatType.self, from: data)

        #expect(chatType == .supergroup(supergroupId: 555666777, isChannel: false))
    }

    /// Тест декодирования chatTypeSupergroup с is_channel=true (канал).
    ///
    /// **Пример реального JSON от TDLib:**
    ///
    /// ```json
    /// {
    ///   "@type": "chatTypeSupergroup",
    ///   "supergroup_id": 111222333,
    ///   "is_channel": true
    /// }
    /// ```
    ///
    /// В TDLib каналы — это супергруппы с флагом `is_channel = true`.
    @Test("Декодирование chatTypeSupergroup (канал)")
    func decodeChatTypeChannel() throws {
        let json = """
        {
            "@type": "chatTypeSupergroup",
            "supergroup_id": 111222333,
            "is_channel": true
        }
        """

        let data = Data(json.utf8)
        let decoder = JSONDecoder.tdlib()
        let chatType = try decoder.decode(ChatType.self, from: data)

        #expect(chatType == .supergroup(supergroupId: 111222333, isChannel: true))
    }

    /// Тест декодирования chatTypeSecret.
    ///
    /// **Пример реального JSON от TDLib:**
    ///
    /// ```json
    /// {
    ///   "@type": "chatTypeSecret",
    ///   "secret_chat_id": 444555666,
    ///   "user_id": 777888999
    /// }
    /// ```
    ///
    /// **TDLib docs:** https://core.telegram.org/tdlib/docs/classtd_1_1td__api_1_1chat_type_secret.html
    @Test("Декодирование chatTypeSecret")
    func decodeChatTypeSecret() throws {
        let json = """
        {
            "@type": "chatTypeSecret",
            "secret_chat_id": 444555666,
            "user_id": 777888999
        }
        """

        let data = Data(json.utf8)
        let decoder = JSONDecoder.tdlib()
        let chatType = try decoder.decode(ChatType.self, from: data)

        #expect(chatType == .secret(secretChatId: 444555666, userId: 777888999))
    }

    /// TDLib возвращает is_channel как Int (0 = false, 1 = true), не Bool.
    @Test("Декодирование is_channel из Int")
    func decodeIsChannelAsInt() throws {
        // TDLib JSON: is_channel как число
        let tdlibJSON = try TDLibJSON(parsing: [
            "@type": "chatTypeSupergroup",
            "supergroup_id": 555666777,
            "is_channel": 0  // Int, не Bool
        ])

        let data = try JSONSerialization.data(withJSONObject: tdlibJSON.data)
        let decoder = JSONDecoder.tdlib()
        let chatType = try decoder.decode(ChatType.self, from: data)

        #expect(chatType == .supergroup(supergroupId: 555666777, isChannel: false))

        // Канал (is_channel = 1)
        let channelJSON = try TDLibJSON(parsing: [
            "@type": "chatTypeSupergroup",
            "supergroup_id": 111222333,
            "is_channel": 1
        ])

        let channelData = try JSONSerialization.data(withJSONObject: channelJSON.data)
        let channelType = try decoder.decode(ChatType.self, from: channelData)

        #expect(channelType == .supergroup(supergroupId: 111222333, isChannel: true))
    }

    /// Тест что ChatType Sendable и Equatable.
    @Test("ChatType соответствует Sendable и Equatable")
    func verifyChatTypeProtocolConformance() {
        let type1 = ChatType.private(userId: 123)
        let type2 = ChatType.private(userId: 123)
        let type3 = ChatType.private(userId: 456)

        // Equatable
        #expect(type1 == type2)
        #expect(type1 != type3)
    }
}
