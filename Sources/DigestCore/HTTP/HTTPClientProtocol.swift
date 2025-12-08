import Foundation
#if os(Linux)
import FoundationNetworking
#endif

/// Ошибки HTTP клиента.
public enum HTTPError: Error {
    /// Клиентская ошибка (4xx).
    ///
    /// Содержит status code и тело ответа. Data может быть пустая, но всегда присутствует.
    case clientError(statusCode: Int, data: Data)

    /// Серверная ошибка (5xx).
    ///
    /// Содержит status code и тело ответа. Data может быть пустая, но всегда присутствует.
    case serverError(statusCode: Int, data: Data)

    /// Невалидный ответ (не HTTPURLResponse).
    case invalidResponse
}

/// Протокол для HTTP клиента.
///
/// Абстракция для выполнения HTTP запросов. Клиент автоматически валидирует
/// статус коды и бросает `HTTPError` для не-2xx ответов.
public protocol HTTPClientProtocol: Sendable {
    /// Выполняет HTTP запрос.
    ///
    /// - Parameter request: URLRequest для выполнения
    /// - Returns: Data тела ответа при успешном статусе (2xx)
    /// - Throws: `HTTPError` при не-2xx статусах или сетевых ошибках
    func send(request: URLRequest) async throws -> Data
}
