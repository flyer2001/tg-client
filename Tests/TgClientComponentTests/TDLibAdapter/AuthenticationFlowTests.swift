import TgClientModels
import TGClientInterfaces
import Testing
import Foundation
import Logging
@testable import TDLibAdapter
import TestHelpers

/// Component-тесты для авторизации через TDLib с использованием high-level API.
///
/// Эти тесты проверяют полный flow авторизации с типобезопасным API,
/// используя MockTDLibFFI для изоляции от реального TDLib.
///
/// **Scope:**
/// - Авторизация по номеру телефона + код
/// - Авторизация с 2FA (пароль)
/// - Обработка ошибок (неверный код, неверный пароль)
///
/// **Related:**
/// - Unit-тесты моделей: `ResponseDecodingTests` (декодирование AuthorizationStateUpdateResponse)
/// - E2E тест: `scripts/manual_e2e_auth.sh` (реальный TDLib)
/// - TDLib docs: https://core.telegram.org/tdlib/docs/classtd_1_1td__api_1_1set_authentication_phone_number.html
@Suite("TDLibAdapter: Процесс авторизации (High-Level API)")
struct AuthenticationFlowTests {

    // MARK: - Phone + Code (Success)

    /// Тест успешной авторизации: phone → code → ready.
    ///
    /// **TDLib flow:**
    /// 1. `setAuthenticationPhoneNumber("+1234567890")` → unsolicited update `authorizationStateWaitCode`
    /// 2. `checkAuthenticationCode("12345")` → unsolicited update `authorizationStateReady`
    ///
    /// **Docs:** https://core.telegram.org/tdlib/docs/classtd_1_1td__api_1_1authorization_state.html
    @Test("Успешная авторизация: телефон + код")
    func authenticateWithPhoneAndCode() async throws {
        // Given: TDLibClient с MockTDLibFFI
        let mockFFI = MockTDLibFFI()
        let logger = Logger(label: "test") { _ in SwiftLogNoOpLogHandler() }
        let tdlibClient = TDLibClient(
            ffi: mockFFI,
            appLogger: logger,
            authorizationPollTimeout: 0.1,
            maxAuthorizationAttempts: 10,
            authorizationTimeout: 5
        )

        // Запускаем TDLib background loop для обработки updates
        tdlibClient.startUpdatesLoop()

        // Шаг 1: Мокаем setAuthenticationPhoneNumber → Ok (fire-and-forget)
        mockFFI.mockResponse(forRequestType: "setAuthenticationPhoneNumber", return: .success(OkResponse()))

        // Мокаем unsolicited update: authorizationStateWaitCode
        // Важно: update должен быть добавлен ПОСЛЕ вызова setAuthenticationPhoneNumber()
        // чтобы waiter успел зарегистрироваться
        Task {
            try await Task.sleep(for: .milliseconds(50))
            mockFFI.mockUpdate(AuthorizationStateUpdateResponse.waitCode)
        }

        // When: Отправляем номер телефона
        let phoneUpdate = try await tdlibClient.setAuthenticationPhoneNumber("+1234567890")

        // Then: Получаем состояние "ждём код"
        #expect(phoneUpdate.authorizationState.type == "authorizationStateWaitCode")

        // Шаг 2: Мокаем checkAuthenticationCode → Ok (fire-and-forget)
        mockFFI.mockResponse(forRequestType: "checkAuthenticationCode", return: .success(OkResponse()))

        // Мокаем unsolicited update: authorizationStateReady
        Task {
            try await Task.sleep(for: .milliseconds(50))
            mockFFI.mockUpdate(AuthorizationStateUpdateResponse.ready)
        }

        // When: Отправляем код подтверждения
        let codeUpdate = try await tdlibClient.checkAuthenticationCode("12345")

        // Then: Авторизация успешна
        #expect(codeUpdate.authorizationState.type == "authorizationStateReady")
    }

    // MARK: - Error Handling

    /// Тест обработки ошибки TDLib: неверный код авторизации.
    ///
    /// **TDLib error:**
    /// - checkAuthenticationCode("12345") → Ok
    /// - Но TDLib эмитит updateAuthorizationState с ошибкой (неверный код)
    ///
    /// **Проверяем:**
    /// - Ошибка пробрасывается как TDLibErrorResponse
    @Test("Обработка ошибок: неверный код авторизации")
    func errorHandlingInvalidCode() async throws {
        // Given: TDLibClient с MockTDLibFFI
        let mockFFI = MockTDLibFFI()
        let logger = Logger(label: "test") { _ in SwiftLogNoOpLogHandler() }
        let tdlibClient = TDLibClient(
            ffi: mockFFI,
            appLogger: logger,
            authorizationPollTimeout: 0.1,
            maxAuthorizationAttempts: 10,
            authorizationTimeout: 5
        )

        // Запускаем TDLib background loop для обработки updates
        tdlibClient.startUpdatesLoop()

        // Мокаем checkAuthenticationCode → Ok (fire-and-forget)
        mockFFI.mockResponse(forRequestType: "checkAuthenticationCode", return: .success(OkResponse()))

        // Мокаем unsolicited update: ERROR вместо authorizationStateReady
        let tdlibError = TDLibErrorResponse(code: 400, message: "PHONE_CODE_INVALID")
        Task {
            try await Task.sleep(for: .milliseconds(50))
            mockFFI.mockUpdate(tdlibError)
        }

        // When: Отправляем неверный код → ожидаем TDLibErrorResponse
        await #expect(throws: TDLibErrorResponse.self) {
            try await tdlibClient.checkAuthenticationCode("12345")
        }
    }
}
