import Foundation
@testable import TDLibAdapter

/// Mock реализация TDLibFFI для Unit-тестов.
///
/// Имитирует поведение реального TDLib FFI слоя (CTDLibFFI):
/// - `send()` парсит JSON, находит замоканный ответ по @type, добавляет в FIFO очередь
/// - `receive()` возвращает первый pending response (FIFO)
///
/// ## FIFO Design
///
/// Не использует @extra (как и реальный ResponseWaiters).
/// Сопоставление только по requestType в FIFO порядке.
final class MockTDLibFFI: TDLibFFI {

    /// Замоканные ответы для каждого типа запроса (FIFO очередь).
    private var mockedResponses: [String: [Result<any TDLibResponse, TDLibErrorResponse>]] = [:]

    /// Pending JSON responses (FIFO).
    private var pendingResponses: [String] = []

    func create() throws {
        // Mock клиент уже готов
    }

    func mockResponse<Response: TDLibResponse>(
        forRequestType requestType: String,
        return result: Result<Response, TDLibErrorResponse>
    ) {
        switch result {
        case .success(let response):
            mockedResponses[requestType, default: []].append(.success(response))
        case .failure(let error):
            mockedResponses[requestType, default: []].append(.failure(error))
        }
    }

    func send(_ request: String) {
        guard let data = request.data(using: .utf8),
              let parsed = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let requestType = parsed["@type"] as? String else {
            fatalError("MockTDLibFFI.send(): invalid JSON or missing @type")
        }

        guard var queue = mockedResponses[requestType], !queue.isEmpty else {
            fatalError("MockTDLibFFI.send(): no mocked response for @type='\(requestType)'")
        }

        let result = queue.removeFirst()
        if queue.isEmpty {
            mockedResponses.removeValue(forKey: requestType)
        } else {
            mockedResponses[requestType] = queue
        }

        let jsonString: String
        switch result {
        case .success(let response):
            let encoder = JSONEncoder()
            guard let data = try? encoder.encode(response),
                  let json = String(data: data, encoding: .utf8) else {
                fatalError("MockTDLibFFI.send(): failed to encode response")
            }
            jsonString = json
        case .failure(let error):
            let encoder = JSONEncoder()
            guard let data = try? encoder.encode(error),
                  let json = String(data: data, encoding: .utf8) else {
                fatalError("MockTDLibFFI.send(): failed to encode error")
            }
            jsonString = json
        }

        pendingResponses.append(jsonString)
    }

    func receive(timeout: Double) -> String? {
        guard !pendingResponses.isEmpty else {
            return nil
        }
        return pendingResponses.removeFirst()
    }
}
