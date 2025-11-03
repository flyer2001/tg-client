import Foundation

/// Обновление состояния авторизации от TDLib.
///
/// TDLib присылает это обновление при изменении состояния авторизации.
///
/// См. https://core.telegram.org/tdlib/docs/classtd_1_1td__api_1_1update_authorization_state.html
public struct AuthorizationStateUpdate: TDLibResponse, Sendable {
    public let type = "updateAuthorizationState"

    /// Новое состояние авторизации
    public let authorizationState: AuthorizationStateInfo

    enum CodingKeys: String, CodingKey {
        case authorizationState = "authorization_state"
    }

    /// Инициализатор для создания обновления программно (например, в тестах).
    ///
    /// - Parameter authorizationState: Информация о состоянии авторизации
    public init(authorizationState: AuthorizationStateInfo) {
        self.authorizationState = authorizationState
    }
}

/// Информация о состоянии авторизации.
///
/// Содержит тип состояния и дополнительные данные (если есть).
public struct AuthorizationStateInfo: Decodable, Sendable {
    /// Тип состояния авторизации
    public let type: String

    enum CodingKeys: String, CodingKey {
        case type = "@type"
    }

    /// Инициализатор для создания состояния программно (например, в тестах).
    ///
    /// - Parameter type: Тип состояния (например, "authorizationStateReady")
    public init(type: String) {
        self.type = type
    }
}
