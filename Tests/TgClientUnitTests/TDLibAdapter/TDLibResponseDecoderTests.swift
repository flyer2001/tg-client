import Foundation
import Testing
import FoundationExtensions
@testable import TDLibAdapter

/// Unit-тесты для декодирования TDLib Response моделей через JSONDecoder.tdlib().
///
/// Проверяем что централизованный decoder:
/// - Корректно конвертирует snake_case JSON → camelCase Swift properties
/// - Обрабатывает явные CodingKeys (например, сохраняет оригинальные имена)
/// - Корректно декодирует сложные структуры (массивы, опциональные поля)
///
/// **TDLib JSON API:**
/// - Все ответы TDLib используют snake_case для полей
/// - Документация: https://core.telegram.org/tdlib/docs/td__json__client_8h.html
@Suite("JSONDecoder.tdlib() Unit Tests для Response моделей")
struct TDLibResponseDecoderTests {

    let decoder = JSONDecoder.tdlib()

    /// Проверяем что decoder корректно конвертирует snake_case в camelCase.
    ///
    /// UserResponse имеет поля firstName, lastName которые в JSON должны быть first_name, last_name.
    @Test("Decode UserResponse - проверка snake_case → camelCase конвертации")
    func decodeUserResponse() throws {
        // Given: JSON от TDLib в snake_case формате
        let json = """
        {
            "id": 12345,
            "first_name": "John",
            "last_name": "Doe",
            "username": "johndoe"
        }
        """
        let data = try #require(json.data(using: .utf8))

        // When: декодируем через .tdlib()
        let user = try decoder.decode(UserResponse.self, from: data)

        // Then: проверяем что поля корректно смаппились
        #expect(user.id == 12345)
        #expect(user.firstName == "John")
        #expect(user.lastName == "Doe")
        #expect(user.username == "johndoe")
    }

    /// Проверяем что decoder корректно обрабатывает опциональные поля.
    ///
    /// Если username отсутствует в JSON, должен быть nil в Swift.
    @Test("Decode UserResponse - опциональное поле")
    func decodeUserResponseWithoutUsername() throws {
        // Given: JSON без username
        let json = """
        {
            "id": 67890,
            "first_name": "Jane",
            "last_name": "Smith"
        }
        """
        let data = try #require(json.data(using: .utf8))

        // When: декодируем
        let user = try decoder.decode(UserResponse.self, from: data)

        // Then: username должен быть nil
        #expect(user.id == 67890)
        #expect(user.firstName == "Jane")
        #expect(user.lastName == "Smith")
        #expect(user.username == nil)
    }

    /// Проверяем что decoder корректно декодирует массивы с snake_case ключами.
    ///
    /// ChatsResponse содержит chatIds массив.
    @Test("Decode ChatsResponse - массив с snake_case ключом")
    func decodeChatsResponse() throws {
        // Given: JSON с массивом chat_ids (snake_case)
        let json = """
        {
            "chat_ids": [100, 200, 300]
        }
        """
        let data = try #require(json.data(using: .utf8))

        // When: декодируем
        let chats = try decoder.decode(ChatsResponse.self, from: data)

        // Then: chatIds должен быть массивом
        #expect(chats.chatIds == [100, 200, 300])
    }

    /// Проверяем что decoder корректно декодирует простые модели.
    ///
    /// TDLibErrorResponse - простая модель с code и message.
    @Test("Decode TDLibErrorResponse - простая модель")
    func decodeTDLibErrorResponse() throws {
        // Given: JSON ошибки
        let json = """
        {
            "code": 404,
            "message": "Not Found"
        }
        """
        let data = try #require(json.data(using: .utf8))

        // When: декодируем
        let error = try decoder.decode(TDLibErrorResponse.self, from: data)

        // Then: проверяем поля
        #expect(error.code == 404)
        #expect(error.message == "Not Found")
    }

    /// Проверяем что decoder корректно работает с пустыми массивами.
    @Test("Decode ChatsResponse - пустой массив")
    func decodeEmptyChatsResponse() throws {
        // Given: пустой массив чатов
        let json = """
        {
            "chat_ids": []
        }
        """
        let data = try #require(json.data(using: .utf8))

        // When
        let chats = try decoder.decode(ChatsResponse.self, from: data)

        // Then
        #expect(chats.chatIds.isEmpty)
    }
}
