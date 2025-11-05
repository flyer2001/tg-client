import Testing
import Foundation
@testable import TDLibAdapter

/// Unit-тесты для декодирования Response моделей TDLib.
///
/// Проверяют корректность декодирования JSON ответов от TDLib:
/// - Правильный snake_case маппинг (snake_case → camelCase)
/// - Корректная обработка вложенных структур
/// - Обработка ошибок
@Suite("Декодирование Response моделей")
struct ResponseDecodingTests {

    let decoder = JSONDecoder()

    // MARK: - AuthorizationStateUpdate

    @Test("Декодирование AuthorizationStateUpdate - waitTdlibParameters")
    func decodeAuthorizationStateWaitTdlibParameters() throws {
        // Given
        let json = """
        {
            "authorization_state": {
                "@type": "authorizationStateWaitTdlibParameters"
            }
        }
        """
        let data = Data(json.utf8)

        // When
        let response = try decoder.decode(AuthorizationStateUpdate.self, from: data)

        // Then
        #expect(response.authorizationState.type == "authorizationStateWaitTdlibParameters")
    }

    @Test("Декодирование AuthorizationStateUpdate - waitPhoneNumber")
    func decodeAuthorizationStateWaitPhoneNumber() throws {
        // Given
        let json = """
        {
            "authorization_state": {
                "@type": "authorizationStateWaitPhoneNumber"
            }
        }
        """
        let data = Data(json.utf8)

        // When
        let response = try decoder.decode(AuthorizationStateUpdate.self, from: data)

        // Then
        #expect(response.authorizationState.type == "authorizationStateWaitPhoneNumber")
    }

    @Test("Декодирование AuthorizationStateUpdate - waitCode")
    func decodeAuthorizationStateWaitCode() throws {
        // Given
        let json = """
        {
            "authorization_state": {
                "@type": "authorizationStateWaitCode"
            }
        }
        """
        let data = Data(json.utf8)

        // When
        let response = try decoder.decode(AuthorizationStateUpdate.self, from: data)

        // Then
        #expect(response.authorizationState.type == "authorizationStateWaitCode")
    }

    @Test("Декодирование AuthorizationStateUpdate - waitPassword")
    func decodeAuthorizationStateWaitPassword() throws {
        // Given
        let json = """
        {
            "authorization_state": {
                "@type": "authorizationStateWaitPassword"
            }
        }
        """
        let data = Data(json.utf8)

        // When
        let response = try decoder.decode(AuthorizationStateUpdate.self, from: data)

        // Then
        #expect(response.authorizationState.type == "authorizationStateWaitPassword")
    }

    @Test("Декодирование AuthorizationStateUpdate - ready")
    func decodeAuthorizationStateReady() throws {
        // Given
        let json = """
        {
            "authorization_state": {
                "@type": "authorizationStateReady"
            }
        }
        """
        let data = Data(json.utf8)

        // When
        let response = try decoder.decode(AuthorizationStateUpdate.self, from: data)

        // Then
        #expect(response.authorizationState.type == "authorizationStateReady")
    }

    // MARK: - TDLibError

    @Test("Декодирование TDLibError")
    func decodeTDLibError() throws {
        // Given
        let json = """
        {
            "code": 400,
            "message": "PHONE_NUMBER_INVALID"
        }
        """
        let data = Data(json.utf8)

        // When
        let error = try decoder.decode(TDLibError.self, from: data)

        // Then
        #expect(error.code == 400)
        #expect(error.message == "PHONE_NUMBER_INVALID")
        #expect(error.type == "error")
    }

    @Test("Декодирование TDLibError - network timeout")
    func decodeTDLibErrorNetworkTimeout() throws {
        // Given
        let json = """
        {
            "code": 500,
            "message": "Network timeout"
        }
        """
        let data = Data(json.utf8)

        // When
        let error = try decoder.decode(TDLibError.self, from: data)

        // Then
        #expect(error.code == 500)
        #expect(error.message == "Network timeout")
    }

    @Test("Декодирование TDLibError - auth failed")
    func decodeTDLibErrorAuthFailed() throws {
        // Given
        let json = """
        {
            "code": 401,
            "message": "PHONE_CODE_INVALID"
        }
        """
        let data = Data(json.utf8)

        // When
        let error = try decoder.decode(TDLibError.self, from: data)

        // Then
        #expect(error.code == 401)
        #expect(error.message == "PHONE_CODE_INVALID")
    }

    // MARK: - Invalid JSON handling

    @Test("Декодирование падает на невалидном JSON")
    func decodeFailsOnInvalidJSON() {
        // Given
        let json = "not a json"
        let data = Data(json.utf8)

        // Then
        #expect(throws: Error.self) {
            try decoder.decode(AuthorizationStateUpdate.self, from: data)
        }
    }

    @Test("Декодирование падает на отсутствующем обязательном поле")
    func decodeFailsOnMissingRequiredField() {
        // Given - missing authorization_state
        let json = "{}"
        let data = Data(json.utf8)

        // Then
        #expect(throws: Error.self) {
            try decoder.decode(AuthorizationStateUpdate.self, from: data)
        }
    }
}
