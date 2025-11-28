import TgClientModels
import TGClientInterfaces
import Foundation
import Testing
import FoundationExtensions
@testable import TDLibAdapter

/// Тесты для кодирования GetChatHistoryRequest.
///
/// **TDLib API:** https://core.telegram.org/tdlib/docs/classtd_1_1td__api_1_1get_chat_history.html
@Suite("Кодирование GetChatHistoryRequest")
struct GetChatHistoryRequestTests {

    @Test("Encode GetChatHistoryRequest с базовыми параметрами")
    func encodeBasicRequest() throws {
        let request = GetChatHistoryRequest(
            chatId: 123456789,
            fromMessageId: 0,
            offset: 0,
            limit: 100,
            onlyLocal: false
        )
        let encoder = JSONEncoder.tdlib()
        let data = try encoder.encode(request)
        let jsonObject = try JSONSerialization.jsonObject(with: data)
        let json = try #require(jsonObject as? [String: Any])

        #expect(json["@type"] as? String == "getChatHistory")
        #expect(json["chat_id"] as? Int64 == 123456789)
        #expect(json["from_message_id"] as? Int64 == 0)
        #expect(json["offset"] as? Int32 == 0)
        #expect(json["limit"] as? Int32 == 100)
        #expect(json["only_local"] as? Bool == false)
    }

    @Test("Encode с отрицательным chatId (канал)")
    func encodeNegativeChatId() throws {
        let request = GetChatHistoryRequest(
            chatId: -1001234567890,
            fromMessageId: 999,
            offset: 0,
            limit: 50,
            onlyLocal: false
        )
        let encoder = JSONEncoder.tdlib()
        let data = try encoder.encode(request)
        let jsonObject = try JSONSerialization.jsonObject(with: data)
        let json = try #require(jsonObject as? [String: Any])

        #expect(json["chat_id"] as? Int64 == -1001234567890)
        #expect(json["from_message_id"] as? Int64 == 999)
        #expect(json["limit"] as? Int32 == 50)
    }

    @Test("Edge case: максимальные значения")
    func encodeMaxValues() throws {
        let request = GetChatHistoryRequest(
            chatId: Int64.max,
            fromMessageId: Int64.max,
            offset: Int32.max,
            limit: 100,
            onlyLocal: true
        )
        let encoder = JSONEncoder.tdlib()
        let data = try encoder.encode(request)
        let jsonObject = try JSONSerialization.jsonObject(with: data)
        let json = try #require(jsonObject as? [String: Any])

        #expect(json["chat_id"] as? Int64 == Int64.max)
        #expect(json["from_message_id"] as? Int64 == Int64.max)
        #expect(json["offset"] as? Int32 == Int32.max)
    }
}
