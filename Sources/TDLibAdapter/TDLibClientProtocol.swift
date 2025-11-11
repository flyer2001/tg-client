import Foundation

/// Протокол для типобезопасного взаимодействия с TDLib.
///
/// Предоставляет high-level API для работы с TDLib вместо низкоуровневого `send/receive`.
///
/// **Преимущества:**
/// - Типобезопасность (вместо `[String: Any]?`)
/// - Удобство тестирования (легко создать mock)
/// - Явные методы для каждой операции
///
/// **Использование:**
/// ```swift
/// let client: TDLibClientProtocol = TDLibClient(...)
/// let state = try await client.setAuthenticationPhoneNumber("+1234567890")
/// ```
///
/// **Docs:** https://core.telegram.org/tdlib/.claude/
public protocol TDLibClientProtocol: Sendable {

    // MARK: - Authentication Methods

    /// Отправляет номер телефона для авторизации.
    ///
    /// **TDLib method:** `setAuthenticationPhoneNumber`
    ///
    /// - Parameter phoneNumber: Номер телефона в международном формате (например, "+1234567890")
    /// - Returns: Обновление состояния авторизации (обычно `authorizationStateWaitCode`)
    /// - Throws: `TDLibError` если номер невалидный или произошла ошибка
    ///
    /// **Docs:** https://core.telegram.org/tdlib/.claude/classtd_1_1td__api_1_1set_authentication_phone_number.html
    func setAuthenticationPhoneNumber(_ phoneNumber: String) async throws -> AuthorizationStateUpdateResponse

    /// Отправляет код подтверждения из SMS/Telegram.
    ///
    /// **TDLib method:** `checkAuthenticationCode`
    ///
    /// - Parameter code: Код подтверждения (обычно 5 цифр)
    /// - Returns: Обновление состояния авторизации (`authorizationStateReady` или `authorizationStateWaitPassword` если включена 2FA)
    /// - Throws: `TDLibError` если код неверный или истёк
    ///
    /// **Docs:** https://core.telegram.org/tdlib/.claude/classtd_1_1td__api_1_1check_authentication_code.html
    func checkAuthenticationCode(_ code: String) async throws -> AuthorizationStateUpdateResponse

    /// Отправляет пароль двухфакторной аутентификации (2FA).
    ///
    /// **TDLib method:** `checkAuthenticationPassword`
    ///
    /// - Parameter password: Пароль 2FA
    /// - Returns: Обновление состояния авторизации (обычно `authorizationStateReady`)
    /// - Throws: `TDLibError` если пароль неверный
    ///
    /// **Docs:** https://core.telegram.org/tdlib/.claude/classtd_1_1td__api_1_1check_authentication_password.html
    func checkAuthenticationPassword(_ password: String) async throws -> AuthorizationStateUpdateResponse

    // MARK: - User Methods

    /// Получает информацию о текущем авторизованном пользователе.
    ///
    /// **TDLib method:** `getMe`
    ///
    /// - Returns: Информация о пользователе
    /// - Throws: `TDLibError` если пользователь не авторизован или произошла ошибка
    ///
    /// **Docs:** https://core.telegram.org/tdlib/.claude/classtd_1_1td__api_1_1get_me.html
    func getMe() async throws -> UserResponse

    // MARK: - Chat Methods

    /// Получает список чатов из указанного списка (main или archive).
    ///
    /// **TDLib method:** `getChats`
    ///
    /// Возвращает список ID чатов в порядке, определённом TDLib (обычно по времени последнего сообщения).
    /// Для получения полной информации о чате (название, тип, счётчик непрочитанных) используйте `getChat(chatId:)`.
    ///
    /// **Параметры:**
    /// - `chatList`: Тип списка чатов (`.main` для основного списка, `.archive` для архива)
    /// - `limit`: Максимальное количество чатов для получения (обычно 100)
    ///
    /// **Возвращает:** Список ID чатов
    ///
    /// **Выбрасывает:** Ошибку если TDLib недоступен или произошла внутренняя ошибка
    ///
    /// **Пример использования:**
    /// ```swift
    /// let response = try await client.getChats(chatList: .main, limit: 100)
    /// for chatId in response.chatIds {
    ///     let chat = try await client.getChat(chatId: chatId)
    ///     print("Chat: \(chat.title), unread: \(chat.unreadCount)")
    /// }
    /// ```
    ///
    /// **TDLib docs:**
    /// - Method: https://core.telegram.org/tdlib/docs/classtd_1_1td__api_1_1get_chats.html
    /// - Response: https://core.telegram.org/tdlib/docs/classtd_1_1td__api_1_1chats.html
    /// - ChatList: https://core.telegram.org/tdlib/docs/classtd_1_1td__api_1_1chat_list.html
    func getChats(chatList: ChatList, limit: Int) async throws -> ChatsResponse

    /// Загружает чаты в TDLib cache.
    ///
    /// **TDLib docs:** https://core.telegram.org/tdlib/docs/classtd_1_1td__api_1_1load_chats.html
    func loadChats(chatList: ChatList, limit: Int) async throws -> OkResponse

    /// Получает информацию о чате.
    ///
    /// **TDLib docs:** https://core.telegram.org/tdlib/docs/classtd_1_1td__api_1_1get_chat.html
    func getChat(chatId: Int64) async throws -> ChatResponse
}
