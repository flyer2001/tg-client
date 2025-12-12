import TgClientModels
import TGClientInterfaces
import Foundation
import Logging
import Testing
@testable import TDLibAdapter
@testable import DigestCore
import TestHelpers

/// Component тесты для flow "Отметка сообщений как прочитанных".
///
/// **Scope:**
/// - Parallel mark-as-read для N чатов (TaskGroup)
/// - Partial failure handling (1 чат failed → остальные помечаем)
/// - Concurrency limit (maxParallelRequests)
///
/// **Проверка через логи:**
/// - Success: `logger.info("Chat \(chatId) marked as read")`
/// - Error: `logger.error("Failed to mark chat \(chatId) as read", error: ...)`
///
/// **Связанная документация:**
/// - E2E сценарий: <doc:MarkAsRead>
/// - Unit тесты модели: ViewMessagesRequestTests.swift
/// - RFC: MVP.md § v0.4.0
@Suite("Component: Отметка сообщений как прочитанных")
struct MarkAsReadFlowTests {

    /// Happy path: отметка сообщений для одного чата.
    ///
    /// **Given:** TDLibClient (MockTDLibFFI) возвращает Ok для viewMessages
    ///
    /// **When:** Вызываем `service.markAsRead([chatId: [messageIds]])`
    ///
    /// **Then:**
    /// - Результат: [chatId: .success(())]
    /// - Лог: "Chat \(chatId) marked as read"
    @Test("Отметка сообщений: один чат успешно")
    func markAsReadSingleChatSuccess() async throws {
        // Given: TDLibClient с MockTDLibFFI
        let mockFFI = MockTDLibFFI()
        let mockLogger = MockLogger()
        let logger = mockLogger.makeLogger(label: "test")

        let tdlibClient = TDLibClient(
            ffi: mockFFI,
            appLogger: logger,
            authorizationPollTimeout: 0.1,
            maxAuthorizationAttempts: 10,
            authorizationTimeout: 5
        )

        tdlibClient.startUpdatesLoop()

        // Настраиваем mock: viewMessages → Ok
        mockFFI.mockResponse(forRequestType: "viewMessages", return: .success(OkResponse()))

        // Given: MarkAsReadService
        let service = MarkAsReadService(
            tdlib: tdlibClient,
            logger: logger,
            maxParallelRequests: 20,
            timeout: .seconds(2)
        )

        // When: отмечаем сообщения как прочитанные
        let chatId: Int64 = 123456
        let messageIds: [Int64] = [1, 2, 3]

        let results = await service.markAsRead([chatId: messageIds])

        // Then: успех для этого чата
        #expect(results.count == 1)
        #expect(results[chatId] != nil)

        switch results[chatId]! {
        case .success:
            break // OK
        case .failure(let error):
            Issue.record("Expected success, got error: \(error)")
        }

        // Then: проверяем лог success
        let infoLogs = mockLogger.messages.filter { $0.level == .info }
        #expect(infoLogs.contains { $0.message.contains("Chat \(chatId) marked as read") })
    }

    /// Partial failure: некоторые чаты failed.
    ///
    /// **Given:** 3 чата, 1 error response в FIFO очереди
    ///
    /// **When:** Вызываем `service.markAsRead([chat1, chat2, chat3])`
    ///
    /// **Then:**
    /// - 2 чата: success
    /// - 1 чат: failure
    /// - Есть error лог
    @Test("Partial failure: некоторые чаты failed")
    func markAsReadPartialFailure() async throws {
        let mockFFI = MockTDLibFFI()
        let mockLogger = MockLogger()
        let logger = mockLogger.makeLogger(label: "test")

        let tdlibClient = TDLibClient(
            ffi: mockFFI,
            appLogger: logger,
            authorizationPollTimeout: 0.1,
            maxAuthorizationAttempts: 10,
            authorizationTimeout: 5
        )

        tdlibClient.startUpdatesLoop()

        // Настраиваем mock: 2 Ok, 1 Error (порядок недетерминирован из-за TaskGroup)
        mockFFI.mockResponse(forRequestType: "viewMessages", return: .success(OkResponse()))
        mockFFI.mockResponse(
            forRequestType: "viewMessages",
            return: Result<OkResponse, TDLibErrorResponse>.failure(
                TDLibErrorResponse(code: 500, message: "Internal error")
            )
        )
        mockFFI.mockResponse(forRequestType: "viewMessages", return: .success(OkResponse()))

        let service = MarkAsReadService(
            tdlib: tdlibClient,
            logger: logger,
            maxParallelRequests: 20,
            timeout: .seconds(2)
        )

        // When: отмечаем 3 чата
        let chat1: Int64 = 111
        let chat2: Int64 = 222
        let chat3: Int64 = 333

        let results = await service.markAsRead([
            chat1: [1, 2],
            chat2: [3, 4],
            chat3: [5, 6]
        ])

        // Then: проверяем соотношение success/failure
        #expect(results.count == 3)

        let successCount = results.values.filter {
            if case .success = $0 { return true }
            return false
        }.count

        let failureCount = results.values.filter {
            if case .failure = $0 { return true }
            return false
        }.count

        #expect(successCount == 2, "Expected 2 successful, got \(successCount)")
        #expect(failureCount == 1, "Expected 1 failed, got \(failureCount)")

        // Then: проверяем логи — есть хотя бы один error
        let errorLogs = mockLogger.messages.filter { $0.level == .error }
        #expect(!errorLogs.isEmpty, "Expected error log for failed chat")
        #expect(errorLogs.contains { $0.message.contains("Failed to mark chat") })
    }

    /// Empty input: пустой словарь чатов.
    ///
    /// **Given:** Пустой словарь `[:]`
    ///
    /// **When:** Вызываем `service.markAsRead([:])`
    ///
    /// **Then:** Возвращает пустой результат, без ошибок
    @Test("Empty input: пустой словарь")
    func markAsReadEmptyInput() async throws {
        let mockFFI = MockTDLibFFI()
        let mockLogger = MockLogger()
        let logger = mockLogger.makeLogger(label: "test")

        let tdlibClient = TDLibClient(
            ffi: mockFFI,
            appLogger: logger,
            authorizationPollTimeout: 0.1,
            maxAuthorizationAttempts: 10,
            authorizationTimeout: 5
        )

        tdlibClient.startUpdatesLoop()

        let service = MarkAsReadService(
            tdlib: tdlibClient,
            logger: logger,
            maxParallelRequests: 20,
            timeout: .seconds(2)
        )

        // When: пустой словарь
        let results = await service.markAsRead([:])

        // Then: пустой результат
        #expect(results.isEmpty)
    }

    /// Concurrency limit: проверка параллелизма для большого batch.
    ///
    /// **Given:** 50 чатов (превышает maxParallelRequests = 20)
    ///
    /// **When:** Вызываем `service.markAsRead([50 чатов])`
    ///
    /// **Then:** Все 50 чатов успешно обработаны
    @Test("Concurrency limit: большой batch")
    func markAsReadLargeBatch() async throws {
        let mockFFI = MockTDLibFFI()
        let mockLogger = MockLogger()
        let logger = mockLogger.makeLogger(label: "test")

        let tdlibClient = TDLibClient(
            ffi: mockFFI,
            appLogger: logger,
            authorizationPollTimeout: 0.1,
            maxAuthorizationAttempts: 10,
            authorizationTimeout: 5
        )

        tdlibClient.startUpdatesLoop()

        // Настраиваем mock: 50 успешных responses
        for _ in 1...50 {
            mockFFI.mockResponse(forRequestType: "viewMessages", return: .success(OkResponse()))
        }

        let service = MarkAsReadService(
            tdlib: tdlibClient,
            logger: logger,
            maxParallelRequests: 20,
            timeout: .seconds(2)
        )

        // When: создаём 50 чатов
        var messages: [Int64: [Int64]] = [:]
        for i in 1...50 {
            messages[Int64(i)] = [Int64(i * 10)]
        }

        let results = await service.markAsRead(messages)

        // Then: все 50 чатов успешно обработаны
        #expect(results.count == 50)

        let successCount = results.values.filter {
            if case .success = $0 { return true }
            return false
        }.count

        #expect(successCount == 50, "All 50 chats should succeed")
    }
}
