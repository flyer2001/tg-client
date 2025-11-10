import Foundation
import Testing
import FoundationExtensions
@testable import TDLibAdapter

/// Тесты для кодирования LoadChatsRequest.
///
/// **TDLib API:** https://core.telegram.org/tdlib/docs/classtd_1_1td__api_1_1load_chats.html
///
/// **Структура запроса:**
/// ```json
/// {
///   "@type": "loadChats",
///   "chat_list": { "@type": "chatListMain" },
///   "limit": 100
/// }
/// ```
@Suite("Кодирование LoadChatsRequest")
struct LoadChatsRequestTests {

    @Test("Encode LoadChatsRequest для main list")
    func encodeLoadChatsForMainList() throws {
        let request = LoadChatsRequest(chatList: .main, limit: 100)
        let encoder = JSONEncoder.tdlib()
        let data = try encoder.encode(request)
        let jsonObject = try JSONSerialization.jsonObject(with: data)
        let json = try #require(jsonObject as? [String: Any], "JSON должен быть словарём")

        #expect(json["@type"] as? String == "loadChats")

        let chatListObject = json["chat_list"]
        let chatList = try #require(chatListObject as? [String: Any], "chat_list должен быть словарём")
        #expect(chatList["@type"] as? String == "chatListMain")

        #expect(json["limit"] as? Int == 100)
    }

    @Test("Encode LoadChatsRequest для archive list")
    func encodeLoadChatsForArchiveList() throws {
        let request = LoadChatsRequest(chatList: .archive, limit: 50)
        let encoder = JSONEncoder.tdlib()
        let data = try encoder.encode(request)
        let jsonObject = try JSONSerialization.jsonObject(with: data)
        let json = try #require(jsonObject as? [String: Any], "JSON должен быть словарём")

        #expect(json["@type"] as? String == "loadChats")

        let chatListObject = json["chat_list"]
        let chatList = try #require(chatListObject as? [String: Any], "chat_list должен быть словарём")
        #expect(chatList["@type"] as? String == "chatListArchive")

        #expect(json["limit"] as? Int == 50)
    }

    @Test("Проверка snake_case маппинга")
    func checkSnakeCaseMapping() throws {
        let request = LoadChatsRequest(chatList: .main, limit: 100)
        let encoder = JSONEncoder.tdlib()
        let data = try encoder.encode(request)
        let jsonObject = try JSONSerialization.jsonObject(with: data)
        let json = try #require(jsonObject as? [String: Any], "JSON должен быть словарём")

        // Проверяем что ключ именно "chat_list", а не "chatList"
        #expect(json["chat_list"] != nil, "Должен быть ключ 'chat_list'")
        #expect(json["chatList"] == nil, "Не должно быть ключа 'chatList'")
    }
}
