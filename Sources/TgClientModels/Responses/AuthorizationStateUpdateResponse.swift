import TGClientInterfaces
import Foundation

public struct AuthorizationStateUpdateResponse: TDLibResponse, Sendable {
    public let type = "updateAuthorizationState"
    public let authorizationState: AuthorizationStateInfo

    enum CodingKeys: String, CodingKey {
        case type = "@type"
        case authorizationState
    }

    #if DEBUG
    public init(authorizationState: AuthorizationStateInfo) {
        self.authorizationState = authorizationState
    }

    /// Helper для тестов: AuthorizationState "waitCode"
    public static var waitCode: AuthorizationStateUpdateResponse {
        AuthorizationStateUpdateResponse(
            authorizationState: AuthorizationStateInfo(type: "authorizationStateWaitCode")
        )
    }

    /// Helper для тестов: AuthorizationState "waitPassword"
    public static var waitPassword: AuthorizationStateUpdateResponse {
        AuthorizationStateUpdateResponse(
            authorizationState: AuthorizationStateInfo(type: "authorizationStateWaitPassword")
        )
    }

    /// Helper для тестов: AuthorizationState "ready"
    public static var ready: AuthorizationStateUpdateResponse {
        AuthorizationStateUpdateResponse(
            authorizationState: AuthorizationStateInfo(type: "authorizationStateReady")
        )
    }
    #endif
}

public struct AuthorizationStateInfo: Codable, Sendable {
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
