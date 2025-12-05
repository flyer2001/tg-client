import Foundation
import FoundationNetworking
@testable import DigestCore

/// Мок HTTP клиента для Component тестов.
///
/// **Дизайн:** Result-based stubbing - один stub на тест.
///
/// **Использование:**
/// ```swift
/// let mockClient = MockHTTPClient()
/// mockClient.stubResult = .success(validResponseData)
/// // или
/// mockClient.stubResult = .failure(HTTPError.clientError(statusCode: 401, data: errorData))
/// ```
///
/// **Будущие улучшения:**
/// - Queue-based: `[Result<Data, Error>]` для retry сценариев (v0.4.0+)
/// - Closure-based: `(URLRequest) -> Result` для сложных сценариев
public actor MockHTTPClient: HTTPClientProtocol {
    /// Stub результата HTTP запроса.
    ///
    /// **ВАЖНО:** Обязательно установить перед вызовом `send()`.
    private var stubResult: Result<Data, Error>?

    public init() {}

    /// Устанавливает stub результат (для actor isolation).
    public func setStubResult(_ result: Result<Data, Error>) {
        self.stubResult = result
    }

    public func send(request: URLRequest) async throws -> Data {
        guard let result = stubResult else {
            fatalError("MockHTTPClient: stubResult not configured. Set stubResult before calling send().")
        }
        return try result.get()
    }
}
