import TgClientModels
import TGClientInterfaces
import Foundation
import Testing
@testable import TDLibAdapter

/// Unit-тесты для кодирования ViewMessagesRequest.
///
/// Запрос отмечает сообщения как просмотренные, уменьшает unread count чата.
/// Идемпотентен: повторный вызов не вызывает ошибку.
///
/// **TDLib API:** https://core.telegram.org/tdlib/docs/classtd_1_1td__api_1_1view_messages.html
@Suite("Кодирование ViewMessagesRequest")
struct ViewMessagesRequestTests {

    let encoder = JSONEncoder.tdlib()

    @Test("Encode ViewMessagesRequest с одним messageId")
    func encodeSingleMessage() throws {
        let request = ViewMessagesRequest(
            chatId: 123456789,
            messageIds: [42],
            forceRead: true
        )

        let data = try encoder.encode(request)
        let jsonObject = try JSONSerialization.jsonObject(with: data)
        let json = try #require(jsonObject as? [String: Any])

        #expect(json["@type"] as? String == "viewMessages")
        #expect(json["chat_id"] as? Int64 == 123456789)
        #expect(json["message_ids"] as? [Int64] == [42])
        #expect(json["force_read"] as? Bool == true)
    }

    @Test("Encode ViewMessagesRequest с несколькими messageIds")
    func encodeMultipleMessages() throws {
        let request = ViewMessagesRequest(
            chatId: -1001234567890,
            messageIds: [1, 2, 3, 100, 999],
            forceRead: false
        )

        let data = try encoder.encode(request)
        let jsonObject = try JSONSerialization.jsonObject(with: data)
        let json = try #require(jsonObject as? [String: Any])

        #expect(json["@type"] as? String == "viewMessages")
        #expect(json["chat_id"] as? Int64 == -1001234567890)
        #expect(json["message_ids"] as? [Int64] == [1, 2, 3, 100, 999])
        #expect(json["force_read"] as? Bool == false)
    }

    @Test("Encode ViewMessagesRequest с пустым messageIds")
    func encodeEmptyMessageIds() throws {
        let request = ViewMessagesRequest(
            chatId: 123,
            messageIds: [],
            forceRead: true
        )

        let data = try encoder.encode(request)
        let jsonObject = try JSONSerialization.jsonObject(with: data)
        let json = try #require(jsonObject as? [String: Any])

        #expect(json["message_ids"] as? [Int64] == [])
    }

    @Test("Encode ViewMessagesRequest с отрицательным chatId")
    func encodeNegativeChatId() throws {
        let request = ViewMessagesRequest(
            chatId: -100123456789,
            messageIds: [1, 2],
            forceRead: true
        )

        let data = try encoder.encode(request)
        let jsonObject = try JSONSerialization.jsonObject(with: data)
        let json = try #require(jsonObject as? [String: Any])

        #expect(json["chat_id"] as? Int64 == -100123456789)
    }

    @Test("Edge case: максимальные значения")
    func encodeMaxValues() throws {
        let request = ViewMessagesRequest(
            chatId: Int64.max,
            messageIds: [Int64.max, Int64.max - 1],
            forceRead: false
        )

        let data = try encoder.encode(request)
        let jsonObject = try JSONSerialization.jsonObject(with: data)
        let json = try #require(jsonObject as? [String: Any])

        #expect(json["chat_id"] as? Int64 == Int64.max)
        #expect(json["message_ids"] as? [Int64] == [Int64.max, Int64.max - 1])
    }
}
