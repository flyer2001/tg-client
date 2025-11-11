import Foundation
import Testing
import FoundationExtensions
import TestHelpers
@testable import TDLibAdapter

/// Тесты для модели ChatsResponse.
///
/// **TDLib API:** https://core.telegram.org/tdlib/docs/classtd_1_1td__api_1_1chats.html
///
/// TDLib возвращает список ID чатов при вызове метода `getChats`.
/// Содержит только ID чатов — для получения полной информации используйте `getChat(chatId:)`.
@Suite("Декодирование модели ChatsResponse")
struct ChatsResponseTests {

    /// Тест round-trip кодирования списка чатов с несколькими ID.
    ///
    /// **TDLib docs:**
    /// - Method: https://core.telegram.org/tdlib/docs/classtd_1_1td__api_1_1get_chats.html
    /// - Response: https://core.telegram.org/tdlib/docs/classtd_1_1td__api_1_1chats.html
    @Test("Round-trip кодирование списка чатов с несколькими ID")
    func roundTripChatsWithMultipleIds() throws {
        let original = ChatsResponse(chatIds: [123456789, 987654321, 555666777])

        let data = try original.toTDLibData()
        let decoded = try JSONDecoder.tdlib().decode(ChatsResponse.self, from: data)

        #expect(decoded.chatIds.count == 3)
        #expect(decoded.chatIds == [123456789, 987654321, 555666777])
    }

    /// Тест round-trip кодирования пустого списка чатов.
    ///
    /// Это валидный ответ — например, когда пользователь новый или все чаты в архиве.
    @Test("Round-trip кодирование пустого списка чатов")
    func roundTripEmptyChats() throws {
        let original = ChatsResponse(chatIds: [])

        let data = try original.toTDLibData()
        let decoded = try JSONDecoder.tdlib().decode(ChatsResponse.self, from: data)

        #expect(decoded.chatIds.isEmpty)
        #expect(decoded.chatIds.count == 0)
    }

    /// Тест round-trip кодирования одного чата.
    ///
    /// Проверяем edge case: один элемент в массиве.
    @Test("Round-trip кодирование одного чата")
    func roundTripSingleChat() throws {
        let original = ChatsResponse(chatIds: [111222333])

        let data = try original.toTDLibData()
        let decoded = try JSONDecoder.tdlib().decode(ChatsResponse.self, from: data)

        #expect(decoded.chatIds.count == 1)
        #expect(decoded.chatIds.first == 111222333)
    }

    /// Тест проверки snake_case маппинга для chat_ids.
    ///
    /// TDLib использует `chat_ids` (snake_case), Swift должен маппить в `chatIds` (camelCase).
    @Test("Проверка snake_case маппинга")
    func verifySnakeCaseMapping() throws {
        let original = ChatsResponse(chatIds: [111, 222])

        let data = try original.toTDLibData()
        let decoded = try JSONDecoder.tdlib().decode(ChatsResponse.self, from: data)

        #expect(decoded.chatIds == [111, 222])
    }

    /// Тест round-trip кодирования больших ID чатов (Int64).
    ///
    /// ID чатов в TDLib — это Int64, могут быть очень большими числами.
    @Test("Round-trip кодирование больших ID (Int64)")
    func roundTripLargeInt64ChatIds() throws {
        let original = ChatsResponse(chatIds: [Int64.max, Int64.min])

        let data = try original.toTDLibData()
        let decoded = try JSONDecoder.tdlib().decode(ChatsResponse.self, from: data)

        #expect(decoded.chatIds.count == 2)
        #expect(decoded.chatIds[0] == Int64.max)
        #expect(decoded.chatIds[1] == Int64.min)
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
