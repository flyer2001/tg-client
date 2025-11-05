import Foundation

/// Состояние авторизации в TDLib.
///
/// Соответствует состояниям из TDLib API.
/// См. https://core.telegram.org/tdlib/.claude/classtd_1_1td__api_1_1authorization_state.html
public enum AuthorizationState: String, Sendable, Equatable {
    /// Ожидание параметров TDLib (API ID, API Hash, директории)
    case waitTdlibParameters = "authorizationStateWaitTdlibParameters"
    /// Ожидание ключа шифрования базы данных
    case waitEncryptionKey = "authorizationStateWaitEncryptionKey"
    /// Ожидание номера телефона
    case waitPhoneNumber = "authorizationStateWaitPhoneNumber"
    /// Ожидание кода подтверждения
    case waitVerificationCode = "authorizationStateWaitCode"
    /// Ожидание пароля 2FA
    case waitTwoFactorPassword = "authorizationStateWaitPassword"
    /// Авторизация завершена успешно
    case ready = "authorizationStateReady"
    /// TDLib клиент закрыт
    case closed = "authorizationStateClosed"
    /// Неизвестное состояние
    case unknown = "unknown"

    /// Создаёт состояние из строки типа TDLib.
    public init(fromTDLibType type: String) {
        self = AuthorizationState(rawValue: type) ?? .unknown
    }

    // MARK: - Convenience Aliases

    /// Алиас для `.waitVerificationCode` (для удобства в тестах и API)
    public static var waitCode: AuthorizationState { .waitVerificationCode }

    /// Алиас для `.waitTwoFactorPassword` (для удобства в тестах и API)
    public static var waitPassword: AuthorizationState { .waitTwoFactorPassword }
}
