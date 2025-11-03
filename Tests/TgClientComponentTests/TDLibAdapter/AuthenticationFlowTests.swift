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

        // Настраиваем mock ответы для каждого шага авторизации
        await mockClient.setMockResponse(
            for: SetAuthenticationPhoneNumberRequest.testWithPhone("+1234567890"),
            response: .success(.waitCode)
        )
        await mockClient.setMockResponse(
            for: CheckAuthenticationCodeRequest.testWith12345Code,
            response: .success(.ready)
        )

        // When: Отправляем номер телефона
        let phoneUpdate = try await mockClient.setAuthenticationPhoneNumber("+1234567890")

        // Then: Получаем состояние "ждём код"
        #expect(phoneUpdate.authorizationState.type == "authorizationStateWaitCode")

        // When: Отправляем код подтверждения
        let codeUpdate = try await mockClient.checkAuthenticationCode("12345")

        // Then: Авторизация успешна
        #expect(codeUpdate.authorizationState.type == "authorizationStateReady")
    }
}
