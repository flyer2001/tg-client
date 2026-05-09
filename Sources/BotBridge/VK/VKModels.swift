import Foundation

// MARK: - Incoming (callback)

/// Событие от VK Callback API.
///
/// Минимальный набор полей: верхнеуровневый `type` определяет, как декодировать `object`.
public struct VKCallbackEvent: Decodable, Sendable {
    public let type: String
    public let groupId: Int?
    public let secret: String?
    public let object: VKObject?

    enum CodingKeys: String, CodingKey {
        case type
        case groupId = "group_id"
        case secret
        case object
    }
}

/// Объект внутри `message_new` события.
public struct VKObject: Decodable, Sendable {
    public let message: VKMessage?
}

/// Сообщение из VK (минимум полей которыми оперируем).
public struct VKMessage: Decodable, Sendable {
    public let id: Int64
    public let date: Int64
    public let peerId: Int64
    public let fromId: Int64
    public let text: String

    enum CodingKeys: String, CodingKey {
        case id, date, text
        case peerId = "peer_id"
        case fromId = "from_id"
    }
}

// MARK: - Outgoing (api.vk.com response)

/// Ответ VK API на любой method вызов.
///
/// Либо `response`, либо `error` — взаимоисключающие.
public struct VKAPIResponse<T: Decodable & Sendable>: Decodable, Sendable {
    public let response: T?
    public let error: VKAPIError?
}

/// Ошибка VK API.
///
/// Полный список кодов: https://dev.vk.com/ru/reference/errors
public struct VKAPIError: Decodable, Sendable, CustomStringConvertible {
    public let errorCode: Int
    public let errorMsg: String

    enum CodingKeys: String, CodingKey {
        case errorCode = "error_code"
        case errorMsg = "error_msg"
    }

    public var description: String {
        return "VK API error \(errorCode): \(errorMsg)"
    }
}

/// Результат `messages.send` — ID отправленного сообщения.
public typealias VKMessageSendResult = Int64
