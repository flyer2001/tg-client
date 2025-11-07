import Testing
import Foundation
import TDLibAdapter

/// Unit-тесты для кодирования GetMeRequest.
///
/// ## Описание модели
///
/// `GetMeRequest` - запрос информации о текущем авторизованном пользователе.
/// Простейший запрос без параметров, содержит только поле `@type`.
///
/// **Структура:**
/// - `type` - всегда "getMe" (константа)
///
/// **Маппинг полей:**
/// - `type` → `@type` (в JSON)
///
/// ## Связь с TDLib API
///
/// Запрос `getMe` возвращает информацию о текущем пользователе (User объект).
/// Используется для проверки успешной авторизации.
///
/// **Документация TDLib:**
/// - https://core.telegram.org/tdlib/docs/classtd_1_1td__api_1_1get_me.html
///
/// ## Пример использования
///
/// ```swift
/// let request = GetMeRequest()
/// let data = try encoder.encode(request)
/// // JSON: {"@type":"getMe"}
/// ```
@Suite("Кодирование GetMeRequest")
struct GetMeRequestTests {

    let encoder = TDLibRequestEncoder()

    /// Кодирование простого запроса без параметров.
    ///
    /// GetMeRequest - простейший запрос TDLib, содержит только поле `@type`.
    @Test("Encode GetMeRequest - простой запрос без параметров")
    func encodeGetMeRequest() throws {
        // Given: создаем запрос GetMeRequest
        let request = GetMeRequest()

        // When: кодируем запрос в JSON через TDLibRequestEncoder
        let data = try encoder.encode(request)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]

        // Then: JSON должен содержать только поле "@type" со значением "getMe"
        // Ожидаем: {"@type": "getMe"}
        #expect(json != nil)
        #expect(json?["@type"] as? String == "getMe")
        #expect(json?.count == 1, "GetMeRequest должен содержать только поле @type")
    }

    /// Проверка валидности JSON формата.
    ///
    /// Закодированные данные должны быть валидным JSON объектом.
    @Test("Encoded JSON is valid format")
    func encodedJSONIsValidFormat() throws {
        // Given: создаем запрос
        let request = GetMeRequest()

        // When: кодируем в JSON
        let data = try encoder.encode(request)

        // Then: данные должны быть валидным JSON объектом (словарь)
        // Ожидаем: JSONSerialization успешно парсит данные как [String: Any]
        let json = try JSONSerialization.jsonObject(with: data)
        #expect(json is [String: Any])
    }

    /// Проверка что закодированные данные не пустые.
    ///
    /// Минимальный запрос должен содержать хотя бы поле `@type`.
    @Test("Encoded data is not empty")
    func encodedDataIsNotEmpty() throws {
        // Given: создаем запрос
        let request = GetMeRequest()

        // When: кодируем в JSON
        let data = try encoder.encode(request)

        // Then: данные не должны быть пустыми
        // Ожидаем: как минимум {"@type":"getMe"} - несколько байт
        #expect(!data.isEmpty, "Закодированные данные не должны быть пустыми")
    }
}
