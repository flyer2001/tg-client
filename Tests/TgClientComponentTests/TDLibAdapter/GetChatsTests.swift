import Testing
import Foundation
@testable import TDLibAdapter

/// Component-тесты для получения списка чатов через TDLib с использованием high-level API.
///
/// Эти тесты проверяют полный flow получения чатов с типобезопасным API,
/// используя MockTDLibClient для изоляции от реального TDLib.
///
/// **Scope:**
/// - Получение списка чатов (getChats)
/// - Фильтрация по типу списка (main/archive)
/// - Обработка пустого результата
/// - Обработка ошибок TDLib
///
/// **Требуемые модели (будут созданы в следующих шагах):**
/// - Request: `GetChatsRequest` (chatList: ChatList, limit: Int)
/// - Response: `ChatsResponse` (chatIds: [Int64])
/// - Enum: `ChatList` (main, archive)
///
/// **Related:**
/// - Unit-тесты моделей: `GetChatsRequestTests`, `ChatsResponseTests` (кодирование/декодирование)
/// - E2E сценарий: <doc:FetchUnreadMessages>
/// - TDLib docs: https://core.telegram.org/tdlib/docs/classtd_1_1td__api_1_1get_chats.html
/// - TDLib Response: https://core.telegram.org/tdlib/docs/classtd_1_1td__api_1_1chats.html
@Suite("TDLibAdapter: Получение списка чатов (getChats)")
struct GetChatsTests {

    // MARK: - Success: Get Chats from Main List

    /// Тест успешного получения списка чатов из основного списка.
    ///
    /// **TDLib flow:**
    /// 1. `getChats(chatList: .main, limit: 100)` → `ChatsResponse(chatIds: [...])`
    ///
    /// **TDLib Response JSON (пример):**
    /// ```json
    /// {
    ///   "@type": "chats",
    ///   "total_count": 2,
    ///   "chat_ids": [123456789, 987654321]
    /// }
    /// ```
    ///
    /// **Требуется:**
    /// - `GetChatsRequest(chatList: ChatList, limit: Int)`
    /// - `ChatsResponse(chatIds: [Int64])`
    /// - `ChatList` enum (.main, .archive)
    /// - `TDLibClientProtocol.getChats(chatList:limit:) async throws -> ChatsResponse`
    ///
    /// **Docs:**
    /// - Method: https://core.telegram.org/tdlib/docs/classtd_1_1td__api_1_1get_chats.html
    /// - Response: https://core.telegram.org/tdlib/docs/classtd_1_1td__api_1_1chats.html
    ///
    /// **Fixture:** `Tests/Fixtures/TDLib/chats_response.json`
    @Test("Успешное получение списка чатов из main")
    func getChatsFromMainList() async throws {
        // Given: Mock client с заранее настроенным ответом
        let mockClient = MockTDLibClient()

        // Настраиваем mock ответ
        await mockClient.setMockResponse(
            for: GetChatsRequest(chatList: .main, limit: 100),
            response: .success(ChatsResponse(chatIds: [123456789, 987654321]))
        )

        // When: Запрашиваем список чатов из основного списка
        let response = try await mockClient.getChats(chatList: .main, limit: 100)

        // Then: Получаем список chatIds
        #expect(response.chatIds.count == 2)
        #expect(response.chatIds.contains(123456789))
        #expect(response.chatIds.contains(987654321))
    }

    // MARK: - Success: Empty Result

    /// Тест обработки пустого результата (нет чатов).
    ///
    /// **TDLib Response JSON:**
    /// ```json
    /// {
    ///   "@type": "chats",
    ///   "total_count": 0,
    ///   "chat_ids": []
    /// }
    /// ```
    ///
    /// **Ожидаемое поведение:**
    /// - Не выбрасывается ошибка
    /// - Возвращается пустой массив chatIds
    @Test("Обработка пустого результата (нет чатов)")
    func getChatsEmptyResult() async throws {
        // Given: Mock client с пустым ответом
        let mockClient = MockTDLibClient()

        // Настраиваем mock ответ с пустым списком
        await mockClient.setMockResponse(
            for: GetChatsRequest(chatList: .main, limit: 100),
            response: .success(ChatsResponse(chatIds: []))
        )

        // When: Запрашиваем список чатов (пустой результат)
        let response = try await mockClient.getChats(chatList: .main, limit: 100)

        // Then: Получаем пустой список без ошибок
        #expect(response.chatIds.isEmpty)
    }

    // MARK: - Success: Archive List

    /// Тест получения чатов из архива.
    ///
    /// **TDLib Request:**
    /// ```json
    /// {
    ///   "@type": "getChats",
    ///   "chat_list": {
    ///     "@type": "chatListArchive"
    ///   },
    ///   "limit": 100
    /// }
    /// ```
    ///
    /// **Docs:** https://core.telegram.org/tdlib/docs/classtd_1_1td__api_1_1chat_list_archive.html
    @Test("Получение чатов из архива")
    func getChatsFromArchive() async throws {
        // Given: Mock client
        let mockClient = MockTDLibClient()

        // Настраиваем mock ответ для архива
        await mockClient.setMockResponse(
            for: GetChatsRequest(chatList: .archive, limit: 50),
            response: .success(ChatsResponse(chatIds: [111222333]))
        )

        // When: Запрашиваем чаты из архива
        let response = try await mockClient.getChats(chatList: .archive, limit: 50)

        // Then: Получаем список архивных чатов
        #expect(response.chatIds.count == 1)
        #expect(response.chatIds.first == 111222333)
    }

    // MARK: - Error Handling

    /// Тест обработки ошибки TDLib: INTERNAL error.
    ///
    /// **TDLib Error JSON:**
    /// ```json
    /// {
    ///   "@type": "error",
    ///   "code": 500,
    ///   "message": "INTERNAL"
    /// }
    /// ```
    ///
    /// **Ожидаемое поведение:**
    /// - Ошибка пробрасывается как исключение
    /// - Содержит код и сообщение из TDLib
    ///
    /// **Docs:** https://core.telegram.org/tdlib/docs/classtd_1_1td__api_1_1error.html
    @Test("Обработка ошибок: TDLib INTERNAL error")
    func errorHandlingInternalError() async throws {
        // Given: Mock client настроенный на выброс ошибки
        let mockClient = MockTDLibClient()

        // Настраиваем mock ответ с ошибкой
        await mockClient.setMockResponse(
            for: GetChatsRequest(chatList: .main, limit: 100),
            response: Result<ChatsResponse, TDLibErrorResponse>.failure(
                TDLibErrorResponse(code: 500, message: "INTERNAL")
            )
        )

        // When/Then: Запрос выбрасывает ошибку
        await #expect(throws: TDLibErrorResponse.self) {
            try await mockClient.getChats(chatList: .main, limit: 100)
        }
    }
}
