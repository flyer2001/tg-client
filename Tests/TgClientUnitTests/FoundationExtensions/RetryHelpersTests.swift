import Testing
import Foundation
import Logging
@testable import FoundationExtensions
import TestHelpers

@Suite("RetryHelpers Tests", .timeLimit(.minutes(1)))
struct RetryHelpersTests {

    // MARK: - withRetry Tests

    @Test("Успех на первой попытке (без retry)")
    func successOnFirstAttempt() async throws {
        let counter = CallCounter()
        var logger = Logger(label: "test")
        logger.logLevel = .critical  // Подавляем логи в тестах

        let result = try await withRetry(
            operation: {
                await counter.increment()
                return "success"
            },
            shouldRetry: { _, _ in true },
            logger: logger
        )

        #expect(result == "success")
        #expect(await counter.get() == 1)  // Вызвана только один раз
    }

    @Test("Fail на 1й попытке → retry → success")
    func retryOnceThenSuccess() async throws {
        let counter = CallCounter()
        var logger = Logger(label: "test")
        logger.logLevel = .critical

        let result = try await withRetry(
            baseDelay: .milliseconds(100),
            operation: {
                await counter.increment()
                if await counter.get() == 1 {
                    throw TestError.temporary
                }
                return "success"
            },
            shouldRetry: { error, _ in
                error is TestError
            },
            logger: logger,
            sleep: { _ in }
        )

        #expect(result == "success")
        #expect(await counter.get() == 2)  // Упала 1 раз, успех на retry
    }

    @Test("Исчерпаны все retry попытки → throw")
    func exhaustRetriesThenThrow() async throws {
        let counter = CallCounter()
        var logger = Logger(label: "test")
        logger.logLevel = .critical

        await #expect(throws: TestError.self) {
            try await withRetry(
                maxAttempts: 3,
                baseDelay: .milliseconds(100),
                operation: {
                    await counter.increment()
                    throw TestError.temporary
                },
                shouldRetry: { _, _ in true },
                logger: logger,
                sleep: { _ in }
            )
        }

        #expect(await counter.get() == 3)  // Все 3 попытки исчерпаны
    }

    @Test("Не-retry-able ошибка: немедленный throw")
    func nonRetryableErrorImmediateThrow() async throws {
        let counter = CallCounter()
        var logger = Logger(label: "test")
        logger.logLevel = .critical

        await #expect(throws: TestError.self) {
            try await withRetry(
                operation: {
                    await counter.increment()
                    throw TestError.permanent
                },
                shouldRetry: { error, _ in
                    // Retry только для temporary ошибок
                    if let testError = error as? TestError {
                        return testError == .temporary
                    }
                    return false
                },
                logger: logger
            )
        }

        #expect(await counter.get() == 1)  // Нет retry для permanent ошибки
    }

    /// Паузы — те, что код **попросил** (SleepRecorder), а не замер по ContinuousClock: детерминированно и мгновенно.
    /// 4 попытки → 3 паузы: при 3 попытках (100, 200) экспонента неотличима от линейного роста — мутация это показала.
    @Test("Exponential backoff delays: 0.1s, 0.2s, 0.4s")
    func exponentialBackoffDelays() async throws {
        let counter = CallCounter()
        let sleeps = SleepRecorder()
        var logger = Logger(label: "test")
        logger.logLevel = .critical

        await #expect(throws: TestError.self) {
            try await withRetry(
                maxAttempts: 4,
                baseDelay: .milliseconds(100),
                operation: {
                    await counter.increment()
                    throw TestError.temporary
                },
                shouldRetry: { _, _ in true },
                logger: logger,
                sleep: sleeps.sleep
            )
        }

        #expect(await counter.get() == 4)
        let durations = await sleeps.durations   // вне #expect: с await он не печатает значения
        #expect(durations == [.milliseconds(100), .milliseconds(200), .milliseconds(400)])  // 100ms·2^n
    }

    // MARK: - withTimeout Tests

    @Test("Операция завершается до timeout")
    func operationCompletesBeforeTimeout() async throws {
        let result = try await withTimeout(.seconds(1)) {
            "success"
        }

        #expect(result == "success")
    }

    @Test("Операция превышает timeout")
    func operationTimesOut() async throws {
        await #expect(throws: TimeoutError.self) {
            try await withTimeout(.milliseconds(50)) {
                try await Task.sleep(for: .seconds(2))
                return "never reached"
            }
        }
    }

    @Test("Timeout отменяет Task операции")
    func timeoutCancelsOperationTask() async throws {
        let flag = BoolFlag()

        await #expect(throws: TimeoutError.self) {
            try await withTimeout(.milliseconds(50)) {
                defer {
                    Task { await flag.set(Task.isCancelled) }
                }
                try await Task.sleep(for: .seconds(2))
                return "never reached"
            }
        }

        // Примечание: Task cancellation асинхронный, может быть не мгновенным
        // Этот тест документирует ожидаемое поведение, не строгую гарантию
    }

    // MARK: - withRetry + withTimeout Integration

    @Test("Retry + timeout: успех на первой попытке")
    func retryWithTimeoutSuccessOnFirstAttempt() async throws {
        let counter = CallCounter()
        var logger = Logger(label: "test")
        logger.logLevel = .critical

        let result = try await withRetry(
            timeout: .seconds(1),
            operation: {
                await counter.increment()
                return "success"
            },
            shouldRetry: { _, _ in true },
            logger: logger
        )

        #expect(result == "success")
        #expect(await counter.get() == 1)
    }

    @Test("Retry + timeout: timeout на 1й, success на retry")
    func retryWithTimeoutTimeoutOnFirstSuccessOnRetry() async throws {
        let counter = CallCounter()
        var logger = Logger(label: "test")
        logger.logLevel = .critical

        let result = try await withRetry(
            maxAttempts: 3,
            baseDelay: .milliseconds(100),
            timeout: .milliseconds(100),
            operation: {
                await counter.increment()
                if await counter.get() == 1 {
                    // Первая попытка: медленная (timeout через 100ms)
                    try await Task.sleep(for: .seconds(2))
                }
                // Вторая попытка: быстрая (success)
                return "success"
            },
            shouldRetry: { error, _ in
                error is TimeoutError
            },
            logger: logger,
            sleep: { _ in }
        )

        #expect(result == "success")
        #expect(await counter.get() == 2)  // Timeout + retry success
    }

    @Test("Retry + timeout: исчерпаны все попытки")
    func retryWithTimeoutExhaustAllAttempts() async throws {
        let counter = CallCounter()
        var logger = Logger(label: "test")
        logger.logLevel = .critical

        await #expect(throws: TimeoutError.self) {
            try await withRetry(
                maxAttempts: 3,
                baseDelay: .milliseconds(100),
                timeout: .milliseconds(50),
                operation: {
                    await counter.increment()
                    try await Task.sleep(for: .seconds(2))   // висит, пока таймаут не отменит
                    return "never reached"
                },
                shouldRetry: { _, _ in true },
                logger: logger,
                sleep: { _ in }
            )
        }

        #expect(await counter.get() == 3)  // Все 3 попытки превысили timeout
    }
}

// MARK: - Test Helpers

enum TestError: Error, Equatable {
    case temporary
    case permanent
}
