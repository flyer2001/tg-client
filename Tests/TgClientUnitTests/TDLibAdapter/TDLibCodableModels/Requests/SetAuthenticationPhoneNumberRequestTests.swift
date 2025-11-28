import TgClientModels
import TGClientInterfaces
import Testing
import Foundation
import TDLibAdapter

/// Unit-тесты для кодирования SetAuthenticationPhoneNumberRequest.
///
/// ## Описание модели
///
/// `SetAuthenticationPhoneNumberRequest` - запрос для установки номера телефона при авторизации.
/// Первый шаг авторизации после получения состояния `authorizationStateWaitPhoneNumber`.
///
/// **Структура:**
/// - `type` - всегда "setAuthenticationPhoneNumber" (константа)
/// - `phoneNumber: String` - номер телефона в международном формате
///
/// **Маппинг полей:**
/// - `type` → `@type`
/// - `phoneNumber` → `phone_number` (camelCase → snake_case)
///
/// ## Связь с TDLib API
///
/// После вызова этого метода TDLib отправит SMS код на указанный номер
/// и перейдет в состояние `authorizationStateWaitCode`.
///
/// **Документация TDLib:**
/// - https://core.telegram.org/tdlib/docs/classtd_1_1td__api_1_1set_authentication_phone_number.html
///
/// ## Формат номера телефона
///
/// - Должен начинаться с `+`
/// - Только цифры после `+`
/// - Примеры: `+79001234567`, `+1234567890`
@Suite("Кодирование SetAuthenticationPhoneNumberRequest")
struct SetAuthenticationPhoneNumberRequestTests {

    let encoder = TDLibRequestEncoder()

    /// Кодирование запроса с номером телефона.
    ///
    /// Проверяем корректную сериализацию номера телефона в snake_case формат.
    @Test("Encode SetAuthenticationPhoneNumberRequest")
    func encodeSetAuthenticationPhoneNumberRequest() throws {
        // Given: создаем запрос с номером телефона в международном формате
        let request = SetAuthenticationPhoneNumberRequest(phoneNumber: "+79001234567")

        // When: кодируем запрос в JSON
        let data = try encoder.encode(request)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]

        // Then: JSON должен содержать @type и phone_number (НЕ phoneNumber)
        // Ожидаем: {"@type": "setAuthenticationPhoneNumber", "phone_number": "+79001234567"}
        #expect(json != nil)
        #expect(json?["@type"] as? String == "setAuthenticationPhoneNumber")
        #expect(json?["phone_number"] as? String == "+79001234567")

        // Проверка отсутствия camelCase ключа
        #expect(json?["phoneNumber"] == nil, "Не должно быть camelCase ключа phoneNumber")
    }
}
