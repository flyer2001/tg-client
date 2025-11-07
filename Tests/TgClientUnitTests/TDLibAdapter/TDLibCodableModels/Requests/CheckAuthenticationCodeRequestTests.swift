import Testing
import Foundation
import TDLibAdapter

/// Unit-тесты для кодирования CheckAuthenticationCodeRequest.
///
/// ## Описание модели
///
/// `CheckAuthenticationCodeRequest` - запрос для проверки кода подтверждения из SMS.
/// Используется после получения состояния `authorizationStateWaitCode`.
///
/// **Структура:**
/// - `type` - всегда "checkAuthenticationCode" (константа)
/// - `code: String` - код подтверждения из SMS или Telegram
///
/// **Маппинг полей:**
/// - `type` → `@type`
/// - `code` → `code` (без изменений)
///
/// ## Связь с TDLib API
///
/// После успешной проверки кода TDLib переходит в состояние:
/// - `authorizationStateWaitPassword` (если включена 2FA)
/// - `authorizationStateReady` (если 2FA отключена)
///
/// **Документация TDLib:**
/// - https://core.telegram.org/tdlib/docs/classtd_1_1td__api_1_1check_authentication_code.html
@Suite("Кодирование CheckAuthenticationCodeRequest")
struct CheckAuthenticationCodeRequestTests {

    let encoder = TDLibRequestEncoder()

    /// Кодирование запроса с SMS кодом.
    @Test("Encode CheckAuthenticationCodeRequest")
    func encodeCheckAuthenticationCodeRequest() throws {
        // Given: создаем запрос с SMS кодом
        let request = CheckAuthenticationCodeRequest(code: "12345")

        // When: кодируем запрос в JSON
        let data = try encoder.encode(request)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]

        // Then: JSON должен содержать @type и code
        // Ожидаем: {"@type": "checkAuthenticationCode", "code": "12345"}
        #expect(json != nil)
        #expect(json?["@type"] as? String == "checkAuthenticationCode")
        #expect(json?["code"] as? String == "12345")
    }
}
