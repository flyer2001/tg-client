import Foundation
@testable import TDLibAdapter

/// Mock реализация TDLibFFI для Unit-тестов и Component-тестов.
///
/// Имитирует поведение реального TDLib FFI слоя (CTDLibFFI):
/// - `send()` парсит JSON, находит замоканный ответ по @type, добавляет в FIFO очередь
/// - `receive()` возвращает первый pending response (FIFO)
///
/// ## loadChats специальная логика
///
/// `loadChats` имитирует реальное TDLib API поведение:
/// - Updates приходят асинхронно ПО ОДНОМУ (updateNewChat)
/// - loadChats возвращает Ok если есть ещё чаты
/// - loadChats возвращает 404 когда все чаты загружены
///
/// **Имитация асинхронности:** Updates добавляются в pendingResponses ДО Ok/404,
/// поэтому TDLibClient получит их через receive() по одному (как от реального TDLib).
final class MockTDLibFFI: TDLibFFI {

    /// Замоканные ответы для каждого типа запроса (FIFO очередь).
    private var mockedResponses: [String: [Result<any TDLibResponse, TDLibErrorResponse>]] = [:]

    /// Очередь updates для эмиссии через loadChats.
    private var queuedUpdates: [Update] = []

    /// Счётчик уже обработанных updates.
    private var updatesProcessed = 0

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

    /// Добавляет update в очередь для эмиссии через loadChats.
    ///
    /// **Имитация Real TDLib API:**
    /// - Updates эмитятся асинхронно ПО ОДНОМУ через receive()
    /// - Каждый вызов loadChats(limit: N) эмитит до N updates
    /// - loadChats возвращает Ok если есть ещё updates, 404 если закончились
    ///
    /// **Использование:**
    /// ```swift
    /// mockFFI.queueUpdate(.newChat(chat: chat1))
    /// mockFFI.queueUpdate(.newChat(chat: chat2))
    /// mockFFI.queueUpdate(.newChat(chat: chat3))
    ///
    /// // loadChats(limit: 2) → pendingResponses: [chat1, chat2, Ok]
    /// // loadChats(limit: 2) → pendingResponses: [chat3, 404]
    /// ```
    func queueUpdate(_ update: Update) {
        queuedUpdates.append(update)
    }

    func send(_ request: String) {
        guard let data = request.data(using: .utf8),
              let parsed = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let requestType = parsed["@type"] as? String else {
            fatalError("MockTDLibFFI.send(): invalid JSON or missing @type")
        }

        // Специальная логика для loadChats (имитация Real TDLib API)
        if requestType == "loadChats" {
            handleLoadChats(parsed: parsed)
            return
        }

        // Обычная FIFO логика для других запросов
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
            let encoder = JSONEncoder.tdlib()
            guard let data = try? encoder.encode(response),
                  let json = String(data: data, encoding: .utf8) else {
                fatalError("MockTDLibFFI.send(): failed to encode response")
            }
            jsonString = json
        case .failure(let error):
            let encoder = JSONEncoder.tdlib()
            guard let data = try? encoder.encode(error),
                  let json = String(data: data, encoding: .utf8) else {
                fatalError("MockTDLibFFI.send(): failed to encode error")
            }
            jsonString = json
        }

        pendingResponses.append(jsonString)
    }

    private func handleLoadChats(parsed: [String: Any]) {
        // Парсим limit из запроса
        let limit = (parsed["limit"] as? Int) ?? 100

        // Эмитим updates (до limit штук)
        let remaining = queuedUpdates.count - updatesProcessed
        let toEmit = min(limit, remaining)

        let encoder = JSONEncoder.tdlib()
        for i in 0..<toEmit {
            let update = queuedUpdates[updatesProcessed + i]
            guard let data = try? encoder.encode(update),
                  let json = String(data: data, encoding: .utf8) else {
                fatalError("MockTDLibFFI.handleLoadChats(): failed to encode update")
            }
            pendingResponses.append(json)
        }
        updatesProcessed += toEmit

        // Ok или 404
        if updatesProcessed >= queuedUpdates.count {
            // Все updates загружены → 404
            let error = TDLibErrorResponse(code: 404, message: "Not Found: chat list is empty")
            guard let data = try? encoder.encode(error),
                  let json = String(data: data, encoding: .utf8) else {
                fatalError("MockTDLibFFI.handleLoadChats(): failed to encode 404 error")
            }
            pendingResponses.append(json)
        } else {
            // Есть ещё updates → Ok
            let ok = OkResponse()
            guard let data = try? encoder.encode(ok),
                  let json = String(data: data, encoding: .utf8) else {
                fatalError("MockTDLibFFI.handleLoadChats(): failed to encode Ok")
            }
            pendingResponses.append(json)
        }
    }

    func receive(timeout: Double) -> String? {
        guard !pendingResponses.isEmpty else {
            return nil
        }
        return pendingResponses.removeFirst()
    }
}
