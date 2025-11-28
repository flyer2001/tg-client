import TgClientModels
import TGClientInterfaces
import Testing
import Foundation
import FoundationExtensions
import TestHelpers
import TDLibAdapter

/// Unit-тесты для декодирования AuthorizationStateUpdateResponse.
///
/// ## Описание модели
///
/// `AuthorizationStateUpdateResponse` - обновление состояния авторизации от TDLib.
/// TDLib присылает это обновление при изменении состояния авторизации.
///
/// **Структура:**
/// - `type` - всегда "updateAuthorizationState" (константа)
/// - `authorizationState: AuthorizationStateInfo` - информация о новом состоянии
///
/// **Структура AuthorizationStateInfo:**
/// - `type: String` - тип состояния (маппинг с `@type` из JSON)
///
/// **Маппинг полей:**
/// - `authorization_state` → `authorizationState`
/// - `@type` → `type`
///
/// ## Связь с TDLib API
///
/// TDLib использует обновления типа `updateAuthorizationState` для передачи информации о текущем состоянии авторизации.
///
/// **Документация TDLib:**
/// - https://core.telegram.org/tdlib/docs/classtd_1_1td__api_1_1update_authorization_state.html
/// - https://core.telegram.org/tdlib/docs/classtd_1_1td__api_1_1authorization_state.html
///
/// ## Возможные состояния
///
/// - `authorizationStateWaitTdlibParameters` - ожидание параметров TDLib (первый шаг)
/// - `authorizationStateWaitPhoneNumber` - ожидание номера телефона
/// - `authorizationStateWaitCode` - ожидание SMS кода
/// - `authorizationStateWaitPassword` - ожидание 2FA пароля
/// - `authorizationStateReady` - авторизация завершена
///
/// ## Используется в
///
/// - `AuthenticationFlowTests` - component-тесты авторизации
@Suite("Декодирование AuthorizationStateUpdateResponse")
struct AuthorizationStateUpdateResponseTests {

    let decoder = JSONDecoder.tdlib()

    /// Round-trip кодирование состояния "waitTdlibParameters".
    ///
    /// Первое состояние после создания TDLib клиента. TDLib ожидает параметры через `setTdlibParameters`.
    @Test("Round-trip кодирование - waitTdlibParameters")
    func roundTripAuthorizationStateWaitTdlibParameters() throws {
        let stateInfo = AuthorizationStateInfo(type: "authorizationStateWaitTdlibParameters")
        let original = AuthorizationStateUpdateResponse(authorizationState: stateInfo)

        let data = try original.toTDLibData()
        let decoded = try decoder.decode(AuthorizationStateUpdateResponse.self, from: data)

        #expect(decoded.authorizationState.type == "authorizationStateWaitTdlibParameters")
    }

    /// Round-trip кодирование состояния "waitPhoneNumber".
    ///
    /// TDLib ожидает номер телефона через `setAuthenticationPhoneNumber`.
    @Test("Round-trip кодирование - waitPhoneNumber")
    func roundTripAuthorizationStateWaitPhoneNumber() throws {
        let stateInfo = AuthorizationStateInfo(type: "authorizationStateWaitPhoneNumber")
        let original = AuthorizationStateUpdateResponse(authorizationState: stateInfo)

        let data = try original.toTDLibData()
        let decoded = try decoder.decode(AuthorizationStateUpdateResponse.self, from: data)

        #expect(decoded.authorizationState.type == "authorizationStateWaitPhoneNumber")
    }

    /// Round-trip кодирование состояния "waitCode".
    ///
    /// TDLib отправил SMS код и ожидает его через `checkAuthenticationCode`.
    @Test("Round-trip кодирование - waitCode")
    func roundTripAuthorizationStateWaitCode() throws {
        let stateInfo = AuthorizationStateInfo(type: "authorizationStateWaitCode")
        let original = AuthorizationStateUpdateResponse(authorizationState: stateInfo)

        let data = try original.toTDLibData()
        let decoded = try decoder.decode(AuthorizationStateUpdateResponse.self, from: data)

        #expect(decoded.authorizationState.type == "authorizationStateWaitCode")
    }

    /// Round-trip кодирование состояния "waitPassword".
    ///
    /// У пользователя включена 2FA. TDLib ожидает пароль через `checkAuthenticationPassword`.
    @Test("Round-trip кодирование - waitPassword")
    func roundTripAuthorizationStateWaitPassword() throws {
        let stateInfo = AuthorizationStateInfo(type: "authorizationStateWaitPassword")
        let original = AuthorizationStateUpdateResponse(authorizationState: stateInfo)

        let data = try original.toTDLibData()
        let decoded = try decoder.decode(AuthorizationStateUpdateResponse.self, from: data)

        #expect(decoded.authorizationState.type == "authorizationStateWaitPassword")
    }

    /// Round-trip кодирование состояния "ready".
    ///
    /// Авторизация завершена успешно. TDLib готов к работе.
    @Test("Round-trip кодирование - ready")
    func roundTripAuthorizationStateReady() throws {
        let stateInfo = AuthorizationStateInfo(type: "authorizationStateReady")
        let original = AuthorizationStateUpdateResponse(authorizationState: stateInfo)

        let data = try original.toTDLibData()
        let decoded = try decoder.decode(AuthorizationStateUpdateResponse.self, from: data)

        #expect(decoded.authorizationState.type == "authorizationStateReady")
    }

    /// Обработка невалидного JSON.
    ///
    /// Проверяем что декодер выбрасывает ошибку при невалидном JSON.
    @Test("Декодирование падает на невалидном JSON")
    func decodeFailsOnInvalidJSON() {
        // Given: невалидный JSON (не является JSON объектом)
        let json = "not a json"
        let data = Data(json.utf8)

        // Then: декодирование должно выбросить ошибку (DecodingError)
        #expect(throws: Error.self) {
            try decoder.decode(AuthorizationStateUpdateResponse.self, from: data)
        }
    }

    /// Обработка отсутствующего обязательного поля.
    ///
    /// Проверяем что декодер выбрасывает ошибку если поле `authorization_state` отсутствует.
    @Test("Декодирование падает на отсутствующем обязательном поле")
    func decodeFailsOnMissingRequiredField() {
        // Given: JSON без обязательного поля authorization_state
        let json = "{}"
        let data = Data(json.utf8)

        // Then: декодирование должно выбросить DecodingError.keyNotFound
        #expect(throws: Error.self) {
            try decoder.decode(AuthorizationStateUpdateResponse.self, from: data)
        }
    }
}
