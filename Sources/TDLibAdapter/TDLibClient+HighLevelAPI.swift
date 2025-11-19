import Foundation
import FoundationExtensions

/// High-level API для TDLibClient.
///
/// Предоставляет типобезопасные методы для работы с TDLib вместо низкоуровневого send/receive.
extension TDLibClient: TDLibClientProtocol {

    // MARK: - Authentication Methods

    public func setAuthenticationPhoneNumber(_ phoneNumber: String) async throws -> AuthorizationStateUpdateResponse {
        // Отправляем запрос на установку номера телефона
        send(SetAuthenticationPhoneNumberRequest(phoneNumber: phoneNumber))

        // Ожидаем обновления состояния авторизации
        return try await waitForAuthorizationUpdate()
    }

    public func checkAuthenticationCode(_ code: String) async throws -> AuthorizationStateUpdateResponse {
        // Отправляем запрос на проверку кода
        send(CheckAuthenticationCodeRequest(code: code))

        // Ожидаем обновления состояния авторизации
        return try await waitForAuthorizationUpdate()
    }

    public func checkAuthenticationPassword(_ password: String) async throws -> AuthorizationStateUpdateResponse {
        // Отправляем запрос на проверку пароля 2FA
        send(CheckAuthenticationPasswordRequest(password: password))

        // Ожидаем обновления состояния авторизации
        return try await waitForAuthorizationUpdate()
    }

    // MARK: - User Methods

    public func getMe() async throws -> UserResponse {
        // Отправляем запрос на получение информации о текущем пользователе
        send(GetMeRequest())

        // Ожидаем ответа от TDLib
        return try await waitForResponse(ofType: UserResponse.self, expectedType: "user")
    }

    // MARK: - Chat Methods

    public func getChats(chatList: ChatList, limit: Int) async throws -> ChatsResponse {
        // Отправляем запрос на получение списка чатов
        send(GetChatsRequest(chatList: chatList, limit: limit))

        // Ожидаем ответа от TDLib
        return try await waitForResponse(ofType: ChatsResponse.self, expectedType: "chats")
    }

    public func loadChats(chatList: ChatList, limit: Int) async throws -> OkResponse {
        appLogger.debug("loadChats: sending request (chatList: \(chatList), limit: \(limit))")

        // Отправляем запрос на загрузку чатов
        send(LoadChatsRequest(chatList: chatList, limit: limit))
        appLogger.debug("loadChats: request sent, waiting for OkResponse...")

        // Ожидаем ответа от TDLib
        let response = try await waitForResponse(ofType: OkResponse.self, expectedType: "ok")
        appLogger.debug("loadChats: received OkResponse")
        return response
    }

    public func getChat(chatId: Int64) async throws -> ChatResponse {
        // Отправляем запрос на получение чата
        send(GetChatRequest(chatId: chatId))

        // Ожидаем ответа от TDLib
        return try await waitForResponse(ofType: ChatResponse.self, expectedType: "chat")
    }

    public func getChatHistory(chatId: Int64, fromMessageId: Int64, offset: Int32, limit: Int32) async throws -> MessagesResponse {
        // Отправляем запрос на получение истории сообщений
        send(GetChatHistoryRequest(chatId: chatId, fromMessageId: fromMessageId, offset: offset, limit: limit, onlyLocal: false))

        // Ожидаем ответа от TDLib
        return try await waitForResponse(ofType: MessagesResponse.self, expectedType: "messages")
    }

    // MARK: - Updates

    /// AsyncStream для получения updates от TDLib.
    ///
    /// **ВАЖНО:** Background loop запускается в `start()`, НЕ здесь!
    public var updates: AsyncStream<Update> {
        // Создаём stream только один раз
        if updatesContinuation == nil {
            let (stream, continuation) = AsyncStream<Update>.makeStream()
            updatesContinuation = continuation
            return stream
        }

        // Повторное обращение - создаём новый stream с тем же continuation
        return AsyncStream<Update> { continuation in
            // FIXME: Это не правильно - нужно хранить массив continuation'ов для broadcast
            // Для MVP работает т.к. у нас один подписчик (ChannelMessageSource)
            //
            // Когда появится второй подписчик (например, NotificationManager):
            // - ⚠️ ПРОБЛЕМА ПРОЯВИТСЯ: второй подписчик получит пустой stream
            // - ✅ РЕШЕНИЕ: broadcast через массив continuations (см. TASKS.md → Technical Debt)
            // - ✅ ТЕСТ: unit-тест на двух подписчиков (пока рано писать)
            continuation.onTermination = { @Sendable _ in }
        }
    }

    // MARK: - Helper Methods

    /// Ожидает следующего обновления состояния авторизации от TDLib.
    ///
    /// **АРХИТЕКТУРНОЕ РЕШЕНИЕ:**
    /// Теперь использует единый background loop через `waitForResponse()` вместо прямого `receive()`.
    /// Это устраняет race condition между authorization loop и background updates loop.
    ///
    /// - Returns: Обновление состояния авторизации
    /// - Throws: `TDLibError` если TDLib вернул ошибку
    func waitForAuthorizationUpdate() async throws -> AuthorizationStateUpdateResponse {
        // Ждём updateAuthorizationState через единый background loop
        return try await waitForResponse(
            ofType: AuthorizationStateUpdateResponse.self,
            expectedType: "updateAuthorizationState"
        )
    }

    /// Ожидает ответа определенного типа от TDLib.
    ///
    /// Метод получает обновления от TDLib через `receive()` и возвращает первый ответ
    /// указанного типа. Если получена ошибка, бросает исключение.
    ///
    /// **Таймаут:** использует `authorizationPollTimeout` из конфигурации клиента.
    ///
    /// **Error handling:**
    /// Все ошибки TDLib пробрасываются как `TDLibErrorResponse`. Критичные коды:
    /// - **SESSION_REVOKED / AUTH_KEY_UNREGISTERED**: Требуется ре-авторизация (пользователь завершил все сессии)
    /// - **500**: TDLib client закрыт, необходим restart приложения
    /// - **406**: Не показывать пользователю (внутренняя ошибка TDLib)
    /// - **USER_DEACTIVATED**: Аккаунт заблокирован/деактивирован
    ///
    /// См. https://core.telegram.org/api/errors для полного списка кодов ошибок.
    ///
    /// **TODO (post-MVP):** Circuit breaker для предотвращения retry loops при критичных ошибках.
    /// Ждёт ответ от TDLib через background loop (БЕЗ прямого вызова receive()).
    ///
    /// **АРХИТЕКТУРНОЕ РЕШЕНИЕ:**
    /// Вместо polling через `receive()` (race condition!), регистрируем continuation
    /// в `responseWaiters`. Background loop вызовет continuation когда получит нужный @type.
    ///
    /// См. `.claude/ARCHITECTURE.md`: Error Handling Strategy
    ///
    /// - Parameters:
    ///   - ofType: Тип ожидаемого ответа
    ///   - expectedType: Ожидаемое значение поля "@type" в JSON ответе TDLib
    /// - Returns: Ответ указанного типа
    /// - Throws: `TDLibErrorResponse` если TDLib вернул ошибку
    private func waitForResponse<T: TDLibResponse>(ofType: T.Type, expectedType: String) async throws -> T {
        appLogger.debug("waitForResponse: started waiting for \(T.self) (@type='\(expectedType)')")

        // Регистрируем continuation в responseWaiters (NSLock внутри, безопасно)
        let rawResponse: [String: Any] = try await withCheckedThrowingContinuation { continuation in
            self.responseWaiters.addWaiter(for: expectedType, continuation: continuation)
        }

        appLogger.debug("waitForResponse: received response for @type='\(expectedType)'")

        // Проверяем на ошибку
        let update = TDLibUpdate(rawResponse)
        if case .error(let error) = update {
            appLogger.error("TDLib error [\(error.code)]: \(error.message)")
            throw error
        }

        // Декодируем в нужный тип
        do {
            let data = try JSONSerialization.data(withJSONObject: rawResponse)
            let decoder = JSONDecoder.tdlib()
            let response = try decoder.decode(T.self, from: data)
            appLogger.debug("waitForResponse: successfully decoded \(T.self)")
            return response
        } catch {
            appLogger.error("waitForResponse: failed to decode @type='\(expectedType)' as \(T.self): \(error)")
            throw TDLibErrorResponse(code: -1, message: "Failed to decode response: \(error)")
        }
    }
}
