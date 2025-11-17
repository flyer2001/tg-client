import Foundation

/// Запрос истории сообщений чата.
///
/// **TDLib API:** https://core.telegram.org/tdlib/docs/classtd_1_1td__api_1_1get_chat_history.html
public struct GetChatHistoryRequest: TDLibRequest, Sendable, Equatable {
    public let type = "getChatHistory"

    /// ID чата.
    public let chatId: Int64

    /// ID сообщения, с которого начинать загрузку (0 = с последнего сообщения).
    public let fromMessageId: Int64

    /// Смещение (0 для точного совпадения, отрицательное для дополнительных сообщений).
    public let offset: Int32

    /// Максимальное количество сообщений (max 100).
    public let limit: Int32

    /// Получать только локально доступные сообщения (без сетевых запросов).
    public let onlyLocal: Bool

    enum CodingKeys: String, CodingKey {
        case type = "@type"
        case chatId
        case fromMessageId
        case offset
        case limit
        case onlyLocal
    }

    public init(
        chatId: Int64,
        fromMessageId: Int64,
        offset: Int32,
        limit: Int32,
        onlyLocal: Bool
    ) {
        self.chatId = chatId
        self.fromMessageId = fromMessageId
        self.offset = offset
        self.limit = limit
        self.onlyLocal = onlyLocal
    }
}
