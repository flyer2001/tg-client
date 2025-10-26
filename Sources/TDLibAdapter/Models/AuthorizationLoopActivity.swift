import Foundation

/// Последняя активность в цикле обработки авторизации.
///
/// Используется для диагностики при зависании или превышении лимитов авторизации.
/// Позволяет точно определить на каком этапе произошла проблема.
enum AuthorizationLoopActivity {
    /// TDLib не прислал обновлений (receive вернул nil)
    case emptyReceive

    /// Получен объект без поля @type (некорректные данные от TDLib)
    case missingType

    /// TDLib прислал ошибку
    case tdlibError(code: Int, message: String)

    /// Получено событие не связанное с авторизацией
    case nonAuthorizationEvent(type: String)

    /// Обработано состояние авторизации
    case authorizationState(AuthorizationState, originalType: String?)
}

extension AuthorizationLoopActivity: CustomStringConvertible {
    var description: String {
        switch self {
        case .emptyReceive:
            return "empty receive (TDLib не ответил)"
        case .missingType:
            return "missing @type field"
        case .tdlibError(let code, let message):
            return "TDLib error [\(code)]: \(message)"
        case .nonAuthorizationEvent(let type):
            return "non-auth event: \(type)"
        case .authorizationState(let state, let originalType):
            if state == .unknown, let originalType = originalType {
                return "auth state: unknown(\(originalType))"
            }
            return "auth state: \(state.rawValue)"
        }
    }
}
