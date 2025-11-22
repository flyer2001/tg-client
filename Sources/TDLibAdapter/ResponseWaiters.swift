import Foundation

/// Механизм управления continuations для async запросов к TDLib.
///
/// **Назначение:**
/// - Обеспечивает thread-safe хранение и обработку CheckedContinuation для async/await запросов
/// - Используется как в реальном TDLibClient, так и в MockTDLibClient (для точной имитации поведения)
///
/// **Принцип работы:**
/// 1. Async метод создаёт continuation и регистрирует его через `addWaiter(for:continuation:)`
/// 2. Background loop получает ответ от TDLib → вызывает `resumeWaiter(for:with:)`
/// 3. Первый continuation из очереди получает ответ (FIFO для простых кейсов)
///
/// **Concurrency:**
/// - Реализован как Swift `actor` для thread-safe доступа к continuations
/// - Все операции с `waiters` dictionary автоматически serialized
///
/// **⚠️ Ограничение текущей реализации:**
/// Ключ - только `requestType` (например "getChatHistory"), без учёта параметров.
/// Для параллельных запросов с разными параметрами нужен RequestKey (chatId, messageId, etc.).
///
/// **Используется в:**
/// - `TDLibClient` (Real) - обработка ответов от TDLib C library
/// - `MockTDLibClient` (Test) - имитация поведения Real клиента для component тестов
///
/// **Unit тесты:** `Tests/TgClientUnitTests/TDLibAdapter/ResponseWaitersTests.swift`
public actor ResponseWaiters {

    /// Результат попытки resume continuation.
    public enum ResumeResult: Sendable {
        /// Continuation успешно resumed
        case resumed
        /// Нет ожидающих waiters для данного типа запроса
        case noWaiter

        /// Convenience property для проверки успеха.
        public var wasResumed: Bool { self == .resumed }
    }

    /// Словарь ожидающих continuations.
    ///
    /// **Ключ:** `requestType` (например "getChat", "getChatHistory")
    /// **Значение:** FIFO очередь continuations для запросов этого типа
    ///
    /// **⚠️ Ограничение:** не учитывает параметры запросов (chatId, messageId, etc.)
    /// Для параллельных запросов нужен RequestKey.
    private var waiters: [String: [CheckedContinuation<TDLibJSON, Error>]] = [:]

    public init() {}

    /// Регистрирует continuation для ожидания ответа.
    ///
    /// - Parameters:
    ///   - type: Тип TDLib запроса (например "getChat", "getChatHistory")
    ///   - continuation: Continuation для resume с результатом
    public func addWaiter(for type: String, continuation: CheckedContinuation<TDLibJSON, Error>) {
        waiters[type, default: []].append(continuation)
    }

    /// Resume первого waiter из очереди с успешным ответом.
    ///
    /// - Parameters:
    ///   - type: Тип TDLib запроса
    ///   - response: TDLib response как `TDLibJSON` (Sendable-safe wrapper)
    /// - Returns: `.resumed` если waiter был найден, `.noWaiter` если очередь пуста
    public func resumeWaiter(for type: String, with response: TDLibJSON) -> ResumeResult {
        guard var queue = waiters[type], !queue.isEmpty else {
            return .noWaiter
        }
        let continuation = queue.removeFirst()
        if queue.isEmpty {
            waiters.removeValue(forKey: type)
        } else {
            waiters[type] = queue
        }

        continuation.resume(returning: response)
        return .resumed
    }

    /// Resume первого waiter из очереди с ошибкой.
    ///
    /// - Parameters:
    ///   - type: Тип TDLib запроса
    ///   - error: Ошибка для передачи в continuation
    /// - Returns: `.resumed` если waiter был найден, `.noWaiter` если очередь пуста
    public func resumeWaiter(for type: String, with error: Error) -> ResumeResult {
        guard var queue = waiters[type], !queue.isEmpty else {
            return .noWaiter
        }
        let continuation = queue.removeFirst()
        if queue.isEmpty {
            waiters.removeValue(forKey: type)
        } else {
            waiters[type] = queue
        }

        continuation.resume(throwing: error)
        return .resumed
    }

    /// Отменяет все ожидающие continuations (CancellationError).
    ///
    /// **Использование:** При shutdown TDLibClient или cleanup в тестах.
    public func cancelAll() {
        let allWaiters = waiters
        waiters.removeAll()

        for (_, queue) in allWaiters {
            for continuation in queue {
                continuation.resume(throwing: CancellationError())
            }
        }
    }
}
