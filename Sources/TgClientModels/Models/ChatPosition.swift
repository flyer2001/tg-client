import Foundation
import FoundationExtensions

/// Позиция чата в списке TDLib.
public struct ChatPosition: Sendable, Equatable, Hashable, Codable {
    public let list: ChatList
    public let order: Int64
    public let isPinned: Bool

    public init(list: ChatList, order: Int64, isPinned: Bool) {
        self.list = list
        self.order = order
        self.isPinned = isPinned
    }

    enum CodingKeys: String, CodingKey {
        case list
        case order
        case isPinned  // convertFromSnakeCase: is_pinned → isPinned
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        list = try container.decode(ChatList.self, forKey: .list)
        order = try container.decodeInt64(forKey: .order)

        // По спецификации TDLib is_pinned обязательное поле (bool, required).
        // Однако на практике TDLib может не присылать это поле → используем default=false.
        // См. ChatPositionTests: "Edge case: is_pinned отсутствует → default=false"
        isPinned = (try? container.decodeBool(forKey: .isPinned)) ?? false
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(list, forKey: .list)
        try container.encode(String(order), forKey: .order)
        try container.encode(isPinned, forKey: .isPinned)
    }
}
