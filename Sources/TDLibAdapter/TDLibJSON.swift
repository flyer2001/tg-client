import TgClientModels
import Foundation

/// Sendable-safe обёртка над TDLib JSON response.
///
/// **Гарантия безопасности:**
///
/// TDLib возвращает JSON из C API, который содержит ТОЛЬКО JSON-совместимые типы:
/// - `String`, `Int`, `Int32`, `Int64`, `Double`, `Bool` — все `Sendable`
/// - `Array`, `Dictionary` — рекурсивно `Sendable` если элементы `Sendable`
/// - `null` → `NSNull` (`Sendable`)
///
/// **Валидация:**
///
/// Конструктор `init(parsing:)` рекурсивно проверяет ВСЕ значения в словаре.
/// Если встречается non-Sendable тип → бросает `TDLibClientError.nonSendableValue`.
///
/// **Использование:**
///
/// ```swift
/// // В TDLibClient.receive():
/// let rawDict = try JSONSerialization.jsonObject(...) as? [String: Any]
/// let json = try TDLibJSON(parsing: rawDict)  // ✅ Валидация здесь
///
/// // Доступ к данным:
/// let id = json["id"] as? Int64
///
/// // Для JSONDecoder:
/// let data = try JSONSerialization.data(withJSONObject: json.data)
/// let response = try JSONDecoder.tdlib().decode(ChatResponse.self, from: data)
/// ```
///
/// **Thread-safety:**
/// - Структура immutable → unconditionally `Sendable`
/// - Все значения validated как `Sendable` → безопасно передавать между потоками
public struct TDLibJSON: Sendable {

    /// Validated Sendable-safe dictionary.
    ///
    /// Все значения гарантированно `Sendable` (проверено в `init(parsing:)`).
    public let data: [String: any Sendable]

    /// Создаёт TDLibJSON с валидацией всех значений.
    ///
    /// - Parameter dict: Raw dictionary от TDLib (через JSONSerialization)
    /// - Throws: `TDLibClientError.nonSendableValue` если найден non-Sendable тип
    public init(parsing dict: [String: Any]) throws {
        self.data = try Self.validateSendable(dict)
    }

    /// Subscript доступ к значениям (как в обычном Dictionary).
    ///
    /// - Returns: Значение приведённое к `any Sendable`, требует manual cast
    ///
    /// **Пример:**
    /// ```swift
    /// let id = json["id"] as? Int64
    /// let title = json["title"] as? String
    /// ```
    public subscript(key: String) -> (any Sendable)? {
        data[key]
    }

    // MARK: - Private Validation

    /// Рекурсивно валидирует что Dictionary содержит только Sendable типы.
    private static func validateSendable(_ dict: [String: Any]) throws -> [String: any Sendable] {
        var result: [String: any Sendable] = [:]
        for (key, value) in dict {
            result[key] = try validateValue(value)
        }
        return result
    }

    /// Валидирует одно значение (рекурсивно для Array/Dictionary).
    private static func validateValue(_ value: Any) throws -> any Sendable {
        switch value {
        // Primitives (все Sendable)
        case let s as String:
            return s
        case let i as Int:
            return i
        case let i32 as Int32:
            return i32
        case let i64 as Int64:
            return i64
        case let d as Double:
            return d
        case let b as Bool:
            return b
        case is NSNull:
            return NSNull()

        // Collections (рекурсивно)
        case let arr as [Any]:
            return try arr.map { try validateValue($0) }
        case let dict as [String: Any]:
            return try validateSendable(dict)

        // Rejection: non-Sendable типы
        default:
            throw TDLibClientError.nonSendableValue(
                type: String(describing: type(of: value))
            )
        }
    }
}
