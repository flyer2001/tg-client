import Foundation

public struct SetAuthenticationPhoneNumberRequest: TDLibRequest {
    public let type = "setAuthenticationPhoneNumber"
    public let phoneNumber: String

    enum CodingKeys: String, CodingKey {
        case type = "@type"
        case phoneNumber = "phone_number"
    }

    public init(phoneNumber: String) {
        self.phoneNumber = phoneNumber
    }
}
