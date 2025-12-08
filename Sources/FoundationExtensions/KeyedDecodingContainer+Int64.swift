import Foundation

extension KeyedDecodingContainer {
    /// Декодирует Int64 из String или Int.
    ///
    /// TDLib (и другие JSON API) присылают большие int64 (> 2^53) как String,
    /// чтобы избежать потери точности в JSON Number (JavaScript ограничение).
    /// Этот метод поддерживает оба варианта для совместимости.
    ///
    /// - Parameter key: Ключ для декодирования
    /// - Returns: Int64 значение
    /// - Throws: DecodingError если значение не может быть преобразовано в Int64
    public func decodeInt64(forKey key: Key) throws -> Int64 {
        // Проверяем что ключ присутствует
        guard contains(key) else {
            throw DecodingError.keyNotFound(
                key,
                DecodingError.Context(
                    codingPath: codingPath,
                    debugDescription: "Key '\(key)' not found"
                )
            )
        }

        // Пробуем String (основной формат TDLib для больших чисел)
        if let stringValue = try? decode(String.self, forKey: key),
           let int64Value = Int64(stringValue) {
            return int64Value
        }

        // Fallback: пробуем Int (маленькие числа или другие API)
        if let intValue = try? decode(Int.self, forKey: key) {
            return Int64(intValue)
        }

        // Fallback: пробуем напрямую Int64
        if let int64Value = try? decode(Int64.self, forKey: key) {
            return int64Value
        }

        // Если ничего не получилось - бросаем ошибку
        throw DecodingError.dataCorruptedError(
            forKey: key,
            in: self,
            debugDescription: "Cannot decode Int64 from key '\(key)' - expected String or Int"
        )
    }

    /// Декодирует Int32 из String или Int.
    ///
    /// Int32 технически влезает в JSON Number (до 2^31 < 2^53),
    /// но TDLib может присылать как String для консистентности API.
    /// Этот метод поддерживает оба варианта для совместимости.
    ///
    /// - Parameter key: Ключ для декодирования
    /// - Returns: Int32 значение
    /// - Throws: DecodingError если значение не может быть преобразовано в Int32
    public func decodeInt32(forKey key: Key) throws -> Int32 {
        // Проверяем что ключ присутствует
        guard contains(key) else {
            throw DecodingError.keyNotFound(
                key,
                DecodingError.Context(
                    codingPath: codingPath,
                    debugDescription: "Key '\(key)' not found"
                )
            )
        }

        // Пробуем String
        if let stringValue = try? decode(String.self, forKey: key),
           let int32Value = Int32(stringValue) {
            return int32Value
        }

        // Fallback: пробуем Int
        if let intValue = try? decode(Int.self, forKey: key),
           let int32Value = Int32(exactly: intValue) {
            return int32Value
        }

        // Fallback: пробуем напрямую Int32
        if let int32Value = try? decode(Int32.self, forKey: key) {
            return int32Value
        }

        // Если ничего не получилось - бросаем ошибку
        throw DecodingError.dataCorruptedError(
            forKey: key,
            in: self,
            debugDescription: "Cannot decode Int32 from key '\(key)' - expected String or Int"
        )
    }

    /// Декодирует Bool из Bool или Int.
    ///
    /// По спецификации TDLib JSON API (td_json_client.h):
    /// "Fields of Bool type are stored as Boolean"
    ///
    /// Однако на практике TDLib может присылать boolean поля как Int (0 = false, 1 = true).
    /// Этот метод поддерживает оба варианта для совместимости с текущей реализацией TDLib.
    ///
    /// - Parameter key: Ключ для декодирования
    /// - Returns: Bool значение
    /// - Throws: DecodingError если значение не может быть преобразовано в Bool
    public func decodeBool(forKey key: Key) throws -> Bool {
        // Проверяем что ключ присутствует
        guard contains(key) else {
            throw DecodingError.keyNotFound(
                key,
                DecodingError.Context(
                    codingPath: codingPath,
                    debugDescription: "Key '\(key)' not found"
                )
            )
        }

        // Пробуем Bool (стандартный JSON / по спецификации TDLib)
        if let boolValue = try? decode(Bool.self, forKey: key) {
            return boolValue
        }

        // Fallback: Int (фактическое поведение TDLib: 0=false, любое != 0 = true)
        if let intValue = try? decode(Int.self, forKey: key) {
            return intValue != 0
        }

        // Если ничего не получилось - бросаем ошибку
        throw DecodingError.dataCorruptedError(
            forKey: key,
            in: self,
            debugDescription: "Cannot decode Bool from key '\(key)' - expected Bool or Int"
        )
    }
}
