import Foundation
import FoundationExtensions
import TGClientInterfaces

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
        self.jsonEncoder = JSONEncoder.tdlib()
    }

    /// Кодирует TDLibRequest в JSON Data.
    ///
    /// - Parameter request: Запрос для кодирования
    /// - Returns: JSON Data для отправки в TDLib
    /// - Throws: EncodingError если кодирование не удалось
    public func encode(_ request: TDLibRequest) throws -> Data {
        return try jsonEncoder.encode(request)
    }

    /// Кодирует TDLibRequest в JSON Data с добавлением @extra поля.
    ///
    /// - Parameters:
    ///   - request: Запрос для кодирования
    ///   - extra: Уникальный @extra ID для Request-Response matching
    /// - Returns: JSON Data с @extra полем для отправки в TDLib
    /// - Throws: EncodingError если кодирование не удалось
    public func encode(_ request: TDLibRequest, withExtra extra: String) throws -> Data {
        let data = try jsonEncoder.encode(request)
        guard var dict = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw EncodingError.invalidValue(
                request,
                EncodingError.Context(
                    codingPath: [],
                    debugDescription: "Failed to parse encoded request as JSON Dictionary"
                )
            )
        }
        dict["@extra"] = extra
        return try JSONSerialization.data(withJSONObject: dict)
    }
}
