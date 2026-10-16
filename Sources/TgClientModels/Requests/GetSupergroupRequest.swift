import TGClientInterfaces
import Foundation

/// Запрос информации о супергруппе — нужен ради `is_forum` (чат с темами).
///
/// **TDLib API:** https://core.telegram.org/tdlib/docs/classtd_1_1td__api_1_1get_supergroup.html
public struct GetSupergroupRequest: TDLibRequest, Sendable, Equatable {
    public let type = "getSupergroup"
    public let supergroupId: Int64

    enum CodingKeys: String, CodingKey {
        case type = "@type"
        case supergroupId
    }

    public init(supergroupId: Int64) { self.supergroupId = supergroupId }
}
