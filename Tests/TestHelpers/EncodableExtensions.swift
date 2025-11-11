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
}
