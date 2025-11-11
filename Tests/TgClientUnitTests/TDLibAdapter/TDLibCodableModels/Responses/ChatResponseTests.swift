import Foundation
import Testing
import FoundationExtensions
import TestHelpers
@testable import TDLibAdapter

/// Тесты для модели ChatResponse (полная информация о чате).
///
/// **TDLib API:** https://core.telegram.org/tdlib/docs/classtd_1_1td__api_1_1chat.html
@Suite("Декодирование модели ChatResponse")
struct ChatResponseTests {

    /// Тест round-trip кодирования базового чата (канал).
    @Test("Round-trip кодирование чата (канал)")
    func roundTripChannelChat() throws {
        let original = ChatResponse(
            id: 123456789,
            type: .supergroup(supergroupId: 987, isChannel: true),
            title: "Tech News",
            unreadCount: 42,
            lastReadInboxMessageId: 999
        )

        let data = try original.toTDLibData()
        let decoded = try JSONDecoder.tdlib().decode(ChatResponse.self, from: data)

        #expect(decoded.id == 123456789)
        #expect(decoded.chatType == .supergroup(supergroupId: 987, isChannel: true))
        #expect(decoded.title == "Tech News")
        #expect(decoded.unreadCount == 42)
        #expect(decoded.lastReadInboxMessageId == 999)
    }

    /// Тест round-trip для различных типов чатов.
    @Test("Round-trip для типа private")
    func roundTripPrivateChat() throws {
        let original = ChatResponse(
            id: 111,
            type: .private(userId: 222),
            title: "Private Chat",
            unreadCount: 5,
            lastReadInboxMessageId: 100
        )

        let data = try original.toTDLibData()
        let decoded = try JSONDecoder.tdlib().decode(ChatResponse.self, from: data)

        #expect(decoded.chatType == .private(userId: 222))
    }

    @Test("Round-trip для типа basicGroup")
    func roundTripBasicGroupChat() throws {
        let original = ChatResponse(
            id: 333,
            type: .basicGroup(basicGroupId: 444),
            title: "Basic Group",
            unreadCount: 3,
            lastReadInboxMessageId: 50
        )

        let data = try original.toTDLibData()
        let decoded = try JSONDecoder.tdlib().decode(ChatResponse.self, from: data)

        #expect(decoded.chatType == .basicGroup(basicGroupId: 444))
    }

    @Test("Round-trip для типа supergroup (не канал)")
    func roundTripSupergroupChat() throws {
        let original = ChatResponse(
            id: 555,
            type: .supergroup(supergroupId: 666, isChannel: false),
            title: "Supergroup",
            unreadCount: 10,
            lastReadInboxMessageId: 200
        )

        let data = try original.toTDLibData()
        let decoded = try JSONDecoder.tdlib().decode(ChatResponse.self, from: data)

        #expect(decoded.chatType == .supergroup(supergroupId: 666, isChannel: false))
    }

    @Test("Round-trip для типа secret")
    func roundTripSecretChat() throws {
        let original = ChatResponse(
            id: 777,
            type: .secret(secretChatId: 888, userId: 999),
            title: "Secret Chat",
            unreadCount: 1,
            lastReadInboxMessageId: 10
        )

        let data = try original.toTDLibData()
        let decoded = try JSONDecoder.tdlib().decode(ChatResponse.self, from: data)

        #expect(decoded.chatType == .secret(secretChatId: 888, userId: 999))
    }

    /// Тест round-trip чата без непрочитанных сообщений.
    @Test("Round-trip чата с unreadCount = 0")
    func roundTripChatWithZeroUnread() throws {
        let original = ChatResponse(
            id: 555666777,
            type: .supergroup(supergroupId: 123, isChannel: false),
            title: "Empty Chat",
            unreadCount: 0,
            lastReadInboxMessageId: 0
        )

        let data = try original.toTDLibData()
        let decoded = try JSONDecoder.tdlib().decode(ChatResponse.self, from: data)

        #expect(decoded.unreadCount == 0)
        #expect(decoded.lastReadInboxMessageId == 0)
    }

    /// Тест round-trip для отрицательных chat ID.
    ///
    /// Приватные и секретные чаты могут иметь отрицательные ID.
    @Test("Round-trip чата с отрицательным ID")
    func roundTripNegativeChatId() throws {
        let original = ChatResponse(
            id: -100123456789,
            type: .private(userId: 456),
            title: "Private Chat",
            unreadCount: 10,
            lastReadInboxMessageId: 500
        )

        let data = try original.toTDLibData()
        let decoded = try JSONDecoder.tdlib().decode(ChatResponse.self, from: data)

        #expect(decoded.id == -100123456789)
        #expect(decoded.chatType == .private(userId: 456))
    }

    /// Тест round-trip для больших значений (Int64/Int32 edge cases).
    @Test("Round-trip edge cases для больших значений")
    func roundTripEdgeCaseValues() throws {
        let original = ChatResponse(
            id: Int64.max,
            type: .supergroup(supergroupId: Int64.max, isChannel: true),
            title: "Edge Case Chat",
            unreadCount: Int32.max,
            lastReadInboxMessageId: Int64.max
        )

        let data = try original.toTDLibData()
        let decoded = try JSONDecoder.tdlib().decode(ChatResponse.self, from: data)

        #expect(decoded.id == Int64.max)
        #expect(decoded.unreadCount == Int32.max)
        #expect(decoded.lastReadInboxMessageId == Int64.max)
    }
}
