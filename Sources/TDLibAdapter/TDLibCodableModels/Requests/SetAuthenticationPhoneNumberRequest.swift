import Foundation

/// Запрос для установки номера телефона при авторизации.
///
/// См. https://core.telegram.org/tdlib/docs/classtd_1_1td__api_1_1set_authentication_phone_number.html
public struct SetAuthenticationPhoneNumberRequest: TDLibRequest {
    public let type = "setAuthenticationPhoneNumber"

    /// Номер телефона в международном формате
    public let phoneNumber: String

    enum CodingKeys: String, CodingKey {
        case type = "@type"
        case phoneNumber = "phone_number"
    }

    public init(phoneNumber: String) {
        self.phoneNumber = phoneNumber
    }
}
