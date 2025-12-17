import Foundation

/// Request для отправки сообщения через Telegram Bot API.
///
/// **Документация:** https://core.telegram.org/bots/api#sendmessage
public struct SendMessageRequest: Codable, Sendable {
    /// ID чата (пользователь или группа).
    public let chatId: Int64

    /// Текст сообщения (plain text, ≤4096 chars).
    public let text: String

    public init(chatId: Int64, text: String) {
        self.chatId = chatId
        self.text = text
    }
}
