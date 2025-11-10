import Foundation
import Testing
import FoundationExtensions
@testable import TDLibAdapter

/// Тесты для модели ChatsResponse.
///
/// **TDLib API:** https://core.telegram.org/tdlib/docs/classtd_1_1td__api_1_1chats.html
///
/// TDLib возвращает список ID чатов при вызове метода `getChats`.
/// Содержит только ID чатов — для получения полной информации используйте `getChat(chatId:)`.
@Suite("Декодирование модели ChatsResponse")
struct ChatsResponseTests {

    /// Тест декодирования списка чатов с несколькими ID.
    ///
    /// **Пример реального ответа TDLib на `getChats`:**
    ///
    /// ```json
    /// {
    ///   "@type": "chats",
    ///   "total_count": 3,
    ///   "chat_ids": [123456789, 987654321, 555666777]
    /// }
    /// ```
    ///
    /// **TDLib docs:**
    /// - Method: https://core.telegram.org/tdlib/docs/classtd_1_1td__api_1_1get_chats.html
    /// - Response: https://core.telegram.org/tdlib/docs/classtd_1_1td__api_1_1chats.html
    @Test("Декодирование списка чатов с несколькими ID")
    func decodeChatsWithMultipleIds() throws {
        let json = """
        {
            "@type": "chats",
            "total_count": 3,
            "chat_ids": [123456789, 987654321, 555666777]
        }
        """

        let data = Data(json.utf8)
        let decoder = JSONDecoder.tdlib()
        let response = try decoder.decode(ChatsResponse.self, from: data)

        #expect(response.chatIds.count == 3)
        #expect(response.chatIds == [123456789, 987654321, 555666777])
    }

    /// Тест декодирования пустого списка чатов.
    ///
    /// **Пример ответа TDLib когда нет чатов:**
    ///
    /// ```json
    /// {
    ///   "@type": "chats",
    ///   "total_count": 0,
    ///   "chat_ids": []
    /// }
    /// ```
    ///
    /// Это валидный ответ — например, когда пользователь новый или все чаты в архиве.
    @Test("Декодирование пустого списка чатов")
    func decodeEmptyChats() throws {
        let json = """
        {
            "@type": "chats",
            "total_count": 0,
            "chat_ids": []
        }
        """

        let data = Data(json.utf8)
        let decoder = JSONDecoder.tdlib()
        let response = try decoder.decode(ChatsResponse.self, from: data)

        #expect(response.chatIds.isEmpty)
        #expect(response.chatIds.count == 0)
    }

    /// Тест декодирования одного чата.
    ///
    /// Проверяем edge case: один элемент в массиве.
    @Test("Декодирование одного чата")
    func decodeSingleChat() throws {
        let json = """
        {
            "@type": "chats",
            "total_count": 1,
            "chat_ids": [111222333]
        }
        """

        let data = Data(json.utf8)
        let decoder = JSONDecoder.tdlib()
        let response = try decoder.decode(ChatsResponse.self, from: data)

        #expect(response.chatIds.count == 1)
        #expect(response.chatIds.first == 111222333)
    }

    /// Тест проверки snake_case маппинга для chat_ids.
    ///
    /// TDLib использует `chat_ids` (snake_case), Swift должен маппить в `chatIds` (camelCase).
    @Test("Проверка snake_case маппинга")
    func verifySnakeCaseMapping() throws {
        let json = """
        {
            "@type": "chats",
            "total_count": 2,
            "chat_ids": [111, 222]
        }
        """

        let data = Data(json.utf8)
        let decoder = JSONDecoder.tdlib()

        // Должно успешно декодироваться несмотря на snake_case в JSON
        let response = try decoder.decode(ChatsResponse.self, from: data)

        #expect(response.chatIds == [111, 222])
    }

    /// Тест декодирования больших ID чатов (Int64).
    ///
    /// ID чатов в TDLib — это Int64, могут быть очень большими числами.
    @Test("Декодирование больших ID (Int64)")
    func decodeLargeInt64ChatIds() throws {
        let json = """
        {
            "@type": "chats",
            "total_count": 2,
            "chat_ids": [9223372036854775807, -9223372036854775808]
        }
        """

        let data = Data(json.utf8)
        let decoder = JSONDecoder.tdlib()
        let response = try decoder.decode(ChatsResponse.self, from: data)

        #expect(response.chatIds.count == 2)
        #expect(response.chatIds[0] == Int64.max)
        #expect(response.chatIds[1] == Int64.min)
    }

    /// Тест создания ChatsResponse программно (для тестов).
    @Test("Создание ChatsResponse программно")
    func createChatsResponseProgrammatically() {
        let response = ChatsResponse(chatIds: [100, 200, 300])

        #expect(response.chatIds.count == 3)
        #expect(response.chatIds == [100, 200, 300])
    }

    /// Тест что ChatsResponse Sendable и Equatable.
    ///
    /// Важно для использования в async контексте и в тестах.
    @Test("ChatsResponse соответствует Sendable и Equatable")
    func verifyProtocolConformance() {
        let response1 = ChatsResponse(chatIds: [1, 2, 3])
        let response2 = ChatsResponse(chatIds: [1, 2, 3])
        let response3 = ChatsResponse(chatIds: [4, 5, 6])

        // Equatable
        #expect(response1 == response2)
        #expect(response1 != response3)
    }
}
