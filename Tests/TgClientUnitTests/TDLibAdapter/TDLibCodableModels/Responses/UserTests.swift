import Foundation
import Testing
@testable import TDLibAdapter

/// Тесты для модели User.
///
/// **TDLib API:** https://core.telegram.org/tdlib/.claude/classtd_1_1td__api_1_1user.html
///
/// TDLib возвращает информацию о пользователе при вызове метода `getMe`.
/// Используется для верификации успешной авторизации.
@Suite("User model decoding")
struct UserTests {

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
    @Test("Decode user with full data")
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
        let decoder = JSONDecoder()
        let user = try decoder.decode(User.self, from: data)

        #expect(user.id == 123456789)
        #expect(user.firstName == "John")  // snake_case → camelCase
        #expect(user.lastName == "Doe")
        #expect(user.username == "johndoe")
    }

    /// Тест декодирования пользователя без username.
    ///
    /// Некоторые пользователи могут не иметь username.
    @Test("Decode user without username")
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
        let decoder = JSONDecoder()
        let user = try decoder.decode(User.self, from: data)

        #expect(user.id == 987654321)
        #expect(user.firstName == "Jane")
        #expect(user.lastName == "Smith")
        #expect(user.username == nil)
    }

    /// Тест создания User программно (для тестов).
    @Test("Create user programmatically")
    func createUserProgrammatically() {
        let user = User(
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
