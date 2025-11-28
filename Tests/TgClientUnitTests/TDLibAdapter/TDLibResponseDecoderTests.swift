import TgClientModels
import TGClientInterfaces
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
}
