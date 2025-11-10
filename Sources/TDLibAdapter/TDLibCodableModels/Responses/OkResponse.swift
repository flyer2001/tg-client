import Foundation

/// Универсальный успешный ответ TDLib без дополнительных данных.
///
/// **TDLib API:** https://core.telegram.org/tdlib/docs/classtd_1_1td__api_1_1ok.html
///
/// Используется методами которые не возвращают конкретных данных.
public struct OkResponse: TDLibResponse, Sendable {
    public let type = "ok"

    enum CodingKeys: String, CodingKey {
        case type = "@type"
    }
}
