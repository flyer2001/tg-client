import Foundation
#if os(Linux)
import FoundationNetworking
#endif

/// Продакшн реализация HTTP клиента через URLSession.
public actor URLSessionHTTPClient: HTTPClientProtocol {
    public init() {}

    public func send(request: URLRequest) async throws -> Data {
        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw HTTPError.invalidResponse
        }

        switch httpResponse.statusCode {
        case 200..<300:
            return data
        case 400..<500:
            throw HTTPError.clientError(statusCode: httpResponse.statusCode, data: data)
        case 500..<600:
            throw HTTPError.serverError(statusCode: httpResponse.statusCode, data: data)
        default:
            throw HTTPError.invalidResponse
        }
    }
}
