import Foundation
import TGClientInterfaces

/// Ошибки валидации TDLibResponse encoding.
public enum TDLibResponseValidationError: Error, CustomStringConvertible {
    case missingTypeField(responseType: String)
    case typeMismatch(responseType: String, propertyValue: String, encodedValue: String)

    public var description: String {
        switch self {
        case .missingTypeField(let type):
            return """
            ❌ \(type) validation failed!

            Missing '@type' field in encoded JSON.

            FIX: Add 'case type = "@type"' to CodingKeys enum.

            Example:
            enum CodingKeys: String, CodingKey {
                case type = "@type"  // ← Add this
                case id
                case name
            }
            """
        case .typeMismatch(let type, let property, let encoded):
            return """
            ❌ \(type) validation failed!

            Type mismatch:
            - Property: type = "\(property)"
            - Encoded:  @type = "\(encoded)"

            FIX: Ensure property value matches "@type" in JSON.
            """
        }
    }
}

/// Test helper для валидации TDLibResponse encoding.
///
/// **Проблема:**
/// TDLibClient.startUpdatesLoop() требует наличия `@type` в JSON для routing responses.
/// Если Response не включает `@type` в CodingKeys → background loop не может обработать → зависание!
///
/// **Решение:**
/// Вызывай `assertValidEncoding()` в каждом unit тесте для Response модели.
public extension TDLibResponse {
    /// Проверяет что Response корректно кодирует поле `@type` в JSON.
    ///
    /// **Использование:**
    /// ```swift
    /// @Test func encoding() throws {
    ///     let response = UserResponse(id: 123, ...)
    ///     try response.assertValidEncoding()
    /// }
    /// ```
    ///
    /// **Требования:**
    /// - Response ДОЛЖЕН иметь `public let type = "..."`
    /// - CodingKeys ДОЛЖНЫ включать `case type = "@type"`
    func assertValidEncoding() throws {
        let encoder = JSONEncoder()
        let data = try encoder.encode(self)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]

        guard let encodedType = json?["@type"] as? String else {
            throw TDLibResponseValidationError.missingTypeField(responseType: "\(Self.self)")
        }

        guard encodedType == type else {
            throw TDLibResponseValidationError.typeMismatch(
                responseType: "\(Self.self)",
                propertyValue: type,
                encodedValue: encodedType
            )
        }
    }
}
