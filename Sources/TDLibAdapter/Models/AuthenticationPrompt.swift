import Foundation

/// Тип запроса данных для авторизации в Telegram.
public enum AuthenticationPrompt {
    /// Запрос номера телефона
    case phoneNumber
    /// Запрос кода подтверждения из SMS/Telegram
    case verificationCode
    /// Запрос пароля двухфакторной аутентификации (2FA)
    case twoFactorPassword
}
