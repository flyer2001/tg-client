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
/// - Unit-тесты моделей: `ResponseDecodingTests` (декодирование AuthorizationStateUpdateResponse)
/// - E2E тест: `scripts/manual_e2e_auth.sh` (реальный TDLib)
/// - TDLib docs: https://core.telegram.org/tdlib/.claude/classtd_1_1td__api_1_1set_authentication_phone_number.html
@Suite("TDLibAdapter: Процесс авторизации (High-Level API)")
struct AuthenticationFlowTests {

    // MARK: - Phone + Code (Success)

    /// Тест успешной авторизации: phone → code → ready.
    ///
    /// **TDLib flow:**
    /// 1. `setAuthenticationPhoneNumber("+1234567890")` → `authorizationStateWaitCode`
    /// 2. `checkAuthenticationCode("12345")` → `authorizationStateReady`
    ///
    /// **Docs:** https://core.telegram.org/tdlib/.claude/classtd_1_1td__api_1_1authorization_state.html
    @Test("Успешная авторизация: телефон + код")
    func authenticateWithPhoneAndCode() async throws {
        // Given: Mock client который эмулирует успешную авторизацию
        let mockClient = MockTDLibClient()

        // Настраиваем mock ответы для каждого шага авторизации
        // Шаг 1: SetAuthenticationPhoneNumberRequest → AuthorizationStateUpdateResponse (waitCode)
        await mockClient.setMockResponse(
            for: SetAuthenticationPhoneNumberRequest.testWithPhone("+1234567890"),
            response: .success(AuthorizationStateUpdateResponse.waitCode)
        )
        // Шаг 2: CheckAuthenticationCodeRequest → AuthorizationStateUpdateResponse (ready)
        await mockClient.setMockResponse(
            for: CheckAuthenticationCodeRequest.testWith12345Code,
            response: .success(AuthorizationStateUpdateResponse.ready)
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

    // MARK: - Error Handling

    /// Тест обработки ошибки TDLib: неверный код авторизации.
    ///
    /// **TDLib error:**
    /// ```json
    /// {
    ///   "@type": "error",
    ///   "code": 400,
    ///   "message": "PHONE_CODE_INVALID"
    /// }
    /// ```
    ///
    /// **Проверяем:**
    /// - Ошибка пробрасывается как TDLibErrorResponse
    /// - Ошибка логируется в формате "TDLib error [code]: message"
    @Test("Обработка ошибок: неверный код авторизации + логирование")
    func errorHandlingInvalidCode() async throws {
        // Given: Mock logger для перехвата логов
        let mockLogger = MockLogger()
        let logger = mockLogger.makeLogger(label: "test")

        // Mock client с логгером
        let mockClient = MockTDLibClient(logger: logger)

        // Настраиваем mock: код неверный → ошибка
        // CheckAuthenticationCodeRequest → TDLibErrorResponse (PHONE_CODE_INVALID)
        let tdlibError = TDLibErrorResponse(code: 400, message: "PHONE_CODE_INVALID")
        await mockClient.setMockResponse(
            for: CheckAuthenticationCodeRequest.testWith12345Code,
            response: .failure(tdlibError) as Result<AuthorizationStateUpdateResponse, TDLibErrorResponse>
        )

        // When: Отправляем неверный код → ожидаем TDLibErrorResponse
        await #expect(throws: TDLibErrorResponse.self) {
            try await mockClient.checkAuthenticationCode("12345")
        }

        // Then: Проверяем что ошибка была залогирована
        #expect(mockLogger.messages.count == 1)

        let errorLog = mockLogger.messages[0]
        #expect(errorLog.level == .error)
        #expect(errorLog.message.contains("TDLib error [400]"))
        #expect(errorLog.message.contains("PHONE_CODE_INVALID"))

    }
}
