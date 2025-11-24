import Testing
import Logging
@testable import TDLibAdapter

/// Unit-тесты для TDLibClient.
///
/// Тестируют РЕАЛЬНУЮ логику TDLibClient (ResponseWaiters, JSON парсинг, обработка ошибок)
/// используя MockTDLibFFI для изоляции от C-библиотеки TDLib.
@Suite("TDLibClient Unit Tests")
struct TDLibClientTests {

    @Test("getMe() возвращает успешный ответ через FFI")
    func getMeReturnsSuccessResponse() async throws {
        let mockFFI = MockTDLibFFI()
        mockFFI.mockResponse(
            forRequestType: "getMe",
            return: .success(UserResponse(id: 777, firstName: "John", lastName: "Doe"))
        )

        let logger = Logger(label: "test")
        let client = TDLibClient(ffi: mockFFI, appLogger: logger)
        client.startUpdatesLoop()

        let user = try await client.getMe()

        #expect(user.id == 777)
        #expect(user.firstName == "John")
        #expect(user.lastName == "Doe")
    }

    @Test("getMe() бросает TDLibErrorResponse при ошибке от FFI")
    func getMeThrowsErrorFromFFI() async throws {
        let mockFFI = MockTDLibFFI()
        mockFFI.mockResponse(
            forRequestType: "getMe",
            return: .failure(TDLibErrorResponse(code: 500, message: "Internal error")) as Result<UserResponse, TDLibErrorResponse>
        )

        let logger = Logger(label: "test")
        let client = TDLibClient(ffi: mockFFI, appLogger: logger)
        client.startUpdatesLoop()

        do {
            _ = try await client.getMe()
            #expect(Bool(false), "Должна быть брошена TDLibErrorResponse")
        } catch let error as TDLibErrorResponse {
            #expect(error.code == 500)
            #expect(error.message == "Internal error")
        }
    }

    @Test("Параллельные запросы getChat обрабатываются через FIFO")
    func parallelRequestsHandledViaFIFO() async throws {
        let mockFFI = MockTDLibFFI()
        mockFFI.mockResponse(
            forRequestType: "getChat",
            return: .success(ChatResponse(id: 123, type: .private(userId: 1), title: "First", unreadCount: 0, lastReadInboxMessageId: 0))
        )
        mockFFI.mockResponse(
            forRequestType: "getChat",
            return: .success(ChatResponse(id: 456, type: .private(userId: 2), title: "Second", unreadCount: 0, lastReadInboxMessageId: 0))
        )

        let logger = Logger(label: "test")
        let client = TDLibClient(ffi: mockFFI, appLogger: logger)
        client.startUpdatesLoop()

        async let chat1 = client.getChat(chatId: 123)
        async let chat2 = client.getChat(chatId: 456)

        let (c1, c2) = try await (chat1, chat2)

        #expect(c1.id == 123)
        #expect(c1.title == "First")
        #expect(c2.id == 456)
        #expect(c2.title == "Second")
    }

    @Test("updates stream получает update даже если startUpdatesLoop() вызван ДО подписки")
    func updatesStreamReceivesUpdateAfterStartUpdatesLoop() async throws {
        let mockFFI = MockTDLibFFI()
        let logger = Logger(label: "test")
        let client = TDLibClient(ffi: mockFFI, appLogger: logger)

        // КРИТИЧНО: startUpdatesLoop() вызывается ДО подписки на updates
        // Это имитирует реальный сценарий в start() где loop запускается сразу
        client.startUpdatesLoop()

        // Эмитим update ПОСЛЕ запуска loop (но ДО подписки)
        mockFFI.mockUpdate(.chatReadInbox(chatId: 999, lastReadInboxMessageId: 42, unreadCount: 3))

        // ТЕПЕРЬ подписываемся на updates (ПОСЛЕ startUpdatesLoop и ПОСЛЕ emit)
        // for await детерминированно ждёт первого update (НЕ нужен Task.sleep)
        var receivedUpdate: Update?
        for await update in client.updates {
            receivedUpdate = update
            break
        }

        // Проверяем что update дошёл несмотря на race condition
        guard case .chatReadInbox(let chatId, let messageId, let unreadCount) = receivedUpdate else {
            #expect(Bool(false), "Expected chatReadInbox update, got \(String(describing: receivedUpdate))")
            return
        }

        #expect(chatId == 999)
        #expect(messageId == 42)
        #expect(unreadCount == 3)
    }
}
