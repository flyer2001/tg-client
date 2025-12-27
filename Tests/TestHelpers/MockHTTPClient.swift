import Foundation
#if os(Linux)
import FoundationNetworking
#endif
@testable import DigestCore

/// Мок HTTP клиента для Component тестов.
///
/// **Дизайн:**
/// - Single-stub: `setStubResult()` для простых тестов
/// - Queue-based: `setStubQueue()` для retry сценариев (v0.4.0)
///
/// **Использование:**
/// ```swift
/// // Простой тест:
/// let mockClient = MockHTTPClient()
/// await mockClient.setStubResult(.success(validResponseData))
///
/// // Retry тест:
/// await mockClient.setStubQueue([
///     .failure(HTTPError.serverError(statusCode: 500, data: Data())),
///     .failure(HTTPError.serverError(statusCode: 503, data: Data())),
///     .success(validResponseData)  // success на 3й попытке
/// ])
/// ```
public actor MockHTTPClient: HTTPClientProtocol {
    /// Stub результата HTTP запроса (single-stub mode).
    private var stubResult: Result<Data, Error>?

    /// Queue результатов для retry сценариев (queue mode).
    private var stubQueue: [Result<Data, Error>] = []

    /// Счётчик вызовов send().
    private var _callCount: Int = 0

    /// История отправленных запросов (для проверки URL/body в тестах).
    private var _sentRequests: [URLRequest] = []

    public init() {}

    /// Устанавливает stub результат (single-stub mode).
    public func setStubResult(_ result: Result<Data, Error>) {
        self.stubResult = result
        self.stubQueue = []  // Очищаем queue при переключении в single-stub
    }

    /// Устанавливает очередь результатов для retry сценариев (queue mode).
    public func setStubQueue(_ queue: [Result<Data, Error>]) {
        self.stubQueue = queue
        self.stubResult = nil  // Очищаем single-stub при переключении в queue
    }

    /// Возвращает количество вызовов send().
    public var callCount: Int {
        _callCount
    }

    /// Возвращает историю отправленных запросов.
    public var sentRequests: [URLRequest] {
        _sentRequests
    }

    public func send(request: URLRequest) async throws -> Data {
        _callCount += 1
        _sentRequests.append(request)

        // Queue mode: берём следующий результат из очереди
        if !stubQueue.isEmpty {
            return try stubQueue.removeFirst().get()
        }

        // Single-stub mode
        guard let result = stubResult else {
            fatalError("MockHTTPClient: stubResult not configured. Set stubResult or stubQueue before calling send().")
        }
        return try result.get()
    }
}
