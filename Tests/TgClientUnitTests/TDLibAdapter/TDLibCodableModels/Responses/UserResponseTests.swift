import Foundation
import Testing
import FoundationExtensions
@testable import TDLibAdapter

/// Тесты для модели UserResponse.
///
/// **TDLib API:** https://core.telegram.org/tdlib/.claude/classtd_1_1td__api_1_1user.html
///
/// TDLib возвращает информацию о пользователе при вызове метода `getMe`.
/// Используется для верификации успешной авторизации.
@Suite("Декодирование модели UserResponse")
struct UserResponseTests {

    /// Тест декодирования пользователя с полными данными.
    ///
    /// **Пример реального ответа TDLib на `getMe`:**
    ///
    /// ```json
    /// {
    ///   "@type": "user",
    ///   "id": 123456789,
    ///   "first_name": "John",
    ///   "last_name": "Doe",
    ///   "username": "johndoe"
    /// }
    /// ```
    ///
    /// **TDLib docs:** https://core.telegram.org/tdlib/.claude/classtd_1_1td__api_1_1get_me.html
    @Test("Декодирование пользователя с полными данными")
    func decodeUserWithFullData() throws {
        let json = """
        {
            "@type": "user",
            "id": 123456789,
            "first_name": "John",
            "last_name": "Doe",
            "username": "johndoe"
        }
        """

        let data = Data(json.utf8)
        let decoder = JSONDecoder.tdlib()
        let user = try decoder.decode(UserResponse.self, from: data)

        #expect(user.id == 123456789)
        #expect(user.firstName == "John")  // snake_case → camelCase
        #expect(user.lastName == "Doe")
        #expect(user.username == "johndoe")
    }

    /// Тест декодирования пользователя без username.
    ///
    /// Некоторые пользователи могут не иметь username.
    @Test("Декодирование пользователя без username")
    func decodeUserWithoutUsername() throws {
        let json = """
        {
            "@type": "user",
            "id": 987654321,
            "first_name": "Jane",
            "last_name": "Smith"
        }
        """

        let data = Data(json.utf8)
        let decoder = JSONDecoder.tdlib()
        let user = try decoder.decode(UserResponse.self, from: data)

        #expect(user.id == 987654321)
        #expect(user.firstName == "Jane")
        #expect(user.lastName == "Smith")
        #expect(user.username == nil)
    }

    /// Тест создания UserResponse программно (для тестов).
    @Test("Создание пользователя программно")
    func createUserProgrammatically() {
        let user = UserResponse(
            id: 111222333,
            firstName: "Test",
            lastName: "User",
            username: "testuser"
        )

        #expect(user.id == 111222333)
        #expect(user.firstName == "Test")
        #expect(user.lastName == "User")
        #expect(user.username == "testuser")
    }
}
