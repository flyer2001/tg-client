import Testing
import Foundation
@testable import TDLibAdapter

/// Component-тесты для loadChats и getChat через TDLibClient.
///
/// Эти тесты проверяют интеграцию high-level API для загрузки и получения чатов.
///
/// **Scope:**
/// - `loadChats()` - загрузка чатов в TDLib cache (успех + 404 pagination)
/// - `getChat(chatId:)` - получение полной информации о чате (успех + ошибки)
///
/// **Related:**
/// - Unit-тесты моделей: `LoadChatsRequestTests`, `GetChatRequestTests`, `ChatResponseTests`
/// - TDLib docs:
///   - loadChats: https://core.telegram.org/tdlib/docs/classtd_1_1td__api_1_1load_chats.html
///   - getChat: https://core.telegram.org/tdlib/docs/classtd_1_1td__api_1_1get_chat.html
@Suite("TDLibAdapter: loadChats + getChat")
struct LoadChatsAndGetChatTests {

    // MARK: - loadChats Tests

    /// Тест успешной загрузки чатов: loadChats → Ok.
    ///
    /// **TDLib behavior:**
    /// - Запрос выполняется асинхронно
    /// - Возвращает `Ok` если чаты успешно добавлены в cache
    ///
    /// **Docs:** https://core.telegram.org/tdlib/docs/classtd_1_1td__api_1_1load_chats.html
    @Test("loadChats: успешная загрузка → Ok")
    func loadChatsSuccess() async throws {
        // Given: Mock client с успешным ответом
        let mockClient = MockTDLibClient()
        await mockClient.setMockResponse(
            for: LoadChatsRequest(chatList: .main, limit: 100),
            response: .success(OkResponse())
        )

        // When: Загружаем чаты
        let response = try await mockClient.loadChats(chatList: .main, limit: 100)

        // Then: Получаем Ok
        #expect(response.type == "ok")
    }

    /// Тест обработки 404 ошибки (все чаты загружены).
    ///
    /// **TDLib behavior:**
    /// - При достижении конца списка чатов возвращает ошибку 404
    /// - Это нормальное поведение для завершения pagination loop
    ///
    /// **Проверяем:**
    /// - Метод пробрасывает `TDLibErrorResponse` через `throws`
    /// - Helper `isAllChatsLoaded` корректно определяет 404
    @Test("loadChats: pagination → 404 (все чаты загружены)")
    func loadChatsPaginationEnd() async throws {
        // Given: Mock client с 404 ошибкой
        let mockClient = MockTDLibClient()
        let allChatsLoadedError = TDLibErrorResponse(code: 404, message: "Not Found")
        await mockClient.setMockResponse(
            for: LoadChatsRequest(chatList: .main, limit: 100),
            response: .failure(allChatsLoadedError) as Result<OkResponse, TDLibErrorResponse>
        )

        // When/Then: Загружаем чаты → выбрасывается TDLibErrorResponse
        do {
            _ = try await mockClient.loadChats(chatList: .main, limit: 100)
            Issue.record("Expected TDLibErrorResponse to be thrown")
        } catch let error as TDLibErrorResponse {
            // Then: Проверяем что это 404 и helper работает
            #expect(error.code == 404)
            #expect(error.isAllChatsLoaded == true)
        }
    }

    // MARK: - getChat Tests

    /// Тест успешного получения чата: getChat → ChatResponse.
    ///
    /// **TDLib behavior:**
    /// - Возвращает полную информацию о чате из cache
    /// - Включает: id, type, title, unreadCount, lastReadInboxMessageId
    ///
    /// **Docs:** https://core.telegram.org/tdlib/docs/classtd_1_1td__api_1_1get_chat.html
    @Test("getChat: успешное получение → ChatResponse")
    func getChatSuccess() async throws {
        // Given: Mock client с успешным ответом
        let mockClient = MockTDLibClient()
        let expectedChat = ChatResponse(
            id: 123,
            type: .supergroup(supergroupId: 456, isChannel: true),
            title: "Tech News",
            unreadCount: 5,
            lastReadInboxMessageId: 100
        )
        await mockClient.setMockResponse(
            for: GetChatRequest(chatId: 123),
            response: .success(expectedChat)
        )

        // When: Получаем чат
        let chat = try await mockClient.getChat(chatId: 123)

        // Then: Проверяем все поля
        #expect(chat.id == 123)
        #expect(chat.chatType == .supergroup(supergroupId: 456, isChannel: true))
        #expect(chat.title == "Tech News")
        #expect(chat.unreadCount == 5)
        #expect(chat.lastReadInboxMessageId == 100)
    }

    /// Тест обработки ошибки 400 (чат не найден).
    ///
    /// **TDLib error:**
    /// ```json
    /// {
    ///   "@type": "error",
    ///   "code": 400,
    ///   "message": "Chat not found"
    /// }
    /// ```
    @Test("getChat: ошибка 400 (чат не найден)")
    func getChatNotFound() async throws {
        // Given: Mock client с 400 ошибкой
        let mockClient = MockTDLibClient()
        let chatNotFoundError = TDLibErrorResponse(code: 400, message: "Chat not found")
        await mockClient.setMockResponse(
            for: GetChatRequest(chatId: 999),
            response: .failure(chatNotFoundError) as Result<ChatResponse, TDLibErrorResponse>
        )

        // When/Then: Получаем несуществующий чат → выбрасывается ошибка
        do {
            _ = try await mockClient.getChat(chatId: 999)
            Issue.record("Expected TDLibErrorResponse to be thrown")
        } catch let error as TDLibErrorResponse {
            #expect(error.code == 400)
            #expect(error.message == "Chat not found")
        }
    }

    /// Тест получения приватного чата с корректным ChatType.
    ///
    /// **Проверяем:**
    /// - ChatType правильно декодируется для разных типов чатов
    /// - Поля опциональны (например, username может быть nil)
    @Test("getChat: приватный чат с userId")
    func getChatPrivate() async throws {
        // Given: Mock client с приватным чатом
        let mockClient = MockTDLibClient()
        let privateChat = ChatResponse(
            id: 456,
            type: .private(userId: 5569612430),
            title: "Заметки от Алисы",
            unreadCount: 0,
            lastReadInboxMessageId: 319645810688
        )
        await mockClient.setMockResponse(
            for: GetChatRequest(chatId: 456),
            response: .success(privateChat)
        )

        // When: Получаем приватный чат
        let chat = try await mockClient.getChat(chatId: 456)

        // Then: Проверяем тип и поля
        #expect(chat.chatType == .private(userId: 5569612430))
        #expect(chat.title == "Заметки от Алисы")
        #expect(chat.unreadCount == 0)
    }
}
