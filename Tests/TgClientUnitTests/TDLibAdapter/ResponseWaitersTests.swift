import Foundation
import Testing
@preconcurrency @testable import TDLibAdapter

// MARK: - Test Helpers

extension ResponseWaiters {
    /// Для тестов: регистрирует waiter и вызывает callback когда готово.
    ///
    /// Гарантирует что continuation зарегистрирован до возврата из callback.
    nonisolated func addWaiterWithCallback(
        for type: String,
        continuation: CheckedContinuation<TDLibJSON, Error>,
        onRegistered: @escaping @Sendable () -> Void
    ) {
        Task {
            await self.addWaiter(for: type, continuation: continuation)
            onRegistered()  // ✅ Сигнал: continuation зарегистрирован
        }
    }
}

/// Unit-тесты для ResponseWaiters - механизм управления continuations для async запросов.
///
/// **Назначение:**
/// ResponseWaiters управляет очередью ожидающих continuations для каждого типа запроса,
/// обеспечивая thread-safe FIFO обработку ответов.
///
/// **Используется в:**
/// - TDLibClient (Real) - для обработки ответов от TDLib
/// - MockTDLibClient (Test) - для имитации поведения Real клиента
@Suite("Unit: ResponseWaiters - continuation management")
struct ResponseWaitersTests {

    /// Добавление waiter и успешное resume с response.
    ///
    /// **Given:** ResponseWaiters без waiters
    /// **When:** Добавляем waiter → resume с success
    /// **Then:** Continuation получает response
    @Test("addWaiter + resumeWithSuccess → continuation получает response")
    func addWaiterAndResumeWithSuccess() async throws {
        let waiters = ResponseWaiters()
        let expectedResponse = try TDLibJSON(parsing: ["result": "success", "value": 42])

        // AsyncStream для синхронизации
        let (stream, streamContinuation) = AsyncStream.makeStream(of: Void.self)

        // Создаём task с continuation (проверки внутри, возвращаем Bool)
        let task = Task<Bool, Error> {
            let result = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<TDLibJSON, Error>) in
                waiters.addWaiterWithCallback(for: "testRequest", continuation: continuation) {
                    streamContinuation.yield(())  // ✅ Сигнал: зарегистрирован
                }
            }
            // Проверяем результат внутри task
            return result["result"] as? String == "success" && result["value"] as? Int == 42
        }

        // Ждём подтверждения регистрации
        _ = await stream.first(where: { _ in true })

        // Resume с response
        let resumeResult = await waiters.resumeWaiter(for: "testRequest", with: expectedResponse)
        #expect(resumeResult.wasResumed)

        // Получаем результат
        let success = try await task.value

        // Then: Проверяем успех
        #expect(success)
    }

    /// Добавление waiter и resume с error.
    ///
    /// **Given:** ResponseWaiters без waiters
    /// **When:** Добавляем waiter → resume с error
    /// **Then:** Continuation бросает ошибку
    @Test("addWaiter + resumeWithError → continuation бросает ошибку")
    func addWaiterAndResumeWithError() async throws {
        let waiters = ResponseWaiters()
        let expectedError = NSError(domain: "test", code: 404, userInfo: [NSLocalizedDescriptionKey: "Not found"])

        // AsyncStream для синхронизации
        let (stream, streamContinuation) = AsyncStream.makeStream(of: Void.self)

        // Создаём task с continuation (проверки внутри, возвращаем Bool)
        let task = Task<Bool, Error> {
            do {
                _ = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<TDLibJSON, Error>) in
                    waiters.addWaiterWithCallback(for: "testRequest", continuation: continuation) {
                        streamContinuation.yield(())  // ✅ Сигнал: зарегистрирован
                    }
                }
                return false  // Не должны попасть сюда
            } catch {
                // Проверяем ошибку внутри task
                let nsError = error as NSError
                return nsError.domain == "test" && nsError.code == 404
            }
        }

        // Ждём подтверждения регистрации
        _ = await stream.first(where: { _ in true })

        // Resume с error
        let resumeResult = await waiters.resumeWaiter(for: "testRequest", with: expectedError)
        #expect(resumeResult.wasResumed)

        // Получаем результат
        let errorMatched = try await task.value

        // Then: Проверяем что ошибка совпала
        #expect(errorMatched)
    }

    /// Resume без waiters → возвращает .noWaiter.
    ///
    /// **Given:** ResponseWaiters без waiters
    /// **When:** Вызываем resumeWaiter
    /// **Then:** Возвращает .noWaiter (не крашится)
    @Test("resumeWaiter без waiters → .noWaiter")
    func resumeWaiterWithoutWaiters() async throws {
        let waiters = ResponseWaiters()
        let testResponse = try TDLibJSON(parsing: ["test": "value"])

        // When: Resume без добавления waiter
        let result = await waiters.resumeWaiter(for: "nonExistent", with: testResponse)

        // Then: Возвращает .noWaiter
        #expect(!result.wasResumed)
        #expect(result == .noWaiter)
    }

    /// cancelAll() → все continuations получают CancellationError.
    ///
    /// **Given:** 3 waiters разных типов
    /// **When:** Вызываем cancelAll()
    /// **Then:** Все continuations бросают CancellationError
    @Test("cancelAll → все continuations получают CancellationError")
    func cancelAllWaiters() async throws {
        let waiters = ResponseWaiters()

        // AsyncStream для синхронизации 3 регистраций
        let (stream, streamContinuation) = AsyncStream.makeStream(of: Void.self)

        // Создаём 3 task с continuations разных типов (возвращаем Bool)
        let task1 = Task<Bool, Error> {
            do {
                _ = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<TDLibJSON, Error>) in
                    waiters.addWaiterWithCallback(for: "getChat", continuation: continuation) {
                        streamContinuation.yield(())
                    }
                }
                return false
            } catch is CancellationError {
                return true
            }
        }
        let task2 = Task<Bool, Error> {
            do {
                _ = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<TDLibJSON, Error>) in
                    waiters.addWaiterWithCallback(for: "getMe", continuation: continuation) {
                        streamContinuation.yield(())
                    }
                }
                return false
            } catch is CancellationError {
                return true
            }
        }
        let task3 = Task<Bool, Error> {
            do {
                _ = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<TDLibJSON, Error>) in
                    waiters.addWaiterWithCallback(for: "getChatHistory", continuation: continuation) {
                        streamContinuation.yield(())
                    }
                }
                return false
            } catch is CancellationError {
                return true
            }
        }

        // Ждём регистрации всех 3 waiters
        for _ in 0..<3 {
            _ = await stream.first(where: { _ in true })
        }

        // When: Отменяем все waiters
        await waiters.cancelAll()

        // Then: Все 3 continuations бросили CancellationError
        let cancelled1 = try await task1.value
        let cancelled2 = try await task2.value
        let cancelled3 = try await task3.value

        #expect(cancelled1)
        #expect(cancelled2)
        #expect(cancelled3)
    }

    /// Thread-safety: параллельные addWaiter + resumeWaiter.
    ///
    /// **Given:** ResponseWaiters
    /// **When:** 10 параллельных задач добавляют waiters + 10 задач resume
    /// **Then:** Все операции выполняются thread-safe, continuations получают ответы
    @Test("Thread-safety: параллельные операции")
    func threadSafetyParallelOperations() async throws {
        let waiters = ResponseWaiters()
        let iterations = 10

        // AsyncStream для синхронизации 10 регистраций
        let (stream, streamContinuation) = AsyncStream.makeStream(of: Void.self)

        // Создаём 10 параллельных tasks
        var tasks: [Task<Int, Error>] = []
        for _ in 0..<iterations {
            let task = Task {
                let result = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<TDLibJSON, Error>) in
                    waiters.addWaiterWithCallback(for: "parallelTest", continuation: continuation) {
                        streamContinuation.yield(())
                    }
                }
                guard let index = result["index"] as? Int else {
                    throw NSError(domain: "test", code: -1, userInfo: [NSLocalizedDescriptionKey: "Missing index"])
                }
                return index
            }
            tasks.append(task)
        }

        // Ждём регистрации всех 10 waiters
        for _ in 0..<iterations {
            _ = await stream.first(where: { _ in true })
        }

        // Resume все waiters
        for i in 0..<iterations {
            let response = try TDLibJSON(parsing: ["index": i])
            let resumeResult = await waiters.resumeWaiter(for: "parallelTest", with: response)
            #expect(resumeResult.wasResumed)
        }

        // Собираем результаты
        var receivedIndices: [Int] = []
        for task in tasks {
            let index = try await task.value
            receivedIndices.append(index)
        }

        // Then: Все 10 continuations получили ответы
        #expect(receivedIndices.count == iterations)

        // Проверяем что все индексы от 0 до 9 присутствуют
        let sortedIndices = receivedIndices.sorted()
        #expect(sortedIndices == Array(0..<iterations))
    }
}
