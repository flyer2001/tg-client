import Testing
import Foundation
@testable import TDLibAdapter

/// Unit-тесты для TDLibUpdate (обёртка для парсинга ответов TDLib).
///
/// Проверяют:
/// - Корректное определение типа по полю @type
/// - Декодирование в соответствующий case
/// - Обработку unknown типов
/// - Error handling (missing @type, invalid JSON)
@Suite("Парсинг TDLib обновлений")
struct TDLibUpdateTests {

    // MARK: - AuthorizationState updates

    @Test("Parse updateAuthorizationState")
    func parseUpdateAuthorizationState() throws {
        // Given
        let json: [String: Any] = [
            "@type": "updateAuthorizationState",
            "authorization_state": [
                "@type": "authorizationStateReady"
            ]
        ]

        // When
        let update = try TDLibUpdate(from: json)

        // Then
        guard case .authorizationState(let authUpdate) = update else {
            Issue.record("Expected authorizationState case")
            return
        }
        #expect(authUpdate.authorizationState.type == "authorizationStateReady")
    }

    @Test("Parse updateAuthorizationState - waitPhoneNumber")
    func parseUpdateAuthorizationStateWaitPhone() throws {
        // Given
        let json: [String: Any] = [
            "@type": "updateAuthorizationState",
            "authorization_state": [
                "@type": "authorizationStateWaitPhoneNumber"
            ]
        ]

        // When
        let update = try TDLibUpdate(from: json)

        // Then
        guard case .authorizationState(let authUpdate) = update else {
            Issue.record("Expected authorizationState case")
            return
        }
        #expect(authUpdate.authorizationState.type == "authorizationStateWaitPhoneNumber")
    }

    // MARK: - Error responses

    @Test("Parse error response")
    func parseErrorResponse() throws {
        // Given
        let json: [String: Any] = [
            "@type": "error",
            "code": 400,
            "message": "PHONE_NUMBER_INVALID"
        ]

        // When
        let update = try TDLibUpdate(from: json)

        // Then
        guard case .error(let error) = update else {
            Issue.record("Expected error case")
            return
        }
        #expect(error.code == 400)
        #expect(error.message == "PHONE_NUMBER_INVALID")
    }

    @Test("Parse error response - auth failed")
    func parseErrorAuthFailed() throws {
        // Given
        let json: [String: Any] = [
            "@type": "error",
            "code": 401,
            "message": "PHONE_CODE_INVALID"
        ]

        // When
        let update = try TDLibUpdate(from: json)

        // Then
        guard case .error(let error) = update else {
            Issue.record("Expected error case")
            return
        }
        #expect(error.code == 401)
        #expect(error.message == "PHONE_CODE_INVALID")
    }

    // MARK: - Unknown types (forward compatibility)

    @Test("Parse unknown type - fallback to .unknown")
    func parseUnknownType() throws {
        // Given
        let json: [String: Any] = [
            "@type": "updateNewMessage",
            "message": ["id": 123]
        ]

        // When
        let update = try TDLibUpdate(from: json)

        // Then
        guard case .unknown(let type) = update else {
            Issue.record("Expected unknown case")
            return
        }
        #expect(type == "updateNewMessage")
    }

    @Test("Parse ok response")
    func parseOkResponse() throws {
        // Given
        let json: [String: Any] = [
            "@type": "ok"
        ]

        // When
        let update = try TDLibUpdate(from: json)

        // Then
        guard case .ok = update else {
            Issue.record("Expected .ok case")
            return
        }
    }

    // MARK: - Error handling

    @Test("Parse fails on missing @type field")
    func parseFailsOnMissingTypeField() {
        // Given
        let json: [String: Any] = [
            "code": 400,
            "message": "Error"
        ]

        // Then
        #expect(throws: TDLibUpdateError.missingTypeField) {
            try TDLibUpdate(from: json)
        }
    }

    @Test("Parse fails on invalid structure")
    func parseFailsOnInvalidStructure() {
        // Given - @type есть, но структура не соответствует error
        let json: [String: Any] = [
            "@type": "error",
            "invalid_field": "value"
        ]

        // Then
        #expect(throws: Error.self) {
            try TDLibUpdate(from: json)
        }
    }

    @Test("Parse fails on empty JSON")
    func parseFailsOnEmptyJSON() {
        // Given
        let json: [String: Any] = [:]

        // Then
        #expect(throws: TDLibUpdateError.missingTypeField) {
            try TDLibUpdate(from: json)
        }
    }
}
