import Foundation

/// Ответ TDLib с информацией об ошибке.
///
/// См. https://core.telegram.org/tdlib/docs/classtd_1_1td__api_1_1error.html
public struct TDLibError: TDLibResponse, Error, Sendable {
    public let type = "error"

    /// Код ошибки
    public let code: Int

    /// Описание ошибки
    public let message: String

    enum CodingKeys: String, CodingKey {
        case code
        case message
    }
}
