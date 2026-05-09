import TGClientInterfaces
import Foundation

/// Содержимое сообщения (контент).
///
/// **MVP:** Поддерживаем только текстовые сообщения, остальные типы = unsupported.
///
/// **TDLib API:** https://core.telegram.org/tdlib/docs/classtd_1_1td__api_1_1_message_content.html
public enum MessageContent: Sendable, Codable, Equatable {
    /// Текстовое сообщение.
    case text(FormattedText)

    /// Неподдерживаемый тип контента (для MVP: фото, видео, стикеры и т.д.).
    case unsupported

    private enum CodingKeys: String, CodingKey {
        case type = "@type"
    }

    private enum ContentType: String, Codable {
        case messageText = "messageText"
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(String.self, forKey: .type)

        switch type {
        case "messageText":
            // text-сообщение: контент в поле "text"
            let textContainer = try decoder.container(keyedBy: TextKeys.self)
            let formattedText = try textContainer.decode(FormattedText.self, forKey: .text)
            self = .text(formattedText)

        case "messagePhoto",
             "messageVideo",
             "messageDocument",
             "messageAnimation",
             "messageAudio",
             "messageVoiceNote":
            // Медиа с возможной подписью — достаём caption если есть и не пустая
            let captionContainer = try decoder.container(keyedBy: CaptionKeys.self)
            if let caption = try captionContainer.decodeIfPresent(FormattedText.self, forKey: .caption),
               !caption.text.isEmpty {
                self = .text(caption)
            } else {
                self = .unsupported
            }

        default:
            // messageSticker, messageVideoNote, messagePoll, messageLocation и т.д. — без текста
            self = .unsupported
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        switch self {
        case .text(let formattedText):
            try container.encode("messageText", forKey: .type)
            var textContainer = encoder.container(keyedBy: TextKeys.self)
            try textContainer.encode(formattedText, forKey: .text)
        case .unsupported:
            try container.encode("messageUnsupported", forKey: .type)
        }
    }

    private enum TextKeys: String, CodingKey {
        case text
    }

    private enum CaptionKeys: String, CodingKey {
        case caption
    }
}
