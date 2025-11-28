import TgClientModels
import Foundation
import FoundationExtensions

/// Test helpers для упрощения работы с TDLib моделями в тестах.
///
/// Предоставляет удобные методы для encode моделей через TDLib encoder.
public extension Encodable {
    /// Encode через TDLib encoder в Data (для тестов).
    ///
    /// Использует `JSONEncoder.tdlib()` с настройками:
    /// - snake_case encoding для всех ключей
    ///
    /// - Returns: Закодированные данные в формате TDLib API
    /// - Throws: Ошибка кодирования если модель невалидна
    ///
    /// ## Использование
    ///
    /// ```swift
    /// let response = UserResponse(userId: 123, firstName: "Test")
    /// let data = try response.toTDLibData()
    /// let decoded = try TDLibResponseDecoder.decode(UserResponse.self, from: data)
    /// #expect(decoded.userId == 123)
    /// ```
    func toTDLibData() throws -> Data {
        try JSONEncoder.tdlib().encode(self)
    }

    /// Encode через TDLib encoder в JSON String с опциональным @extra.
    ///
    /// **@extra matching:**
    /// TDLib копирует @extra из request в response для идентификации ответов.
    /// Этот метод позволяет добавить @extra в любой Encodable объект.
    ///
    /// - Parameter extra: Опциональный @extra ID для инъекции в JSON
    /// - Returns: JSON string готовый для отправки в TDLib
    ///
    /// ## Использование
    ///
    /// ```swift
    /// let request = GetChatRequest(chatId: 123)
    /// let json = try request.toTDLibJSON(withExtra: "req_123")
    /// mockFFI.send(json)
    /// // Response будет содержать "@extra": "req_123"
    /// ```
    func toTDLibJSON(withExtra extra: String? = nil) throws -> String {
        var data = try toTDLibData()

        if let extra = extra {
            guard var dict = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                throw NSError(domain: "EncodableExtensions", code: -1,
                              userInfo: [NSLocalizedDescriptionKey: "Failed to parse encoded data as dictionary"])
            }
            dict["@extra"] = extra
            data = try JSONSerialization.data(withJSONObject: dict)
        }

        guard let json = String(data: data, encoding: .utf8) else {
            throw NSError(domain: "EncodableExtensions", code: -2,
                          userInfo: [NSLocalizedDescriptionKey: "Failed to convert Data to String"])
        }
        return json
    }
}
