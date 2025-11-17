import Foundation

/// Ответ TDLib с списком сообщений (из getChatHistory).
///
/// **TDLib API:** https://core.telegram.org/tdlib/docs/classtd_1_1td__api_1_1messages.html
public struct MessagesResponse: TDLibResponse, Sendable, Equatable {
    public let type = "messages"

    /// Приблизительное общее количество найденных сообщений.
    public let totalCount: Int32

    /// Список сообщений.
    public let messages: [Message]

    enum CodingKeys: String, CodingKey {
        case totalCount
        case messages
    }

    #if DEBUG
    /// Инициализатор для тестов (создание mock-данных).
    public init(totalCount: Int32, messages: [Message]) {
        self.totalCount = totalCount
        self.messages = messages
    }
    #endif
}
