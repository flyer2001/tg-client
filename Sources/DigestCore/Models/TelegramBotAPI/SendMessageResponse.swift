import Foundation

/// Response от Telegram Bot API (sendMessage).
///
/// **Документация:** https://core.telegram.org/bots/api#making-requests
public struct SendMessageResponse: Codable, Sendable {
    /// Успешность запроса.
    public let ok: Bool

    /// Результат (сообщение) если успешно.
    public let result: Message?

    /// Код ошибки если `ok == false`.
    public let errorCode: Int?

    /// Описание ошибки если `ok == false`.
    public let description: String?

    public init(ok: Bool, result: Message? = nil, errorCode: Int? = nil, description: String? = nil) {
        self.ok = ok
        self.result = result
        self.errorCode = errorCode
        self.description = description
    }
}

/// Сообщение отправленное ботом.
///
/// **Документация:** https://core.telegram.org/bots/api#message
public struct Message: Codable, Sendable {
    /// ID сообщения.
    public let messageId: Int

    /// Отправитель (бот).
    public let from: User

    /// Чат куда отправлено.
    public let chat: Chat

    /// Timestamp (Unix time).
    public let date: Int

    /// Текст сообщения.
    public let text: String?

    public init(messageId: Int, from: User, chat: Chat, date: Int, text: String?) {
        self.messageId = messageId
        self.from = from
        self.chat = chat
        self.date = date
        self.text = text
    }
}

/// Пользователь или бот.
///
/// **Документация:** https://core.telegram.org/bots/api#user
public struct User: Codable, Sendable {
    /// ID пользователя/бота.
    public let id: Int64

    /// Является ли ботом.
    public let isBot: Bool

    /// Имя.
    public let firstName: String

    /// Username (опционально).
    public let username: String?

    public init(id: Int64, isBot: Bool, firstName: String, username: String?) {
        self.id = id
        self.isBot = isBot
        self.firstName = firstName
        self.username = username
    }
}

/// Чат (private, group, channel).
///
/// **Документация:** https://core.telegram.org/bots/api#chat
public struct Chat: Codable, Sendable {
    /// ID чата.
    public let id: Int64

    /// Имя (для private chat).
    public let firstName: String?

    /// Фамилия (для private chat).
    public let lastName: String?

    /// Username чата.
    public let username: String?

    /// Тип чата: "private", "group", "supergroup", "channel".
    public let type: String

    public init(id: Int64, firstName: String?, lastName: String?, username: String?, type: String) {
        self.id = id
        self.firstName = firstName
        self.lastName = lastName
        self.username = username
        self.type = type
    }
}
