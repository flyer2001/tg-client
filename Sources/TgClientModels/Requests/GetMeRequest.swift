import TGClientInterfaces
import Foundation

public struct GetMeRequest: TDLibRequest {
    public let type = "getMe"

    enum CodingKeys: String, CodingKey {
        case type = "@type"
    }

    public init() {}
}
