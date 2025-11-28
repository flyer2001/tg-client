import TgClientModels
import Foundation

/// Механизм управления continuations для async запросов к TDLib.
///
/// **Назначение:**
/// - Обеспечивает thread-safe хранение и обработку CheckedContinuation для async/await запросов
/// - Точный матчинг запрос-ответ по уникальному `@extra` ключу
///
/// **Принцип работы (@extra matching):**
/// 1. TDLibClient генерирует уникальный `@extra` для каждого запроса
/// 2. Async метод регистрирует continuation через `addWaiter(forExtra:continuation:)`
/// 3. TDLib копирует `@extra` из request в response
/// 4. Background loop получает ответ → вызывает `resumeWaiter(forExtra:with:)`
/// 5. Continuation матчится точно по `@extra` (не FIFO!)
///
/// **Concurrency:**
/// - Реализован как Swift `actor` для thread-safe доступа к continuations
/// - Все операции с `waiters` dictionary автоматически serialized
///
/// **Используется в:**
/// - `TDLibClient` (Real) - обработка ответов от TDLib C library
///
/// **Unit тесты:** `Tests/TgClientUnitTests/TDLibAdapter/ResponseWaitersTests.swift`
public actor ResponseWaiters {

    /// Результат попытки resume continuation.
    public enum ResumeResult: Sendable {
        /// Continuation успешно resumed
        case resumed
        /// Нет ожидающего waiter для данного @extra
        case noWaiter

        /// Convenience property для проверки успеха.
        public var wasResumed: Bool { self == .resumed }
    }

    /// Словарь ожидающих continuations.
    ///
    /// **Ключ:** уникальный `@extra` ID запроса
    /// **Значение:** continuation для этого запроса
    private var waiters: [String: CheckedContinuation<TDLibJSON, Error>] = [:]

    public init() {}

    /// Регистрирует continuation для ожидания ответа по @extra.
    ///
    /// - Parameters:
    ///   - extra: Уникальный @extra ID запроса (генерируется TDLibClient)
    ///   - continuation: Continuation для resume с результатом
    public func addWaiter(forExtra extra: String, continuation: CheckedContinuation<TDLibJSON, Error>) {
        waiters[extra] = continuation
    }

    /// Регистрирует continuation для ожидания unsolicited update по @type.
    ///
    /// **Use case:** Authorization flow ждёт `updateAuthorizationState` без @extra
    /// (TDLib отправляет их сам, не в ответ на request).
    ///
    /// - Parameters:
    ///   - type: Тип update (@type field, например "updateAuthorizationState")
    ///   - continuation: Continuation для resume с результатом
    public func addWaiter(forType type: String, continuation: CheckedContinuation<TDLibJSON, Error>) {
        waiters[type] = continuation
    }

    /// Resume waiter по @extra с успешным ответом.
    ///
    /// - Parameters:
    ///   - extra: @extra ID из response
    ///   - response: TDLib response как `TDLibJSON` (Sendable-safe wrapper)
    /// - Returns: `.resumed` если waiter был найден, `.noWaiter` если нет
    public func resumeWaiter(forExtra extra: String, with response: TDLibJSON) -> ResumeResult {
        guard let continuation = waiters.removeValue(forKey: extra) else {
            return .noWaiter
        }
        continuation.resume(returning: response)
        return .resumed
    }

    /// Resume waiter по @extra с ошибкой.
    ///
    /// - Parameters:
    ///   - extra: @extra ID из response
    ///   - error: Ошибка для передачи в continuation
    /// - Returns: `.resumed` если waiter был найден, `.noWaiter` если нет
    public func resumeWaiter(forExtra extra: String, with error: Error) -> ResumeResult {
        guard let continuation = waiters.removeValue(forKey: extra) else {
            return .noWaiter
        }
        continuation.resume(throwing: error)
        return .resumed
    }

    /// Resume waiter по @type с успешным update.
    ///
    /// **Use case:** Authorization flow получает `updateAuthorizationState` от TDLib.
    ///
    /// - Parameters:
    ///   - type: Тип update (@type field)
    ///   - update: TDLib update как `TDLibJSON`
    /// - Returns: `.resumed` если waiter был найден, `.noWaiter` если нет
    public func resumeWaiter(forType type: String, with update: TDLibJSON) -> ResumeResult {
        guard let continuation = waiters.removeValue(forKey: type) else {
            return .noWaiter
        }
        continuation.resume(returning: update)
        return .resumed
    }

    /// Resume waiter по @type с ошибкой.
    ///
    /// - Parameters:
    ///   - type: Тип update (@type field)
    ///   - error: Ошибка для передачи в continuation
    /// - Returns: `.resumed` если waiter был найден, `.noWaiter` если нет
    public func resumeWaiter(forType type: String, with error: Error) -> ResumeResult {
        guard let continuation = waiters.removeValue(forKey: type) else {
            return .noWaiter
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

        for (_, continuation) in allWaiters {
            continuation.resume(throwing: CancellationError())
        }
    }
}
