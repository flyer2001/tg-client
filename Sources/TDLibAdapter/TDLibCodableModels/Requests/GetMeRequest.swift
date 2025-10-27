import Foundation

/// Запрос информации о текущем пользователе.
///
/// См. https://core.telegram.org/tdlib/docs/classtd_1_1td__api_1_1get_me.html
public struct GetMeRequest: TDLibRequest {
    public let type = "getMe"

    enum CodingKeys: String, CodingKey {
        case type = "@type"
    }

    public init() {}
}
