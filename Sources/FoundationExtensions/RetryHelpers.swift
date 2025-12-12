import Foundation
import Logging

// MARK: - Retry Strategy

/// Retry async операции с exponential backoff
///
/// **Использование:**
/// ```swift
/// try await withRetry(
///     operation: { try await someAsyncOperation() },
///     shouldRetry: { error, _ in error is TimeoutError },
///     logger: logger
/// )
/// ```
///
/// **Exponential backoff:** 1s → 2s → 4s (default maxAttempts = 3, baseDelay = 1s)
public func withRetry<T: Sendable>(
    maxAttempts: Int = 3,
    baseDelay: Duration = .seconds(1),  // Базовая задержка для exponential backoff
    timeout: Duration? = nil,  // Опциональный timeout для каждой попытки
    operation: @escaping @Sendable () async throws -> T,
    shouldRetry: @escaping @Sendable (Error, Int) -> Bool,
    logger: Logger
) async throws -> T {
    var lastError: Error?

    for attempt in 0..<maxAttempts {
        do {
            // Применяем timeout если указан
            if let timeout = timeout {
                return try await withTimeout(timeout, operation: operation)
            } else {
                return try await operation()
            }
        } catch {
            lastError = error
            let isLast = (attempt == maxAttempts - 1)

            if !isLast && shouldRetry(error, attempt) {
                // Exponential backoff: baseDelay * 2^attempt
                let multiplier = Int64(pow(2.0, Double(attempt)))
                let delay = baseDelay * multiplier
                logger.warning("Retrying after \(delay)", metadata: [
                    "attempt": "\(attempt + 1)/\(maxAttempts)",
                    "error": "\(error)"
                ])
                try await Task.sleep(for: delay)
            } else {
                throw error
            }
        }
    }

    // ⚠️ КРИТИЧНО: Этот код НЕ ДОЛЖЕН выполниться (логика выше всегда return/throw)
    // Если выполнится → серьёзный баг в retry логике
    logger.critical("FATAL: withRetry loop completed without return/throw", metadata: [
        "maxAttempts": "\(maxAttempts)",
        "lastError": "\(String(describing: lastError))",
        "errorType": "\(type(of: lastError))",
        "timeout": "\(String(describing: timeout))"
    ])

    fatalError("Unreachable: retry loop completed without return/throw. Last error: \(String(describing: lastError))")
}

// MARK: - Timeout

/// Timeout ошибка для операций которые превысили лимит времени
public enum TimeoutError: Error, LocalizedError {
    case timedOut

    public var errorDescription: String? {
        "Operation timed out"
    }
}

/// Timeout wrapper для async операций
///
/// **Использование:**
/// ```swift
/// try await withTimeout(.seconds(30)) {
///     try await longRunningOperation()
/// }
/// ```
///
/// **Поведение:**
/// - Запускает операцию параллельно с timeout таймером
/// - Первая завершившаяся Task выигрывает (операция или timeout)
/// - Отменяет оставшуюся Task после завершения
public func withTimeout<T: Sendable>(
    _ timeout: Duration,
    operation: @escaping @Sendable () async throws -> T
) async throws -> T {
    try await withThrowingTaskGroup(of: T.self) { group in
        // Task 1: реальная операция
        group.addTask { try await operation() }

        // Task 2: timeout таймер
        group.addTask {
            try await Task.sleep(for: timeout)
            throw TimeoutError.timedOut
        }

        // Первая завершившаяся Task выигрывает
        let result = try await group.next()!
        group.cancelAll()  // Отменяем оставшуюся Task
        return result
    }
}
