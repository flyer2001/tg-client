import TGClientInterfaces
import Foundation

/// Запрос `sendMessage` для TDLib (минимальный — только текст).
///
/// **TDLib API:** https://core.telegram.org/tdlib/docs/classtd_1_1td__api_1_1send_message.html
///
/// **Формат запроса:**
/// ```json
/// {
///   "@type": "sendMessage",
///   "chat_id": <int>,
///   "input_message_content": {
///     "@type": "inputMessageText",
///     "text": { "@type": "formattedText", "text": "...", "entities": [] }
///   }
/// }
/// ```
///
/// **Возвращает:** preliminary `Message` объект сразу. Полная гарантия доставки приходит
/// позже через update `messageSendSucceeded`/`messageSendFailed` — для MVP мы их не ждём.
public struct SendMessageRequest: TDLibRequest {
    public let type = "sendMessage"
    public let chatId: Int64
    public let inputMessageContent: InputMessageText

    enum CodingKeys: String, CodingKey {
        case type = "@type"
        case chatId
        case inputMessageContent
    }

    public init(chatId: Int64, text: String) {
        self.chatId = chatId
        self.inputMessageContent = InputMessageText(text: FormattedText(text: text, entities: []))
    }
}

/// Минимальный `inputMessageText` (только текст, без link preview опций).
public struct InputMessageText: Encodable, Sendable {
    public let type = "inputMessageText"
    public let text: FormattedText

    enum CodingKeys: String, CodingKey {
        case type = "@type"
        case text
    }

    public init(text: FormattedText) {
        self.text = text
    }
}
