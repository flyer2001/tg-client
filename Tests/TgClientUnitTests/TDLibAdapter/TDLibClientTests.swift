import TgClientModels
import TGClientInterfaces
import Testing
import Logging
import TestHelpers
@testable import TDLibAdapter

/// Unit-тесты для TDLibClient.
///
/// Тестируют РЕАЛЬНУЮ логику TDLibClient (ResponseWaiters, JSON парсинг, обработка ошибок)
/// используя MockTDLibFFI для изоляции от C-библиотеки TDLib.
@Suite("TDLibClient Unit Tests")
struct TDLibClientTests {

    @Test("getMe() возвращает успешный ответ через FFI")
    func getMeReturnsSuccessResponse() async throws {
        print("\n🧪 TEST START: getMeReturnsSuccessResponse")
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
        print("\n🧪 TEST START: getMeThrowsErrorFromFFI")
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

    @Test("Параллельные запросы getChat матчатся по @extra")
    func parallelRequestsMatchByExtra() async throws {
        print("\n🧪 TEST START: parallelRequestsMatchByExtra")
        let mockFFI = MockTDLibFFI()

        // Мокаем 2 "шаблонных" response (id будет перезаписан из request)
        mockFFI.mockResponse(
            forRequestType: "getChat",
            return: .success(ChatResponse(id: 0, type: .private(userId: 1), title: "Mock", unreadCount: 0, lastReadInboxMessageId: 0))
        )
        mockFFI.mockResponse(
            forRequestType: "getChat",
            return: .success(ChatResponse(id: 0, type: .private(userId: 2), title: "Mock", unreadCount: 0, lastReadInboxMessageId: 0))
        )

        let logger = Logger(label: "test")
        let client = TDLibClient(ffi: mockFFI, appLogger: logger)
        client.startUpdatesLoop()

        async let chat1 = client.getChat(chatId: 123)
        async let chat2 = client.getChat(chatId: 456)

        let (c1, c2) = try await (chat1, chat2)

        // Главное: каждый request получил response с СВОИМ chatId
        #expect(c1.id == 123)
        #expect(c2.id == 456)
    }

    /// 100 параллельных getChat запросов матчатся точно по @extra.
    ///
    /// **Проблема (до @extra matching):**
    /// При FIFO подходе response для chatId=456 мог прийти к waiter для chatId=123.
    ///
    /// **Given:** MockTDLibFFI с 100 замоканными getChat responses
    /// **When:** 100 параллельных getChat запросов
    /// **Then:** Каждый запрос получает response с СВОИМ chatId (точный матчинг по @extra)
    @Test("100 параллельных getChat запросов матчатся по @extra")
    func parallelGetChatRequestsMatchByExtra() async throws {
        print("\n🧪 TEST START: parallelGetChatRequestsMatchByExtra")
        let mockFFI = MockTDLibFFI()

        // Мокаем 100 responses с разными chatId
        let chatIds: [Int64] = (1...100).map { Int64($0 * 1000) }  // 1000, 2000, ... 100000
        for chatId in chatIds {
            mockFFI.mockResponse(
                forRequestType: "getChat",
                return: .success(ChatResponse(
                    id: chatId,
                    type: .`private`(userId: chatId),
                    title: "Chat \(chatId)",
                    unreadCount: 0,
                    lastReadInboxMessageId: 0
                ))
            )
        }

        let logger = Logger(label: "test")
        let client = TDLibClient(ffi: mockFFI, appLogger: logger)
        client.startUpdatesLoop()

        // 100 параллельных запросов
        let results: [(requested: Int64, received: Int64)] = try await withThrowingTaskGroup(
            of: (Int64, Int64).self
        ) { group in
            for chatId in chatIds {
                group.addTask {
                    let chat = try await client.getChat(chatId: chatId)
                    return (chatId, chat.id)
                }
            }

            var collected: [(Int64, Int64)] = []
            for try await result in group {
                collected.append(result)
            }
            return collected
        }

        // ASSERT: каждый запрос получил СВОЙ response
        for (requested, received) in results {
            #expect(requested == received, "Request for chatId=\(requested) received chatId=\(received)")
        }
    }

    @Test("updates stream получает update даже если startUpdatesLoop() вызван ДО подписки")
    func updatesStreamReceivesUpdateAfterStartUpdatesLoop() async throws {
        print("\n🧪 TEST START: updatesStreamReceivesUpdateAfterStartUpdatesLoop")
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
