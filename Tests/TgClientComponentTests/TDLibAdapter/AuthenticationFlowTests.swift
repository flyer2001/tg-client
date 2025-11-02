import Testing
import Foundation
@testable import TDLibAdapter

/// Component-тесты для авторизации через TDLib с использованием high-level API.
///
/// Эти тесты проверяют полный flow авторизации с типобезопасным API,
/// используя MockTDLibClient для изоляции от реального TDLib.
///
/// **Scope:**
/// - Авторизация по номеру телефона + код
/// - Авторизация с 2FA (пароль)
/// - Обработка ошибок (неверный код, неверный пароль)
///
/// **Related:**
/// - Unit-тесты моделей: `ResponseDecodingTests` (декодирование AuthorizationStateUpdate)
/// - E2E тест: `scripts/manual_e2e_auth.sh` (реальный TDLib)
/// - TDLib docs: https://core.telegram.org/tdlib/docs/classtd_1_1td__api_1_1set_authentication_phone_number.html
@Suite("TDLibAdapter: Authentication Flow (High-Level API)")
struct AuthenticationFlowTests {

    // MARK: - Phone + Code (Success)

    /// Тест успешной авторизации: phone → code → ready.
    ///
    /// **TDLib flow:**
    /// 1. `setAuthenticationPhoneNumber("+1234567890")` → `authorizationStateWaitCode`
    /// 2. `checkAuthenticationCode("12345")` → `authorizationStateReady`
    ///
    /// **Docs:** https://core.telegram.org/tdlib/docs/classtd_1_1td__api_1_1authorization_state.html
    @Test("Successful authentication: phone + code")
    func authenticateWithPhoneAndCode() async throws {
        // Given: Mock client который эмулирует успешную авторизацию
        let mockClient = MockTDLibClient()
        mockClient.stubAuthorizationFlow([
            .waitPhoneNumber,
            .waitCode,
            .ready
        ])

        // When: Отправляем номер телефона
        let phoneState = try await mockClient.setAuthenticationPhoneNumber("+1234567890")

        // Then: Получаем состояние "ждём код"
        #expect(phoneState == .waitCode)

        // When: Отправляем код подтверждения
        let codeState = try await mockClient.checkAuthenticationCode("12345")

        // Then: Авторизация успешна
        #expect(codeState == .ready)
    }
}

// MARK: - Mock TDLib Client

/// Mock-реализация TDLibClientProtocol для component-тестов.
///
/// Позволяет эмулировать различные сценарии авторизации без реального TDLib.
final class MockTDLibClient: TDLibClientProtocol {

    private var stubbedFlow: [AuthorizationState] = []
    private var currentFlowIndex = 0

    /// Настроить mock для возврата последовательности состояний авторизации.
    func stubAuthorizationFlow(_ states: [AuthorizationState]) {
        self.stubbedFlow = states
        self.currentFlowIndex = 0
    }

    // MARK: - TDLibClientProtocol Implementation

    func setAuthenticationPhoneNumber(_ phoneNumber: String) async throws -> AuthorizationState {
        return try nextState()
    }

    func checkAuthenticationCode(_ code: String) async throws -> AuthorizationState {
        return try nextState()
    }

    func checkAuthenticationPassword(_ password: String) async throws -> AuthorizationState {
        return try nextState()
    }

    // MARK: - Helpers

    private func nextState() throws -> AuthorizationState {
        guard currentFlowIndex < stubbedFlow.count else {
            throw TDLibError(code: -1, message: "Mock flow exhausted")
        }
        let state = stubbedFlow[currentFlowIndex]
        currentFlowIndex += 1
        return state
    }
}
