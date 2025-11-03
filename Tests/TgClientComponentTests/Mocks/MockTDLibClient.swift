import Foundation
@testable import TDLibAdapter

/// Mock реализация TDLibClientProtocol для component-тестов.
///
/// Имитирует поведение реального TDLibClient: для каждого типа запроса возвращает настроенный response.
/// Использует actor для thread-safety.
///
/// **Использование:**
/// ```swift
/// let mockClient = MockTDLibClient()
///
/// // Настройка ответа для конкретного запроса
/// await mockClient.setMockResponse(
///     for: SetAuthenticationPhoneNumberRequest.testWithPhone("+1234567890"),
///     response: .success(.waitVerificationCode)
/// )
///
/// // Вызов метода - mock вернёт настроенный ответ для этого типа запроса
/// let state = try await mockClient.setAuthenticationPhoneNumber("+1234567890")
/// ```
actor MockTDLibClient: TDLibClientProtocol {

    // MARK: - Mock State

    /// Словарь с mock ответами для каждого типа запроса.
    ///
    /// Ключ - TDLibRequest.type (например, "setAuthenticationPhoneNumber")
    /// Значение - Result с успешным ответом или ошибкой
    private var mockResponses: [String: Result<AuthorizationState, TDLibError>] = [:]

    // MARK: - Initialization

    init() {}

    // MARK: - Public Methods for Test Setup

    /// Настраивает mock ответ для указанного TDLib запроса.
    ///
    /// Использует `request.type` как ключ для хранения ответа.
    ///
    /// **Пример:**
    /// ```swift
    /// await mockClient.setMockResponse(
    ///     for: CheckAuthenticationPasswordRequest.testWith12345Password,
    ///     response: .success(.ready)
    /// )
    /// ```
    ///
    /// - Parameters:
    ///   - request: TDLib запрос (используется только для получения `.type`)
    ///   - response: Result с состоянием авторизации или ошибкой
    func setMockResponse<T: TDLibRequest>(
        for request: T,
        response: Result<AuthorizationState, TDLibError>
    ) {
        mockResponses[request.type] = response
    }

    // MARK: - TDLibClientProtocol

    func setAuthenticationPhoneNumber(_ phoneNumber: String) async throws -> AuthorizationStateUpdate {
        let request = SetAuthenticationPhoneNumberRequest(phoneNumber: phoneNumber)
        return try getMockResponse(for: request)
    }

    func checkAuthenticationCode(_ code: String) async throws -> AuthorizationStateUpdate {
        let request = CheckAuthenticationCodeRequest(code: code)
        return try getMockResponse(for: request)
    }

    func checkAuthenticationPassword(_ password: String) async throws -> AuthorizationStateUpdate {
        let request = CheckAuthenticationPasswordRequest(password: password)
        return try getMockResponse(for: request)
    }

    // MARK: - Helper Methods

    /// Получает mock ответ для указанного запроса.
    ///
    /// Использует `request.type` для поиска настроенного ответа.
    /// Если ответ не настроен, бросает ошибку.
    ///
    /// - Parameter request: TDLib запрос
    /// - Returns: AuthorizationStateUpdate из настроенного состояния
    /// - Throws: MockError.responseNotConfigured если ответ не настроен, или TDLibError если настроен .failure
    private func getMockResponse<T: TDLibRequest>(for request: T) throws -> AuthorizationStateUpdate {
        guard let result = mockResponses[request.type] else {
            throw MockError.responseNotConfigured(requestType: request.type)
        }

        switch result {
        case .success(let state):
            return createAuthorizationStateUpdate(from: state)
        case .failure(let error):
            throw error
        }
    }

    /// Создаёт AuthorizationStateUpdate из AuthorizationState enum.
    ///
    /// Переиспользует существующие проверенные модели.
    /// AuthorizationState.rawValue уже содержит корректную строку типа TDLib.
    ///
    /// - Parameter state: Состояние авторизации
    /// - Returns: AuthorizationStateUpdate для указанного состояния
    private func createAuthorizationStateUpdate(from state: AuthorizationState) -> AuthorizationStateUpdate {
        return AuthorizationStateUpdate(
            authorizationState: AuthorizationStateInfo(type: state.rawValue)
        )
    }
}

// MARK: - Mock Errors

/// Ошибки MockTDLibClient.
enum MockError: Error, CustomStringConvertible {
    /// Response для типа запроса не был настроен в тесте
    case responseNotConfigured(requestType: String)

    var description: String {
        switch self {
        case .responseNotConfigured(let requestType):
            return """
            Mock response not configured for request type '\(requestType)'.

            Use: await mockClient.setMockResponse(for: <request>, response: .success(.ready))
            """
        }
    }
}

// MARK: - Test Helpers

/// Test helpers для создания TDLib запросов с предопределёнными параметрами.

extension SetAuthenticationPhoneNumberRequest {
    /// Тестовый запрос с номером телефона +1234567890
    static var testWithPhone: Self {
        SetAuthenticationPhoneNumberRequest(phoneNumber: "+1234567890")
    }

    /// Создаёт тестовый запрос с произвольным номером телефона
    static func testWithPhone(_ phone: String) -> Self {
        SetAuthenticationPhoneNumberRequest(phoneNumber: phone)
    }
}

extension CheckAuthenticationCodeRequest {
    /// Тестовый запрос с кодом 12345
    static var testWith12345Code: Self {
        CheckAuthenticationCodeRequest(code: "12345")
    }

    /// Создаёт тестовый запрос с произвольным кодом
    static func testWithCode(_ code: String) -> Self {
        CheckAuthenticationCodeRequest(code: code)
    }
}

extension CheckAuthenticationPasswordRequest {
    /// Тестовый запрос с паролем "my2FApassword"
    static var testWith2FAPassword: Self {
        CheckAuthenticationPasswordRequest(password: "my2FApassword")
    }

    /// Создаёт тестовый запрос с произвольным паролем
    static func testWithPassword(_ password: String) -> Self {
        CheckAuthenticationPasswordRequest(password: password)
    }
}
