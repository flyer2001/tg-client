import Foundation

/// Модель сообщения из источника (канал, группа, личный чат).
///
/// Используется в DigestCore для формирования AI-дайджеста.
public struct SourceMessage: Sendable, Codable, Equatable {
    /// ID чата (канала/группы).
    public let chatId: Int64

    /// ID сообщения.
    public let messageId: Int64

    /// Текстовое содержимое сообщения.
    public let content: String

    /// Название канала/группы.
    public let channelTitle: String

    /// Ссылка на сообщение (если доступна).
    ///
    /// Формат для публичных каналов: `https://t.me/{username}/{messageId}`
    ///
    /// Для приватных каналов: `nil`
    public let link: String?

    public init(
        chatId: Int64,
        messageId: Int64,
        content: String,
        channelTitle: String,
        link: String?
    ) {
        self.chatId = chatId
        self.messageId = messageId
        self.content = content
        self.channelTitle = channelTitle
        self.link = link
    }
}
