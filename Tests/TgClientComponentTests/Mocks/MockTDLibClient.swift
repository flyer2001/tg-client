import Foundation
import Logging
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
    /// Ключ - TDLibRequest.type (например, "setAuthenticationPhoneNumber", "getMe")
    /// Значение - Result с TDLibResponse (любого типа) или ошибкой
    private var mockResponses: [String: Result<any TDLibResponse, TDLibErrorResponse>] = [:]

    /// Logger для записи событий (опционально, для тестов логирования)
    private let logger: Logger?

    // MARK: - Initialization

    /// Инициализирует MockTDLibClient.
    ///
    /// - Parameter logger: Опциональный logger для проверки логирования в тестах
    init(logger: Logger? = nil) {
        self.logger = logger
    }

    // MARK: - Public Methods for Test Setup

    /// Настраивает mock ответ для указанного TDLib запроса.
    ///
    /// Использует `request.type` как ключ для хранения ответа.
    ///
    /// **Примеры:**
    /// ```swift
    /// // Для методов авторизации - передаём AuthorizationStateUpdateResponse
    /// await mockClient.setMockResponse(
    ///     for: CheckAuthenticationPasswordRequest.testWith2FAPassword,
    ///     response: .success(AuthorizationStateUpdateResponse(authorizationState: AuthorizationStateInfo(type: "authorizationStateReady")))
    /// )
    ///
    /// // Для getMe - передаём UserResponse
    /// await mockClient.setMockResponse(
    ///     for: GetMeRequest(),
    ///     response: .success(UserResponse(id: 123, firstName: "John", lastName: "Doe"))
    /// )
    /// ```
    ///
    /// - Parameters:
    ///   - request: TDLib запрос (используется только для получения `.type`)
    ///   - response: Result с TDLibResponse или ошибкой
    func setMockResponse<Request: TDLibRequest, Response: TDLibResponse>(
        for request: Request,
        response: Result<Response, TDLibErrorResponse>
    ) {
        mockResponses[request.type] = response.map { $0 as any TDLibResponse }
    }

    // MARK: - TDLibClientProtocol

    func setAuthenticationPhoneNumber(_ phoneNumber: String) async throws -> AuthorizationStateUpdateResponse {
        let request = SetAuthenticationPhoneNumberRequest(phoneNumber: phoneNumber)
        return try getMockResponse(for: request)
    }

    func checkAuthenticationCode(_ code: String) async throws -> AuthorizationStateUpdateResponse {
        let request = CheckAuthenticationCodeRequest(code: code)
        return try getMockResponse(for: request)
    }

    func checkAuthenticationPassword(_ password: String) async throws -> AuthorizationStateUpdateResponse {
        let request = CheckAuthenticationPasswordRequest(password: password)
        return try getMockResponse(for: request)
    }

    func getMe() async throws -> UserResponse {
        let request = GetMeRequest()
        return try getMockResponse(for: request)
    }

    func getChats(chatList: ChatList, limit: Int) async throws -> ChatsResponse {
        let request = GetChatsRequest(chatList: chatList, limit: limit)
        return try getMockResponse(for: request)
    }

    // MARK: - Helper Methods

    /// Получает mock ответ для указанного запроса.
    ///
    /// Использует `request.type` для поиска настроенного ответа.
    /// Если ответ не настроен, бросает ошибку.
    ///
    /// - Parameter request: TDLib запрос
    /// - Returns: Ответ указанного типа
    /// - Throws: MockError.responseNotConfigured если ответ не настроен, или TDLibErrorResponse если настроен .failure
    private func getMockResponse<Request: TDLibRequest, Response: TDLibResponse>(for request: Request) throws -> Response {
        guard let result = mockResponses[request.type] else {
            throw MockError.responseNotConfigured(requestType: request.type)
        }

        switch result {
        case .success(let response):
            guard let typedResponse = response as? Response else {
                fatalError("Mock configured with wrong response type for '\(request.type)'. Expected \(Response.self), got \(type(of: response))")
            }
            return typedResponse
        case .failure(let error):
            // Логируем ошибку (аналогично реальному TDLibClient)
            logger?.error("TDLib error [\(error.code)]: \(error.message)")
            throw error
        }
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

// MARK: - AuthorizationStateUpdateResponse Test Helpers

extension AuthorizationStateUpdateResponse {
    /// Создаёт update для состояния "waiting for code"
    static var waitCode: Self {
        AuthorizationStateUpdateResponse(authorizationState: AuthorizationStateInfo(type: "authorizationStateWaitCode"))
    }

    /// Создаёт update для состояния "waiting for password"
    static var waitPassword: Self {
        AuthorizationStateUpdateResponse(authorizationState: AuthorizationStateInfo(type: "authorizationStateWaitPassword"))
    }

    /// Создаёт update для состояния "ready"
    static var ready: Self {
        AuthorizationStateUpdateResponse(authorizationState: AuthorizationStateInfo(type: "authorizationStateReady"))
    }
}
