import TGClientInterfaces
import Foundation

/// Запрос `searchPublicChat` — ищет чат по публичному username.
///
/// Возвращает `ChatResponse`. Если username не найден — TDLib вернёт ошибку 404.
///
/// **TDLib API:** https://core.telegram.org/tdlib/docs/classtd_1_1td__api_1_1search_public_chat.html
public struct SearchPublicChatRequest: TDLibRequest {
    public let type = "searchPublicChat"
    public let username: String

    enum CodingKeys: String, CodingKey {
        case type = "@type"
        case username
    }

    public init(username: String) {
        self.username = username
    }
}
