import Testing
import Foundation
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

    let decoder = JSONDecoder()

    /// Декодирование состояния "waitTdlibParameters".
    ///
    /// Первое состояние после создания TDLib клиента. TDLib ожидает параметры через `setTdlibParameters`.
    @Test("Декодирование AuthorizationStateUpdateResponse - waitTdlibParameters")
    func decodeAuthorizationStateWaitTdlibParameters() throws {
        // Given: JSON ответ от TDLib с состоянием waitTdlibParameters
        let json = """
        {
            "authorization_state": {
                "@type": "authorizationStateWaitTdlibParameters"
            }
        }
        """
        let data = Data(json.utf8)

        // When: декодируем JSON в модель AuthorizationStateUpdateResponse
        let response = try decoder.decode(AuthorizationStateUpdateResponse.self, from: data)

        // Then: поле authorizationState.type должно содержать "authorizationStateWaitTdlibParameters"
        #expect(response.authorizationState.type == "authorizationStateWaitTdlibParameters")
    }

    /// Декодирование состояния "waitPhoneNumber".
    ///
    /// TDLib ожидает номер телефона через `setAuthenticationPhoneNumber`.
    @Test("Декодирование AuthorizationStateUpdateResponse - waitPhoneNumber")
    func decodeAuthorizationStateWaitPhoneNumber() throws {
        // Given: JSON ответ от TDLib с состоянием waitPhoneNumber
        let json = """
        {
            "authorization_state": {
                "@type": "authorizationStateWaitPhoneNumber"
            }
        }
        """
        let data = Data(json.utf8)

        // When: декодируем JSON в модель
        let response = try decoder.decode(AuthorizationStateUpdateResponse.self, from: data)

        // Then: поле authorizationState.type должно содержать "authorizationStateWaitPhoneNumber"
        #expect(response.authorizationState.type == "authorizationStateWaitPhoneNumber")
    }

    /// Декодирование состояния "waitCode".
    ///
    /// TDLib отправил SMS код и ожидает его через `checkAuthenticationCode`.
    @Test("Декодирование AuthorizationStateUpdateResponse - waitCode")
    func decodeAuthorizationStateWaitCode() throws {
        // Given: JSON ответ от TDLib с состоянием waitCode
        let json = """
        {
            "authorization_state": {
                "@type": "authorizationStateWaitCode"
            }
        }
        """
        let data = Data(json.utf8)

        // When: декодируем JSON в модель
        let response = try decoder.decode(AuthorizationStateUpdateResponse.self, from: data)

        // Then: поле authorizationState.type должно содержать "authorizationStateWaitCode"
        #expect(response.authorizationState.type == "authorizationStateWaitCode")
    }

    /// Декодирование состояния "waitPassword".
    ///
    /// У пользователя включена 2FA. TDLib ожидает пароль через `checkAuthenticationPassword`.
    @Test("Декодирование AuthorizationStateUpdateResponse - waitPassword")
    func decodeAuthorizationStateWaitPassword() throws {
        // Given: JSON ответ от TDLib с состоянием waitPassword
        let json = """
        {
            "authorization_state": {
                "@type": "authorizationStateWaitPassword"
            }
        }
        """
        let data = Data(json.utf8)

        // When: декодируем JSON в модель
        let response = try decoder.decode(AuthorizationStateUpdateResponse.self, from: data)

        // Then: поле authorizationState.type должно содержать "authorizationStateWaitPassword"
        #expect(response.authorizationState.type == "authorizationStateWaitPassword")
    }

    /// Декодирование состояния "ready".
    ///
    /// Авторизация завершена успешно. TDLib готов к работе.
    @Test("Декодирование AuthorizationStateUpdateResponse - ready")
    func decodeAuthorizationStateReady() throws {
        // Given: JSON ответ от TDLib с состоянием ready
        let json = """
        {
            "authorization_state": {
                "@type": "authorizationStateReady"
            }
        }
        """
        let data = Data(json.utf8)

        // When: декодируем JSON в модель
        let response = try decoder.decode(AuthorizationStateUpdateResponse.self, from: data)

        // Then: поле authorizationState.type должно содержать "authorizationStateReady"
        #expect(response.authorizationState.type == "authorizationStateReady")
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
