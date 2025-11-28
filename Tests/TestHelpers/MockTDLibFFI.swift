import TgClientModels
import TGClientInterfaces
import Foundation
@testable import TDLibAdapter

/// Mock реализация TDLibFFI для Unit-тестов и Component-тестов.
///
/// Имитирует поведение реального TDLib FFI слоя (CTDLibFFI):
/// - `send()` генерирует уникальный @extra и сохраняет response в `responsesByExtra`
/// - `receive()` возвращает responses по @extra (НЕ FIFO!) или updates (FIFO)
///
/// ## @extra Matching (Request-Response)
///
/// Для точного матчинга параллельных запросов:
/// - `send()` генерирует уникальный @extra (mock_1, mock_2...)
/// - Response сохраняется в Dictionary `responsesByExtra[@extra]`
/// - `receive()` возвращает любой response из Dictionary (порядок НЕ важен)
/// - TDLibClient матчит response по @extra через ResponseWaiters
///
/// ## Updates (Asynchronous)
///
/// Updates приходят БЕЗ @extra и обрабатываются FIFO:
/// - `mockUpdate()` добавляет update в `pendingUpdates` (FIFO очередь)
/// - `loadChats` эмитит updates по одному в `pendingUpdates`
/// - `receive()` возвращает updates из FIFO если нет responses
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
public final class MockTDLibFFI: TDLibFFI, @unchecked Sendable {

    /// Lock для защиты shared mutable state (mockedResponses, responsesByExtra, pendingUpdates, queuedUpdates).
    private let lock = NSLock()

    /// Замоканные ответы для каждого типа запроса (FIFO очередь).
    /// Используется для auth flow (forType matching).
    private var mockedResponses: [String: [Result<any TDLibResponse, TDLibErrorResponse>]] = [:]

    /// Очередь updates для эмиссии через loadChats.
    private var queuedUpdates: [Update] = []

    /// Счётчик уже обработанных updates.
    private var updatesProcessed = 0

    /// Responses с @extra для точного матчинга параллельных запросов.
    /// - Key: @extra (например "mock_123")
    /// - Value: JSON response с этим @extra
    private var responsesByExtra: [String: String] = [:]

    /// Pending updates БЕЗ @extra (FIFO очередь).
    /// Updates приходят асинхронно и НЕ привязаны к конкретному запросу.
    private var pendingUpdates: [String] = []

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

    /// Эмитит update напрямую в pendingUpdates (БЕЗ loadChats).
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
        pendingUpdates.append(json)
    }

    /// Эмитит unsolicited response (например updateAuthorizationState) напрямую в pendingUpdates.
    ///
    /// **Использование в auth тестах:**
    /// Auth flow использует unsolicited updates типа `updateAuthorizationState` которые НЕ имеют @extra.
    /// TDLibClient.waitForAuthorizationUpdate() ждёт такие updates через ResponseWaiters.addWaiter(forType:).
    ///
    /// ```swift
    /// mockFFI.mockUpdate(AuthorizationStateUpdateResponse.waitCode)
    /// // Сразу доступно через receive(), TDLibClient матчит по @type
    /// ```
    public func mockUpdate<R: TDLibResponse>(_ response: R) {
        lock.lock()
        defer { lock.unlock() }

        let encoder = JSONEncoder.tdlib()
        guard let data = try? encoder.encode(response),
              let json = String(data: data, encoding: .utf8) else {
            fatalError("MockTDLibFFI.mockUpdate(): failed to encode response")
        }
        pendingUpdates.append(json)
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

        // Специальная логика для getChat (параметры request → response)
        if requestType == "getChat" {
            handleGetChat(parsed: parsed, extra: generatedExtra)
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

        // Сохраняем response по @extra для точного матчинга
        responsesByExtra[generatedExtra] = jsonString
        return generatedExtra
    }

    private func handleLoadChats(parsed: [String: Any], extra: String) {

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
                pendingUpdates.append(json)
            } catch {
                fatalError("MockTDLibFFI.handleLoadChats(): failed to encode update: \(error)")
            }
        }
        updatesProcessed += toEmit

        // Ok или 404 — получают @extra из request и сохраняются в responsesByExtra
        do {
            if updatesProcessed >= queuedUpdates.count {
                // Все updates загружены → 404
                let error = TDLibErrorResponse(code: 404, message: "Not Found: chat list is empty")
                let json = try error.toTDLibJSON(withExtra: extra)
                responsesByExtra[extra] = json
            } else {
                // Есть ещё updates → Ok
                let ok = OkResponse()
                let json = try ok.toTDLibJSON(withExtra: extra)
                responsesByExtra[extra] = json
            }
        } catch {
            fatalError("MockTDLibFFI.handleLoadChats(): failed to encode response: \(error)")
        }
    }

    /// Специальная логика для getChat: копирует chat_id из request в response.
    ///
    /// **Имитация Real TDLib API:**
    /// - Реальный TDLib берёт chat_id из request и возвращает данные для ЭТОГО chat
    /// - Мы берём ЛЮБОЙ мокнутый ChatResponse из очереди и заменяем id на chat_id из request
    ///
    /// **Использование в тестах:**
    /// ```swift
    /// // Тест мокает "шаблонные" responses (id не важен, будет перезаписан)
    /// mockFFI.mockResponse(forRequestType: "getChat", return: ChatResponse(id: 0, ...))
    /// mockFFI.mockResponse(forRequestType: "getChat", return: ChatResponse(id: 0, ...))
    ///
    /// // Параллельные запросы получат response с СВОИМ chat_id
    /// client.getChat(chatId: 1000) → ChatResponse(id: 1000)
    /// client.getChat(chatId: 2000) → ChatResponse(id: 2000)
    /// ```
    private func handleGetChat(parsed: [String: Any], extra: String) {
        // Парсим chat_id из request
        guard let chatId = parsed["chat_id"] as? Int64 else {
            fatalError("MockTDLibFFI.handleGetChat(): request missing chat_id")
        }

        // Берём ЛЮБОЙ мокнутый ChatResponse из FIFO очереди
        guard var queue = mockedResponses["getChat"], !queue.isEmpty else {
            fatalError("MockTDLibFFI.handleGetChat(): no mocked response for getChat")
        }

        let result = queue.removeFirst()
        if queue.isEmpty {
            mockedResponses.removeValue(forKey: "getChat")
        } else {
            mockedResponses["getChat"] = queue
        }

        // Модифицируем response: заменяем id на chat_id из request
        do {
            switch result {
            case .success(let response):
                guard let chatResponse = response as? ChatResponse else {
                    fatalError("MockTDLibFFI.handleGetChat(): mocked response is not ChatResponse")
                }

                // Создаём новый ChatResponse с chat_id из request
                let modifiedResponse = ChatResponse(
                    id: chatId,  // ← ИЗ REQUEST!
                    type: chatResponse.chatType,
                    title: chatResponse.title,
                    unreadCount: chatResponse.unreadCount,
                    lastReadInboxMessageId: chatResponse.lastReadInboxMessageId
                )

                let json = try modifiedResponse.toTDLibJSON(withExtra: extra)
                responsesByExtra[extra] = json

            case .failure(let error):
                // Ошибки не модифицируем (они не зависят от chat_id)
                let json = try error.toTDLibJSON(withExtra: extra)
                responsesByExtra[extra] = json
            }
        } catch {
            fatalError("MockTDLibFFI.handleGetChat(): failed to encode response: \(error)")
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

        // Приоритет 1: Responses с @extra (любой, порядок не важен)
        if let (extra, json) = responsesByExtra.first {
            responsesByExtra.removeValue(forKey: extra)
            lock.unlock()

            // КРИТИЧНО: Имитация асинхронности real TDLib
            // Real TDLib возвращает responses из C++ background thread с задержкой.
            // MockTDLibFFI добавляет responses СИНХРОННО в send() → race condition:
            // Background loop может прочитать response ДО регистрации waiter в TDLibClient.execute()
            // Задержка даёт время на await responseWaiters.addWaiter() в execute()
            Thread.sleep(forTimeInterval: 0.001)

            return json
        }

        // Приоритет 2: Updates БЕЗ @extra (FIFO)
        if !pendingUpdates.isEmpty {
            let json = pendingUpdates.removeFirst()
            lock.unlock()
            return json
        }

        // Нет данных - освобождаем lock и ждём
        // Имитация блокирующего td_json_client_receive(): ждём 1ms (даём шанс send() взять lock)
        lock.unlock()
        Thread.sleep(forTimeInterval: min(timeout, 0.001))
        return nil
    }
}
