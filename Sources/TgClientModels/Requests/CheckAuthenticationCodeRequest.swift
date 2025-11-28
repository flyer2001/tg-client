import TGClientInterfaces
import Foundation

public struct CheckAuthenticationCodeRequest: TDLibRequest {
    public let type = "checkAuthenticationCode"
    public let code: String

    enum CodingKeys: String, CodingKey {
        case type = "@type"
        case code
    }

    public init(code: String) {
        self.code = code
    }
}
