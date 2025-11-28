import TgClientModels
import TGClientInterfaces
import Foundation
import Testing
import FoundationExtensions
import TestHelpers
@testable import TDLibAdapter

/// Unit-тесты для MessagesResponse (ответ getChatHistory).
///
/// **TDLib API:** https://core.telegram.org/tdlib/docs/classtd_1_1td__api_1_1messages.html
@Suite("Unit: MessagesResponse")
struct MessagesResponseTests {

    /// Round-trip для списка сообщений.
    @Test("Round-trip: список сообщений")
    func roundTripMessages() throws {
        let message1 = Message(
            id: 1,
            chatId: 100,
            date: 1699564800,
            content: .text(FormattedText(text: "First", entities: nil))
        )
        let message2 = Message(
            id: 2,
            chatId: 100,
            date: 1699564900,
            content: .text(FormattedText(text: "Second", entities: nil))
        )

        let original = MessagesResponse(
            totalCount: 42,
            messages: [message1, message2]
        )

        // Проверяем что @type включен в encoded JSON (критично для TDLibClient routing)
        try original.assertValidEncoding()

        let data = try original.toTDLibData()
        let decoded = try JSONDecoder.tdlib().decode(MessagesResponse.self, from: data)

        #expect(decoded.totalCount == 42)
        #expect(decoded.messages.count == 2)
        #expect(decoded.messages[0].id == 1)
        #expect(decoded.messages[1].id == 2)
    }

    /// Round-trip для пустого списка.
    @Test("Round-trip: пустой список")
    func roundTripEmptyMessages() throws {
        let original = MessagesResponse(
            totalCount: 0,
            messages: []
        )

        let data = try original.toTDLibData()
        let decoded = try JSONDecoder.tdlib().decode(MessagesResponse.self, from: data)

        #expect(decoded.totalCount == 0)
        #expect(decoded.messages.isEmpty)
    }

    /// Edge case: большой totalCount.
    @Test("Round-trip: большой totalCount")
    func roundTripLargeTotalCount() throws {
        let original = MessagesResponse(
            totalCount: Int32.max,
            messages: []
        )

        let data = try original.toTDLibData()
        let decoded = try JSONDecoder.tdlib().decode(MessagesResponse.self, from: data)

        #expect(decoded.totalCount == Int32.max)
    }
}
