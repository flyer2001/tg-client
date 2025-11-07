import Foundation

public struct CheckAuthenticationPasswordRequest: TDLibRequest {
    public let type = "checkAuthenticationPassword"
    public let password: String

    enum CodingKeys: String, CodingKey {
        case type = "@type"
        case password
    }

    public init(password: String) {
        self.password = password
    }
}
