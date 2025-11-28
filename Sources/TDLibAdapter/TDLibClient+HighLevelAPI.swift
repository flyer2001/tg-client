import TGClientInterfaces
import TgClientModels
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
        let extra = send(GetMeRequest())
        return try await waitForResponse(forExtra: extra, ofType: UserResponse.self)
    }

    // MARK: - Chat Methods

    public func getChats(chatList: ChatList, limit: Int) async throws -> ChatsResponse {
        let extra = send(GetChatsRequest(chatList: chatList, limit: limit))
        return try await waitForResponse(forExtra: extra, ofType: ChatsResponse.self)
    }

    public func loadChats(chatList: ChatList, limit: Int) async throws -> OkResponse {
        appLogger.debug("loadChats: sending request (chatList: \(chatList), limit: \(limit))")
        let extra = send(LoadChatsRequest(chatList: chatList, limit: limit))
        appLogger.debug("loadChats: request sent (@extra=\(extra)), waiting for OkResponse...")
        let response = try await waitForResponse(forExtra: extra, ofType: OkResponse.self)
        appLogger.debug("loadChats: received OkResponse")
        return response
    }

    public func getChat(chatId: Int64) async throws -> ChatResponse {
        let extra = send(GetChatRequest(chatId: chatId))
        return try await waitForResponse(forExtra: extra, ofType: ChatResponse.self)
    }

    public func getChatHistory(chatId: Int64, fromMessageId: Int64, offset: Int32, limit: Int32) async throws -> MessagesResponse {
        let extra = send(GetChatHistoryRequest(chatId: chatId, fromMessageId: fromMessageId, offset: offset, limit: limit, onlyLocal: false))
        return try await waitForResponse(forExtra: extra, ofType: MessagesResponse.self)
    }

    // MARK: - Updates

    /// AsyncStream для получения updates от TDLib.
    ///
    /// **ВАЖНО:**
    /// - Background loop запускается в `start()` и инициализирует stream
    /// - Поддерживается только ОДИН подписчик (для MVP)
    ///
    /// **Technical Debt:**
    /// - ⚠️ ПРОБЛЕМА: AsyncStream можно consume только один раз
    /// - ✅ РЕШЕНИЕ (когда понадобится 2+ подписчиков): broadcast через массив continuation'ов
    /// - 📝 См. TASKS.md → Technical Debt → "TDLibClient.updates broadcast"
    public var updates: AsyncStream<Update> {
        guard let stream = updatesStream else {
            fatalError("updates stream not initialized. Call startUpdatesLoop() first.")
        }
        return stream
    }

    // MARK: - Helper Methods

    /// Ожидает следующего обновления состояния авторизации от TDLib.
    ///
    /// **АРХИТЕКТУРНОЕ РЕШЕНИЕ:**
    /// Теперь использует единый background loop через `waitForResponse(forType:)` вместо прямого `receive()`.
    /// Это устраняет race condition между authorization loop и background updates loop.
    ///
    /// - Returns: Обновление состояния авторизации
    /// - Throws: `TDLibError` если TDLib вернул ошибку
    func waitForAuthorizationUpdate() async throws -> AuthorizationStateUpdateResponse {
        // Ждём updateAuthorizationState через единый background loop (БЕЗ @extra)
        return try await waitForResponse(forType: "updateAuthorizationState", ofType: AuthorizationStateUpdateResponse.self)
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
    /// в `responseWaiters`. Background loop вызовет continuation когда получит @extra.
    ///
    /// См. `.claude/ARCHITECTURE.md`: Error Handling Strategy
    ///
    /// - Parameters:
    ///   - extra: Уникальный @extra ID запроса (сгенерированный через generateExtra())
    ///   - ofType: Тип ожидаемого ответа
    /// - Returns: Ответ указанного типа
    /// - Throws: `TDLibErrorResponse` если TDLib вернул ошибку
    private func waitForResponse<T: TDLibResponse>(forExtra extra: String, ofType: T.Type) async throws -> T {
        appLogger.debug("waitForResponse: waiting for @extra='\(extra)' (\(T.self))")

        // Регистрируем continuation в responseWaiters по @extra
        let tdlibJSON: TDLibJSON = try await withCheckedThrowingContinuation { continuation in
            Task {
                await self.responseWaiters.addWaiter(forExtra: extra, continuation: continuation)
            }
        }

        appLogger.debug("waitForResponse: received response for @extra='\(extra)'")

        // Проверяем на ошибку
        let update = TDLibUpdate(tdlibJSON.data)
        if case .error(let error) = update {
            appLogger.error("TDLib error [\(error.code)]: \(error.message)")
            throw error
        }

        // Декодируем в нужный тип
        do {
            let data = try JSONSerialization.data(withJSONObject: tdlibJSON.data)
            let decoder = JSONDecoder.tdlib()
            let response = try decoder.decode(T.self, from: data)
            appLogger.debug("waitForResponse: successfully decoded \(T.self)")
            return response
        } catch {
            appLogger.error("waitForResponse: failed to decode response for @extra='\(extra)' as \(T.self): \(error)")
            throw TDLibClientError.decodeFailed(expectedType: "\(T.self)", underlyingError: error)
        }
    }

    /// Ожидает unsolicited update определенного типа (БЕЗ @extra).
    ///
    /// **Use case:** Authorization flow ждёт `updateAuthorizationState` от TDLib
    /// (TDLib отправляет их сам, не в ответ на request).
    ///
    /// - Parameters:
    ///   - type: Тип update (@type field, например "updateAuthorizationState")
    ///   - ofType: Тип ожидаемого ответа
    /// - Returns: Update указанного типа
    /// - Throws: `TDLibErrorResponse` если TDLib вернул ошибку
    private func waitForResponse<T: TDLibResponse>(forType type: String, ofType: T.Type) async throws -> T {
        appLogger.debug("waitForResponse: waiting for @type='\(type)' (\(T.self))")

        // Регистрируем continuation в responseWaiters по типу
        let tdlibJSON: TDLibJSON = try await withCheckedThrowingContinuation { continuation in
            Task {
                await self.responseWaiters.addWaiter(forType: type, continuation: continuation)
            }
        }

        appLogger.debug("waitForResponse: received update for @type='\(type)'")

        // Проверяем на ошибку
        let update = TDLibUpdate(tdlibJSON.data)
        if case .error(let error) = update {
            appLogger.error("TDLib error [\(error.code)]: \(error.message)")
            throw error
        }

        // Декодируем в нужный тип
        do {
            let data = try JSONSerialization.data(withJSONObject: tdlibJSON.data)
            let decoder = JSONDecoder.tdlib()
            let response = try decoder.decode(T.self, from: data)
            appLogger.debug("waitForResponse: successfully decoded \(T.self)")
            return response
        } catch {
            appLogger.error("waitForResponse: failed to decode update @type='\(type)' as \(T.self): \(error)")
            throw TDLibClientError.decodeFailed(expectedType: "\(T.self)", underlyingError: error)
        }
    }
}
