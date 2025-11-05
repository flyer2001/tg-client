import Foundation

/// Запрос текущего состояния авторизации.
///
/// См. https://core.telegram.org/tdlib/.claude/classtd_1_1td__api_1_1get_authorization_state.html
public struct GetAuthorizationStateRequest: TDLibRequest {
    public let type = "getAuthorizationState"

    enum CodingKeys: String, CodingKey {
        case type = "@type"
    }

    public init() {}
}
