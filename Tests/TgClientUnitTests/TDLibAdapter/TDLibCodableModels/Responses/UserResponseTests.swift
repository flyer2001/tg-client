import Foundation
import Testing
import FoundationExtensions
import TestHelpers
@testable import TDLibAdapter

/// Тесты для модели UserResponse.
///
/// **TDLib API:** https://core.telegram.org/tdlib/.claude/classtd_1_1td__api_1_1user.html
///
/// TDLib возвращает информацию о пользователе при вызове метода `getMe`.
/// Используется для верификации успешной авторизации.
@Suite("Декодирование модели UserResponse")
struct UserResponseTests {

    /// Тест round-trip кодирования пользователя с полными данными.
    ///
    /// Проверяет что модель корректно encode/decode через TDLib encoder/decoder.
    ///
    /// **TDLib docs:** https://core.telegram.org/tdlib/.claude/classtd_1_1td__api_1_1get_me.html
    @Test("Round-trip кодирование пользователя с полными данными")
    func roundTripUserWithFullData() throws {
        let original = UserResponse(
            id: 123456789,
            firstName: "John",
            lastName: "Doe",
            username: "johndoe"
        )

        let data = try original.toTDLibData()
        let decoded = try JSONDecoder.tdlib().decode(UserResponse.self, from: data)

        #expect(decoded.id == 123456789)
        #expect(decoded.firstName == "John")
        #expect(decoded.lastName == "Doe")
        #expect(decoded.username == "johndoe")
    }

    /// Тест round-trip кодирования пользователя без username.
    ///
    /// Проверяет корректную обработку опциональных полей.
    @Test("Round-trip кодирование пользователя без username")
    func roundTripUserWithoutUsername() throws {
        let original = UserResponse(
            id: 987654321,
            firstName: "Jane",
            lastName: "Smith",
            username: nil
        )

        let data = try original.toTDLibData()
        let decoded = try JSONDecoder.tdlib().decode(UserResponse.self, from: data)

        #expect(decoded.id == 987654321)
        #expect(decoded.firstName == "Jane")
        #expect(decoded.lastName == "Smith")
        #expect(decoded.username == nil)
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
