import TgClientModels
import TGClientInterfaces
import Foundation
import Testing
import FoundationExtensions
import TestHelpers
@testable import TDLibAdapter

/// Unit-тесты для Message модели (сообщение из TDLib).
///
/// **TDLib API:** https://core.telegram.org/tdlib/docs/classtd_1_1td__api_1_1message.html
@Suite("Unit: Message Response")
struct MessageTests {

    /// Round-trip тест для текстового сообщения.
    @Test("Round-trip: текстовое сообщение")
    func roundTripTextMessage() throws {
        let formattedText = FormattedText(text: "Hello world", entities: nil)
        let original = Message(
            id: 12345,
            chatId: 67890,
            date: 1699564800,
            content: .text(formattedText)
        )

        let data = try original.toTDLibData()
        let decoded = try JSONDecoder.tdlib().decode(Message.self, from: data)

        #expect(decoded.id == 12345)
        #expect(decoded.chatId == 67890)
        #expect(decoded.date == 1699564800)

        guard case .text(let decodedText) = decoded.content else {
            Issue.record("Expected .text content")
            return
        }
        #expect(decodedText.text == "Hello world")
    }

    /// Round-trip для unsupported типа контента (для MVP).
    @Test("Round-trip: unsupported content type")
    func roundTripUnsupportedMessage() throws {
        let original = Message(
            id: 99999,
            chatId: 11111,
            date: 1699564900,
            content: .unsupported
        )

        let data = try original.toTDLibData()
        let decoded = try JSONDecoder.tdlib().decode(Message.self, from: data)

        #expect(decoded.id == 99999)
        guard case .unsupported = decoded.content else {
            Issue.record("Expected .unsupported content")
            return
        }
    }

    /// Edge case: отрицательный chatId (каналы/супергруппы).
    @Test("Round-trip: отрицательный chatId")
    func roundTripNegativeChatId() throws {
        let formattedText = FormattedText(text: "Channel post", entities: nil)
        let original = Message(
            id: 111,
            chatId: -1001234567890,
            date: 1699564800,
            content: .text(formattedText)
        )

        let data = try original.toTDLibData()
        let decoded = try JSONDecoder.tdlib().decode(Message.self, from: data)

        #expect(decoded.chatId == -1001234567890)
    }

    /// Edge case: Int64.max для ID.
    @Test("Round-trip: максимальные значения ID")
    func roundTripMaxValues() throws {
        let formattedText = FormattedText(text: "Max ID test", entities: nil)
        let original = Message(
            id: Int64.max,
            chatId: Int64.max,
            date: Int32.max,
            content: .text(formattedText)
        )

        let data = try original.toTDLibData()
        let decoded = try JSONDecoder.tdlib().decode(Message.self, from: data)

        #expect(decoded.id == Int64.max)
        #expect(decoded.chatId == Int64.max)
        #expect(decoded.date == Int32.max)
    }
}
