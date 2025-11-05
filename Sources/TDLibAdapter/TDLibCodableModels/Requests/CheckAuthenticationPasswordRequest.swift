import Foundation

/// Запрос для проверки пароля двухфакторной аутентификации.
///
/// См. https://core.telegram.org/tdlib/.claude/classtd_1_1td__api_1_1check_authentication_password.html
public struct CheckAuthenticationPasswordRequest: TDLibRequest {
    public let type = "checkAuthenticationPassword"

    /// Пароль 2FA
    public let password: String

    enum CodingKeys: String, CodingKey {
        case type = "@type"
        case password
    }

    public init(password: String) {
        self.password = password
    }
}
