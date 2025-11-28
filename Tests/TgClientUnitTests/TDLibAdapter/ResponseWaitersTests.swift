import TgClientModels
import TGClientInterfaces
import Foundation
import Testing
@preconcurrency @testable import TDLibAdapter

// MARK: - Test Helpers

extension ResponseWaiters {
    /// Для тестов: регистрирует waiter по @extra и вызывает callback когда готово.
    ///
    /// Гарантирует что continuation зарегистрирован до возврата из callback.
    nonisolated func addWaiterWithCallback(
        forExtra extra: String,
        continuation: CheckedContinuation<TDLibJSON, Error>,
        onRegistered: @escaping @Sendable () -> Void
    ) {
        Task {
            await self.addWaiter(forExtra: extra, continuation: continuation)
            onRegistered()  // ✅ Сигнал: continuation зарегистрирован
        }
    }

    /// Для тестов: регистрирует waiter по типу (для unsolicited updates).
    ///
    /// Гарантирует что continuation зарегистрирован до возврата из callback.
    nonisolated func addWaiterWithCallback(
        forType type: String,
        continuation: CheckedContinuation<TDLibJSON, Error>,
        onRegistered: @escaping @Sendable () -> Void
    ) {
        Task {
            await self.addWaiter(forType: type, continuation: continuation)
            onRegistered()  // ✅ Сигнал: continuation зарегистрирован
        }
    }
}

/// Unit-тесты для ResponseWaiters - механизм управления continuations для async запросов.
///
/// **Назначение:**
/// ResponseWaiters управляет continuations для запросов к TDLib.
/// Каждый запрос идентифицируется уникальным @extra ключом.
///
/// **@extra matching:**
/// - TDLibClient генерирует уникальный @extra для каждого запроса
/// - TDLib копирует @extra из request в response
/// - ResponseWaiters матчит response к waiter по @extra
///
/// **Используется в:**
/// - TDLibClient (Real) - для обработки ответов от TDLib
@Suite("Unit: ResponseWaiters - @extra matching")
struct ResponseWaitersTests {

    // MARK: - Basic @extra Matching

    /// Базовый сценарий: добавление waiter и успешный resume по @extra.
    ///
    /// **Given:** ResponseWaiters без waiters
    /// **When:** Добавляем waiter с @extra="req_1" → resume с тем же @extra
    /// **Then:** Continuation получает response
    @Test("addWaiter + resume по @extra → continuation получает response")
    func addWaiterAndResumeByExtra() async throws {
        let waiters = ResponseWaiters()
        let extra = "req_123"
        let expectedResponse = try TDLibJSON(parsing: ["@type": "chat", "id": 42, "@extra": extra])

        let (stream, streamContinuation) = AsyncStream.makeStream(of: Void.self)

        let task = Task<Bool, Error> {
            let result = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<TDLibJSON, Error>) in
                waiters.addWaiterWithCallback(forExtra: extra, continuation: continuation) {
                    streamContinuation.yield(())
                }
            }
            return result["id"] as? Int == 42
        }

        _ = await stream.first(where: { _ in true })

        let resumeResult = await waiters.resumeWaiter(forExtra: extra, with: expectedResponse)
        #expect(resumeResult.wasResumed)

        let success = try await task.value
        #expect(success)
    }

    /// Resume waiter с error по @extra.
    ///
    /// **Given:** Waiter зарегистрирован с @extra="err_req"
    /// **When:** Resume с error для того же @extra
    /// **Then:** Continuation бросает ошибку
    @Test("resume с error по @extra → continuation бросает ошибку")
    func resumeWithErrorByExtra() async throws {
        let waiters = ResponseWaiters()
        let extra = "err_req"
        let expectedError = NSError(domain: "TDLib", code: 404, userInfo: [NSLocalizedDescriptionKey: "Chat not found"])

        let (stream, streamContinuation) = AsyncStream.makeStream(of: Void.self)

        let task = Task<Bool, Error> {
            do {
                _ = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<TDLibJSON, Error>) in
                    waiters.addWaiterWithCallback(forExtra: extra, continuation: continuation) {
                        streamContinuation.yield(())
                    }
                }
                return false
            } catch {
                let nsError = error as NSError
                return nsError.domain == "TDLib" && nsError.code == 404
            }
        }

        _ = await stream.first(where: { _ in true })

        let resumeResult = await waiters.resumeWaiter(forExtra: extra, with: expectedError)
        #expect(resumeResult.wasResumed)

        let errorMatched = try await task.value
        #expect(errorMatched)
    }

    /// Resume с несуществующим @extra → .noWaiter.
    ///
    /// **Given:** ResponseWaiters без waiters
    /// **When:** Resume с неизвестным @extra
    /// **Then:** Возвращает .noWaiter (не крашится)
    @Test("resume с несуществующим @extra → .noWaiter")
    func resumeWithUnknownExtra() async throws {
        let waiters = ResponseWaiters()
        let response = try TDLibJSON(parsing: ["@type": "ok", "@extra": "unknown_123"])

        let result = await waiters.resumeWaiter(forExtra: "unknown_123", with: response)

        #expect(!result.wasResumed)
        #expect(result == .noWaiter)
    }

    // MARK: - Precise Matching (не FIFO!)

    /// Точный матчинг: 3 параллельных запроса, resume в обратном порядке.
    ///
    /// **Проблема старой реализации:**
    /// Ключ = requestType → параллельные getChat попадают в одну FIFO очередь.
    /// Response для chatId=456 может прийти к waiter для chatId=123.
    ///
    /// **Given:** 3 waiters: @extra="req_1", "req_2", "req_3"
    /// **When:** Resume в ОБРАТНОМ порядке: req_3 → req_2 → req_1
    /// **Then:** Каждый waiter получает СВОЙ response (точный матчинг по @extra)
    @Test("@extra matching: точный матчинг, не FIFO")
    func preciseMatchingNotFIFO() async throws {
        let waiters = ResponseWaiters()

        let (stream, streamContinuation) = AsyncStream.makeStream(of: Void.self)

        // 3 waiters с разными @extra
        let task1 = Task<String, Error> {
            let result = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<TDLibJSON, Error>) in
                waiters.addWaiterWithCallback(forExtra: "req_1", continuation: continuation) {
                    streamContinuation.yield(())
                }
            }
            return result["data"] as? String ?? "none"
        }
        let task2 = Task<String, Error> {
            let result = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<TDLibJSON, Error>) in
                waiters.addWaiterWithCallback(forExtra: "req_2", continuation: continuation) {
                    streamContinuation.yield(())
                }
            }
            return result["data"] as? String ?? "none"
        }
        let task3 = Task<String, Error> {
            let result = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<TDLibJSON, Error>) in
                waiters.addWaiterWithCallback(forExtra: "req_3", continuation: continuation) {
                    streamContinuation.yield(())
                }
            }
            return result["data"] as? String ?? "none"
        }

        // Ждём регистрации всех 3
        for _ in 0..<3 {
            _ = await stream.first(where: { _ in true })
        }

        // Resume в ОБРАТНОМ порядке (если бы был FIFO — req_1 получил бы data_3)
        let response3 = try TDLibJSON(parsing: ["data": "data_3", "@extra": "req_3"])
        let response2 = try TDLibJSON(parsing: ["data": "data_2", "@extra": "req_2"])
        let response1 = try TDLibJSON(parsing: ["data": "data_1", "@extra": "req_1"])

        #expect((await waiters.resumeWaiter(forExtra: "req_3", with: response3)).wasResumed)
        #expect((await waiters.resumeWaiter(forExtra: "req_2", with: response2)).wasResumed)
        #expect((await waiters.resumeWaiter(forExtra: "req_1", with: response1)).wasResumed)

        // Каждый получил СВОЙ response
        #expect(try await task1.value == "data_1")
        #expect(try await task2.value == "data_2")
        #expect(try await task3.value == "data_3")
    }

    // MARK: - cancelAll

    /// cancelAll() отменяет все ожидающие continuations.
    ///
    /// **Given:** 3 waiters с разными @extra
    /// **When:** cancelAll()
    /// **Then:** Все continuations получают CancellationError
    @Test("cancelAll → все continuations получают CancellationError")
    func cancelAllWaiters() async throws {
        let waiters = ResponseWaiters()

        let (stream, streamContinuation) = AsyncStream.makeStream(of: Void.self)

        let task1 = Task<Bool, Error> {
            do {
                _ = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<TDLibJSON, Error>) in
                    waiters.addWaiterWithCallback(forExtra: "cancel_1", continuation: continuation) {
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
                    waiters.addWaiterWithCallback(forExtra: "cancel_2", continuation: continuation) {
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
                    waiters.addWaiterWithCallback(forExtra: "cancel_3", continuation: continuation) {
                        streamContinuation.yield(())
                    }
                }
                return false
            } catch is CancellationError {
                return true
            }
        }

        for _ in 0..<3 {
            _ = await stream.first(where: { _ in true })
        }

        await waiters.cancelAll()

        #expect(try await task1.value)
        #expect(try await task2.value)
        #expect(try await task3.value)
    }

    // MARK: - Type-based Matching (для unsolicited updates)

    /// addWaiter(forType:) для unsolicited updates (updateAuthorizationState).
    ///
    /// **Use case:** Authorization flow ждёт `updateAuthorizationState` без @extra
    /// (TDLib отправляет их сам, не в ответ на request).
    ///
    /// **Given:** ResponseWaiters без waiters
    /// **When:** addWaiter(forType: "updateAuthorizationState") → resume с тем же типом
    /// **Then:** Continuation получает update
    @Test("addWaiter(forType:) + resume по типу → continuation получает update")
    func addWaiterByTypeAndResumeByType() async throws {
        let waiters = ResponseWaiters()
        let updateType = "updateAuthorizationState"
        let expectedUpdate = try TDLibJSON(parsing: [
            "@type": updateType,
            "authorization_state": ["@type": "authorizationStateReady"]
        ])

        let (stream, streamContinuation) = AsyncStream.makeStream(of: Void.self)

        let task = Task<Bool, Error> {
            let result = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<TDLibJSON, Error>) in
                waiters.addWaiterWithCallback(forType: updateType, continuation: continuation) {
                    streamContinuation.yield(())
                }
            }
            return result["@type"] as? String == updateType
        }

        _ = await stream.first(where: { _ in true })

        let resumeResult = await waiters.resumeWaiter(forType: updateType, with: expectedUpdate)
        #expect(resumeResult.wasResumed)

        let success = try await task.value
        #expect(success)
    }

    /// Resume с несуществующим типом → .noWaiter.
    ///
    /// **Given:** ResponseWaiters без waiters
    /// **When:** Resume с неизвестным типом
    /// **Then:** Возвращает .noWaiter
    @Test("resume с несуществующим типом → .noWaiter")
    func resumeWithUnknownType() async throws {
        let waiters = ResponseWaiters()
        let update = try TDLibJSON(parsing: ["@type": "updateNewChat", "chat": ["id": 123]])

        let result = await waiters.resumeWaiter(forType: "updateNewChat", with: update)

        #expect(!result.wasResumed)
        #expect(result == .noWaiter)
    }

    /// Смешанный сценарий: @extra и @type waiters одновременно (изоляция).
    ///
    /// **Given:** ResponseWaiters с 2 waiters: один по @extra, один по @type
    /// **When:** Resume оба
    /// **Then:** Каждый получает свой response, нет cross-matching
    @Test("@extra и @type waiters не мешают друг другу")
    func mixedExtraAndTypeWaiters() async throws {
        let waiters = ResponseWaiters()

        let (stream, streamContinuation) = AsyncStream.makeStream(of: Void.self)

        // Waiter по @extra (request/response)
        let extraTask = Task<String, Error> {
            let result = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<TDLibJSON, Error>) in
                waiters.addWaiterWithCallback(forExtra: "req_42", continuation: continuation) {
                    streamContinuation.yield(())
                }
            }
            return result["data"] as? String ?? "none"
        }

        // Waiter по @type (unsolicited update)
        let typeTask = Task<String, Error> {
            let result = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<TDLibJSON, Error>) in
                waiters.addWaiterWithCallback(forType: "updateAuthorizationState", continuation: continuation) {
                    streamContinuation.yield(())
                }
            }
            return result["@type"] as? String ?? "none"
        }

        // Ждём регистрации обоих
        _ = await stream.first(where: { _ in true })
        _ = await stream.first(where: { _ in true })

        // Resume оба (в любом порядке)
        let extraResponse = try TDLibJSON(parsing: ["data": "response_data", "@extra": "req_42"])
        let typeResponse = try TDLibJSON(parsing: ["@type": "updateAuthorizationState", "state": "ready"])

        #expect((await waiters.resumeWaiter(forExtra: "req_42", with: extraResponse)).wasResumed)
        #expect((await waiters.resumeWaiter(forType: "updateAuthorizationState", with: typeResponse)).wasResumed)

        // Каждый получил свой response
        #expect(try await extraTask.value == "response_data")
        #expect(try await typeTask.value == "updateAuthorizationState")
    }
}
