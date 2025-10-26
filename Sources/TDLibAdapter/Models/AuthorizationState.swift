import Foundation

/// Состояние авторизации в TDLib.
///
/// Соответствует состояниям из TDLib API.
/// См. https://core.telegram.org/tdlib/docs/classtd_1_1td__api_1_1authorization_state.html
enum AuthorizationState: String {
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
    init(fromTDLibType type: String) {
        self = AuthorizationState(rawValue: type) ?? .unknown
    }
}
