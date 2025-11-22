import Foundation

/// Client-side ошибки TDLib адаптера (НЕ от TDLib сервера).
///
/// Эти ошибки генерируются внутри TDLibClient, а не возвращаются от TDLib.
/// Для server-side ошибок используется ``TDLibErrorResponse``.
public enum TDLibClientError: Error, Sendable {
    /// Не удалось декодировать ответ TDLib в ожидаемый тип.
    ///
    /// - Parameters:
    ///   - expectedType: Тип, который ожидался для декодирования
    ///   - underlyingError: Исходная ошибка декодирования
    case decodeFailed(expectedType: String, underlyingError: Error)

    /// Обнаружен non-Sendable тип в TDLib JSON response.
    ///
    /// **Когда возникает:**
    /// TDLib вернул JSON с типом данных который не поддерживает Sendable
    /// (например, custom class, closure).
    ///
    /// **Это НЕ должно происходить в норме!**
    /// JSON спецификация гарантирует только Sendable типы.
    /// Если эта ошибка возникла → bug в TDLib или в парсинге.
    ///
    /// - Parameter type: Название проблемного типа
    case nonSendableValue(type: String)

    /// Ошибка парсинга JSON от TDLib — полученная структура не [String: Any].
    ///
    /// **Когда возникает:**
    /// `JSONSerialization` успешно распарсил JSON, но результат не Dictionary.
    ///
    /// **Это НЕ должно происходить в норме!**
    /// TDLib всегда возвращает JSON объект (Dictionary).
    ///
    /// - Parameter json: Исходная JSON строка для debugging
    case invalidJSONStructure(json: String)
}
