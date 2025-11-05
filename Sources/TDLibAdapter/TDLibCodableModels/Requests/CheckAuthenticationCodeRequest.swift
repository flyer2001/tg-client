import Foundation

/// Запрос для проверки кода подтверждения.
///
/// См. https://core.telegram.org/tdlib/.claude/classtd_1_1td__api_1_1check_authentication_code.html
public struct CheckAuthenticationCodeRequest: TDLibRequest {
    public let type = "checkAuthenticationCode"

    /// Код подтверждения из SMS или Telegram
    public let code: String

    enum CodingKeys: String, CodingKey {
        case type = "@type"
        case code
    }

    public init(code: String) {
        self.code = code
    }
}
