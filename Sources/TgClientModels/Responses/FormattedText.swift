import TGClientInterfaces
import Foundation

/// Formatted text (с поддержкой entities для форматирования).
///
/// **TDLib API:** https://core.telegram.org/tdlib/docs/classtd_1_1td__api_1_1formatted_text.html
public struct FormattedText: Sendable, Codable, Equatable {
    /// Текстовое содержимое.
    public let text: String

    /// Форматирование текста (жирный, курсив, ссылки и т.д.).
    ///
    /// **MVP:** Игнорируем entities, используем только plain text.
    public let entities: [TextEntity]?

    /// Инициализатор для тестов и production-конструирования (например, sendMessage).
    public init(text: String, entities: [TextEntity]?) {
        self.text = text
        self.entities = entities
    }
}

/// Text entity (форматирование участка текста).
///
/// **MVP:** Заглушка для совместимости, не используется.
///
/// **TDLib API:** https://core.telegram.org/tdlib/docs/classtd_1_1td__api_1_1text_entity.html
public struct TextEntity: Sendable, Codable, Equatable {
    // TODO Post-MVP: Реализовать поля (offset, length, type)
}
