import Testing
import Foundation
import TDLibAdapter

/// Unit-тесты для кодирования CheckAuthenticationPasswordRequest.
///
/// ## Описание модели
///
/// `CheckAuthenticationPasswordRequest` - запрос для проверки пароля двухфакторной аутентификации (2FA).
/// Используется после получения состояния `authorizationStateWaitPassword`.
///
/// **Структура:**
/// - `type` - всегда "checkAuthenticationPassword" (константа)
/// - `password: String` - пароль 2FA пользователя
///
/// **Маппинг полей:**
/// - `type` → `@type`
/// - `password` → `password` (без изменений)
///
/// ## Связь с TDLib API
///
/// После успешной проверки пароля TDLib переходит в состояние `authorizationStateReady`.
///
/// **Документация TDLib:**
/// - https://core.telegram.org/tdlib/docs/classtd_1_1td__api_1_1check_authentication_password.html
@Suite("Кодирование CheckAuthenticationPasswordRequest")
struct CheckAuthenticationPasswordRequestTests {

    let encoder = TDLibRequestEncoder()

    /// Кодирование запроса с 2FA паролем.
    @Test("Encode CheckAuthenticationPasswordRequest")
    func encodeCheckAuthenticationPasswordRequest() throws {
        // Given: создаем запрос с 2FA паролем
        let request = CheckAuthenticationPasswordRequest(password: "secret")

        // When: кодируем запрос в JSON
        let data = try encoder.encode(request)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]

        // Then: JSON должен содержать @type и password
        // Ожидаем: {"@type": "checkAuthenticationPassword", "password": "secret"}
        #expect(json != nil)
        #expect(json?["@type"] as? String == "checkAuthenticationPassword")
        #expect(json?["password"] as? String == "secret")
    }
}
