import TgClientModels
import TGClientInterfaces
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
///
/// ## Thread Safety
///
/// **NSLock** защищает shared mutable state:
/// - `send()` thread-safe (можно вызывать из разных потоков)
/// - `receive()` thread-safe, НО ДОЛЖЕН вызываться только из одного потока (serial DispatchQueue)
///   для имитации реального TDLib API behaviour
///
/// При первом вызове `receive()` запоминается текущий pthread, последующие вызовы
/// проверяют что поток не изменился (через `precondition`).
public final class MockTDLibFFI: TDLibFFI {

    /// Lock для защиты shared mutable state (mockedResponses, pendingResponses, queuedUpdates).
    private let lock = NSLock()

    /// Замоканные ответы для каждого типа запроса (FIFO очередь).
    private var mockedResponses: [String: [Result<any TDLibResponse, TDLibErrorResponse>]] = [:]

    /// Очередь updates для эмиссии через loadChats.
    private var queuedUpdates: [Update] = []

    /// Счётчик уже обработанных updates.
    private var updatesProcessed = 0

    /// Pending JSON responses (FIFO).
    private var pendingResponses: [String] = []

    /// Поток, на котором был первый вызов receive().
    /// Используется для проверки thread safety (как в CTDLibFFI).
    private var expectedThread: pthread_t?

    /// Счётчик для генерации уникального @extra.
    private var extraCounter: UInt64 = 0

    public init() {}

    public func create() throws {
        // Mock клиент уже готов
    }

    public func mockResponse<Response: TDLibResponse>(
        forRequestType requestType: String,
        return result: Result<Response, TDLibErrorResponse>
    ) {
        lock.lock()
        defer { lock.unlock() }

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
    public func queueUpdate(_ update: Update) {
        lock.lock()
        defer { lock.unlock() }

        queuedUpdates.append(update)
    }

    /// Эмитит update напрямую в pendingResponses (БЕЗ loadChats).
    ///
    /// **Использование в тестах:**
    /// Для unit-тестов которые проверяют обработку updates без loadChats API.
    /// Например, тесты на race condition в updates stream initialization.
    ///
    /// ```swift
    /// mockFFI.mockUpdate(.chatReadInbox(chatId: 123, lastReadInboxMessageId: 10, unreadCount: 0))
    /// // Сразу доступно через receive()
    /// ```
    public func mockUpdate(_ update: Update) {
        lock.lock()
        defer { lock.unlock() }

        let encoder = JSONEncoder.tdlib()
        guard let data = try? encoder.encode(update),
              let json = String(data: data, encoding: .utf8) else {
            fatalError("MockTDLibFFI.mockUpdate(): failed to encode update")
        }
        pendingResponses.append(json)
    }

    @discardableResult
    public func send(_ request: String) -> String {
        lock.lock()
        defer { lock.unlock() }

        guard let data = request.data(using: .utf8),
              let parsed = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let requestType = parsed["@type"] as? String else {
            fatalError("MockTDLibFFI.send(): invalid JSON or missing @type")
        }

        // Генерируем уникальный @extra (как реальный TDLib FFI)
        extraCounter &+= 1
        let generatedExtra = "mock_\(extraCounter)"

        // Специальная логика для loadChats (имитация Real TDLib API)
        if requestType == "loadChats" {
            handleLoadChats(parsed: parsed, extra: generatedExtra)
            return generatedExtra
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

        // Кодируем response с @extra (используем toTDLibJSON helper)
        let jsonString: String
        do {
            switch result {
            case .success(let response):
                jsonString = try response.toTDLibJSON(withExtra: generatedExtra)
            case .failure(let error):
                jsonString = try error.toTDLibJSON(withExtra: generatedExtra)
            }
        } catch {
            fatalError("MockTDLibFFI.send(): failed to encode response: \(error)")
        }

        pendingResponses.append(jsonString)
        return generatedExtra
    }

    private func handleLoadChats(parsed: [String: Any], extra: String?) {
        // Парсим limit из запроса
        let limit = (parsed["limit"] as? Int) ?? 100

        // Эмитим updates (до limit штук) — updates НЕ получают @extra
        let remaining = queuedUpdates.count - updatesProcessed
        let toEmit = min(limit, remaining)

        for i in 0..<toEmit {
            let update = queuedUpdates[updatesProcessed + i]
            do {
                // Updates не получают @extra (они асинхронные, не response)
                let json = try update.toTDLibJSON()
                pendingResponses.append(json)
            } catch {
                fatalError("MockTDLibFFI.handleLoadChats(): failed to encode update: \(error)")
            }
        }
        updatesProcessed += toEmit

        // Ok или 404 — получают @extra из request
        do {
            if updatesProcessed >= queuedUpdates.count {
                // Все updates загружены → 404
                let error = TDLibErrorResponse(code: 404, message: "Not Found: chat list is empty")
                let json = try error.toTDLibJSON(withExtra: extra)
                pendingResponses.append(json)
            } else {
                // Есть ещё updates → Ok
                let ok = OkResponse()
                let json = try ok.toTDLibJSON(withExtra: extra)
                pendingResponses.append(json)
            }
        } catch {
            fatalError("MockTDLibFFI.handleLoadChats(): failed to encode response: \(error)")
        }
    }

    public func receive(timeout: Double) -> String? {
        lock.lock()

        // Проверка thread safety: receive() ДОЛЖЕН вызываться только из одного потока (serial DispatchQueue)
        let currentThread = pthread_self()
        if let expected = expectedThread {
            precondition(
                pthread_equal(currentThread, expected) != 0,
                "MockTDLibFFI.receive() вызван из другого потока! Ожидался: \(expected), получен: \(currentThread)"
            )
        } else {
            // Первый вызов: запоминаем поток
            expectedThread = currentThread
        }

        // Если очередь пуста - освобождаем lock и ждём
        // Имитация блокирующего td_json_client_receive(): ждём 1ms (даём шанс send() взять lock)
        if pendingResponses.isEmpty {
            lock.unlock()
            Thread.sleep(forTimeInterval: min(timeout, 0.001))
            return nil
        }

        let response = pendingResponses.removeFirst()
        lock.unlock()
        return response
    }
}
