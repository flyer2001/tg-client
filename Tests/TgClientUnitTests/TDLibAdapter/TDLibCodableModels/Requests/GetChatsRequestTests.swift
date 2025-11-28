import TgClientModels
import TGClientInterfaces
import Testing
import Foundation
import TDLibAdapter

/// Unit-тесты для кодирования GetChatsRequest.
///
/// ## Описание модели
///
/// `GetChatsRequest` - запрос для получения списка чатов из указанного списка (main или archive).
///
/// **Структура:**
/// - `type` - всегда "getChats" (константа)
/// - `chatList: ChatList` - тип списка чатов (main/archive)
/// - `limit: Int` - максимальное количество чатов для получения
///
/// **Маппинг полей:**
/// - `type` → `@type`
/// - `chatList` → `chat_list` (вложенный объект с `@type`)
/// - `limit` → `limit`
///
/// ## Связь с TDLib API
///
/// Возвращает список ID чатов в порядке, определённом TDLib (обычно по времени последнего сообщения).
/// Для получения полной информации о чате используйте `getChat(chatId:)`.
///
/// **Документация TDLib:**
/// - Method: https://core.telegram.org/tdlib/docs/classtd_1_1td__api_1_1get_chats.html
/// - ChatList: https://core.telegram.org/tdlib/docs/classtd_1_1td__api_1_1chat_list.html
/// - ChatListMain: https://core.telegram.org/tdlib/docs/classtd_1_1td__api_1_1chat_list_main.html
/// - ChatListArchive: https://core.telegram.org/tdlib/docs/classtd_1_1td__api_1_1chat_list_archive.html
///
/// ## Пример JSON (main list)
///
/// ```json
/// {
///   "@type": "getChats",
///   "chat_list": {
///     "@type": "chatListMain"
///   },
///   "limit": 100
/// }
/// ```
///
/// ## Пример JSON (archive list)
///
/// ```json
/// {
///   "@type": "getChats",
///   "chat_list": {
///     "@type": "chatListArchive"
///   },
///   "limit": 50
/// }
/// ```
@Suite("Кодирование GetChatsRequest")
struct GetChatsRequestTests {

    let encoder = TDLibRequestEncoder()

    /// Кодирование запроса для получения чатов из основного списка.
    ///
    /// Проверяем корректную сериализацию chatList: .main в формат TDLib.
    @Test("Encode GetChatsRequest для main list")
    func encodeGetChatsRequestMainList() throws {
        // Given: создаем запрос для получения 100 чатов из основного списка
        let request = GetChatsRequest(chatList: .main, limit: 100)

        // When: кодируем запрос в JSON
        let data = try encoder.encode(request)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]

        // Then: JSON должен содержать правильную структуру
        // Ожидаем:
        // {
        //   "@type": "getChats",
        //   "chat_list": { "@type": "chatListMain" },
        //   "limit": 100
        // }
        #expect(json != nil)
        #expect(json?["@type"] as? String == "getChats")
        #expect(json?["limit"] as? Int == 100)

        // Проверка вложенного объекта chat_list
        let chatListJson = json?["chat_list"] as? [String: Any]
        #expect(chatListJson != nil, "chat_list должен быть объектом")
        #expect(chatListJson?["@type"] as? String == "chatListMain")
    }

    /// Кодирование запроса для получения чатов из архива.
    ///
    /// Проверяем корректную сериализацию chatList: .archive в формат TDLib.
    @Test("Encode GetChatsRequest для archive list")
    func encodeGetChatsRequestArchiveList() throws {
        // Given: создаем запрос для получения 50 чатов из архива
        let request = GetChatsRequest(chatList: .archive, limit: 50)

        // When: кодируем запрос в JSON
        let data = try encoder.encode(request)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]

        // Then: JSON должен содержать правильную структуру для архива
        // Ожидаем:
        // {
        //   "@type": "getChats",
        //   "chat_list": { "@type": "chatListArchive" },
        //   "limit": 50
        // }
        #expect(json != nil)
        #expect(json?["@type"] as? String == "getChats")
        #expect(json?["limit"] as? Int == 50)

        // Проверка вложенного объекта chat_list для архива
        let chatListJson = json?["chat_list"] as? [String: Any]
        #expect(chatListJson != nil, "chat_list должен быть объектом")
        #expect(chatListJson?["@type"] as? String == "chatListArchive")
    }

    /// Проверка snake_case маппинга для поля chat_list.
    ///
    /// TDLib ожидает `chat_list`, а не `chatList` (camelCase).
    @Test("Проверка snake_case маппинга")
    func verifyChatListSnakeCaseMapping() throws {
        // Given
        let request = GetChatsRequest(chatList: .main, limit: 100)

        // When
        let data = try encoder.encode(request)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]

        // Then: должен быть ключ chat_list (snake_case), а не chatList (camelCase)
        #expect(json?["chat_list"] != nil, "Должен быть ключ chat_list (snake_case)")
        #expect(json?["chatList"] == nil, "Не должно быть camelCase ключа chatList")
    }

    /// Проверка что limit передаётся без изменений.
    @Test("Проверка передачи limit")
    func verifyLimitEncoding() throws {
        // Given: различные значения limit
        let limits = [1, 50, 100, 200]

        for limit in limits {
            // When
            let request = GetChatsRequest(chatList: .main, limit: limit)
            let data = try encoder.encode(request)
            let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]

            // Then: limit должен совпадать
            #expect(json?["limit"] as? Int == limit, "limit должен быть \(limit)")
        }
    }
}
