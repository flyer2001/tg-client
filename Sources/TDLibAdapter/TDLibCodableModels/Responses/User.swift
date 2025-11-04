import Foundation

/// Модель пользователя Telegram.
///
/// **TDLib API:** https://core.telegram.org/tdlib/docs/classtd_1_1td__api_1_1user.html
public struct User: TDLibResponse, Sendable {
    public let type = "user"

    /// Уникальный идентификатор пользователя
    public let id: Int64

    /// Имя пользователя
    public let firstName: String

    /// Фамилия пользователя
    public let lastName: String

    /// Username пользователя (без @)
    public let username: String?

    enum CodingKeys: String, CodingKey {
        case id
        case firstName = "first_name"
        case lastName = "last_name"
        case username
    }

    /// Инициализатор для создания пользователя программно (например, в тестах).
    ///
    /// - Parameters:
    ///   - id: Уникальный идентификатор
    ///   - firstName: Имя
    ///   - lastName: Фамилия
    ///   - username: Username (опционально)
    public init(id: Int64, firstName: String, lastName: String, username: String? = nil) {
        self.id = id
        self.firstName = firstName
        self.lastName = lastName
        self.username = username
    }
}
