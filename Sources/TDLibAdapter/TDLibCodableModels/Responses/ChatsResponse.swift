import Foundation

/// Модель ответа TDLib с списком ID чатов.
///
/// **TDLib API:** https://core.telegram.org/tdlib/docs/classtd_1_1td__api_1_1chats.html
public struct ChatsResponse: TDLibResponse, Sendable, Equatable {
    public let type = "chats"

    /// Список ID чатов
    public let chatIds: [Int64]

    enum CodingKeys: String, CodingKey {
        case chatIds
    }

    #if DEBUG
    /// Инициализатор для создания ответа программно (например, в тестах).
    ///
    /// - Parameter chatIds: Список ID чатов
    public init(chatIds: [Int64]) {
        self.chatIds = chatIds
    }
    #endif
}
