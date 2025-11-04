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
/// **Docs:** https://core.telegram.org/tdlib/docs/
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
    /// **Docs:** https://core.telegram.org/tdlib/docs/classtd_1_1td__api_1_1set_authentication_phone_number.html
    func setAuthenticationPhoneNumber(_ phoneNumber: String) async throws -> AuthorizationStateUpdate

    /// Отправляет код подтверждения из SMS/Telegram.
    ///
    /// **TDLib method:** `checkAuthenticationCode`
    ///
    /// - Parameter code: Код подтверждения (обычно 5 цифр)
    /// - Returns: Обновление состояния авторизации (`authorizationStateReady` или `authorizationStateWaitPassword` если включена 2FA)
    /// - Throws: `TDLibError` если код неверный или истёк
    ///
    /// **Docs:** https://core.telegram.org/tdlib/docs/classtd_1_1td__api_1_1check_authentication_code.html
    func checkAuthenticationCode(_ code: String) async throws -> AuthorizationStateUpdate

    /// Отправляет пароль двухфакторной аутентификации (2FA).
    ///
    /// **TDLib method:** `checkAuthenticationPassword`
    ///
    /// - Parameter password: Пароль 2FA
    /// - Returns: Обновление состояния авторизации (обычно `authorizationStateReady`)
    /// - Throws: `TDLibError` если пароль неверный
    ///
    /// **Docs:** https://core.telegram.org/tdlib/docs/classtd_1_1td__api_1_1check_authentication_password.html
    func checkAuthenticationPassword(_ password: String) async throws -> AuthorizationStateUpdate

    // MARK: - User Methods

    /// Получает информацию о текущем авторизованном пользователе.
    ///
    /// **TDLib method:** `getMe`
    ///
    /// - Returns: Информация о пользователе
    /// - Throws: `TDLibError` если пользователь не авторизован или произошла ошибка
    ///
    /// **Docs:** https://core.telegram.org/tdlib/docs/classtd_1_1td__api_1_1get_me.html
    func getMe() async throws -> User
}
