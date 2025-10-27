import Foundation

/// Энкодер для сериализации TDLibRequest в JSON формат TDLib.
///
/// TDLib JSON API использует snake_case для имен полей согласно официальной документации:
/// - td_json_client.h: "JSON objects with the same keys as the API object field names"
/// - Официальный пример: https://github.com/tdlib/td/blob/36b05e9/example/python/tdjson_example.py
///
/// Маппинг camelCase → snake_case выполняется через явные CodingKeys в каждой модели.
public struct TDLibRequestEncoder {
    private let jsonEncoder: JSONEncoder

    public init() {
        self.jsonEncoder = JSONEncoder()
    }

    /// Кодирует TDLibRequest в JSON Data.
    ///
    /// - Parameter request: Запрос для кодирования
    /// - Returns: JSON Data для отправки в TDLib
    /// - Throws: EncodingError если кодирование не удалось
    public func encode(_ request: TDLibRequest) throws -> Data {
        return try jsonEncoder.encode(request)
    }
}
