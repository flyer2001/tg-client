import TGClientInterfaces
import Foundation
import FoundationExtensions

/// Супергруппа — из всех полей нужны `is_forum` и `is_channel`.
///
/// **TDLib API:** https://core.telegram.org/tdlib/docs/classtd_1_1td__api_1_1supergroup.html
public struct SupergroupResponse: TDLibResponse, Sendable, Equatable {
    public let type = "supergroup"
    public let id: Int64
    public let isChannel: Bool
    public let isForum: Bool

    enum CodingKeys: String, CodingKey {
        case type = "@type"
        case id, isChannel, isForum
    }

    /// Bool через `decodeBool`: TDLibClient перегоняет ответ через JSONSerialization, на Linux true/false → 1/0.
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(Int64.self, forKey: .id)
        isChannel = try c.decodeBool(forKey: .isChannel)
        isForum = try c.decodeBool(forKey: .isForum)
    }

    #if DEBUG
    public init(id: Int64, isChannel: Bool, isForum: Bool) {
        self.id = id
        self.isChannel = isChannel
        self.isForum = isForum
    }
    #endif
}
