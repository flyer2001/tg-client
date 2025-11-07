import Foundation

public struct AuthorizationStateUpdateResponse: TDLibResponse, Sendable {
    public let type = "updateAuthorizationState"
    public let authorizationState: AuthorizationStateInfo

    enum CodingKeys: String, CodingKey {
        case authorizationState = "authorization_state"
    }

    #if DEBUG
    public init(authorizationState: AuthorizationStateInfo) {
        self.authorizationState = authorizationState
    }
    #endif
}

public struct AuthorizationStateInfo: Decodable, Sendable {
    public let type: String

    enum CodingKeys: String, CodingKey {
        case type = "@type"
    }

    #if DEBUG
    public init(type: String) {
        self.type = type
    }
    #endif
}
