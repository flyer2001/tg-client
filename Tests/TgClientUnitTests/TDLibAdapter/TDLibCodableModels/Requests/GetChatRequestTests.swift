import Testing
import Foundation
import TDLibAdapter

/// Unit-тесты для кодирования GetChatRequest.
///
/// ## Описание модели
///
/// `GetChatRequest` - запрос для получения полной информации о чате по его ID.
///
/// **Структура:**
/// - `type` - всегда "getChat" (константа)
/// - `chatId: Int64` - уникальный идентификатор чата
///
/// **Маппинг полей:**
/// - `type` → `@type`
/// - `chatId` → `chat_id`
///
/// ## Связь с TDLib API
///
/// Возвращает объект Chat с полной информацией о чате: title, type, unreadCount, lastReadInboxMessageId и др.
/// Метод работает offline если текущий пользователь не бот.
///
/// **Документация TDLib:**
/// - Method: https://core.telegram.org/tdlib/docs/classtd_1_1td__api_1_1get_chat.html
/// - Chat: https://core.telegram.org/tdlib/docs/classtd_1_1td__api_1_1chat.html
///
/// ## Пример JSON
///
/// ```json
/// {
///   "@type": "getChat",
///   "chat_id": 123456789
/// }
/// ```
@Suite("Кодирование GetChatRequest")
struct GetChatRequestTests {

    let encoder = TDLibRequestEncoder()

    /// Кодирование базового запроса для получения чата.
    @Test("Encode GetChatRequest с базовым chatId")
    func encodeGetChatRequestBasic() throws {
        // Given: создаем запрос для получения чата с ID 123456789
        let request = GetChatRequest(chatId: 123456789)

        // When: кодируем запрос в JSON
        let data = try encoder.encode(request)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]

        // Then: JSON должен содержать правильную структуру
        #expect(json != nil)
        #expect(json?["@type"] as? String == "getChat")
        #expect(json?["chat_id"] as? Int64 == 123456789)
    }

    /// Проверка кодирования отрицательных chat ID.
    ///
    /// Некоторые чаты (особенно приватные и секретные) могут иметь отрицательные ID.
    @Test("Encode GetChatRequest с отрицательным chatId")
    func encodeGetChatRequestNegativeId() throws {
        // Given: отрицательный chatId (типичный для приватных чатов)
        let request = GetChatRequest(chatId: -100123456789)

        // When
        let data = try encoder.encode(request)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]

        // Then: отрицательный ID должен быть сохранен
        #expect(json?["@type"] as? String == "getChat")
        #expect(json?["chat_id"] as? Int64 == -100123456789)
    }

    /// Проверка что различные chat ID корректно энкодятся.
    @Test("Проверка различных chat ID значений")
    func verifyDifferentChatIds() throws {
        // Given: различные значения chatId (включая edge cases)
        let chatIds: [Int64] = [1, 100, 123456789, -100123456789, Int64.max]

        for chatId in chatIds {
            // When
            let request = GetChatRequest(chatId: chatId)
            let data = try encoder.encode(request)
            let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]

            // Then: chatId должен совпадать
            #expect(json?["chat_id"] as? Int64 == chatId, "chat_id должен быть \(chatId)")
        }
    }
}
