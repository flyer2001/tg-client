import Testing
import Foundation
import TDLibAdapter

/// Unit-тесты для декодирования TDLibErrorResponse.
///
/// ## Описание модели
///
/// `TDLibErrorResponse` - ответ TDLib с информацией об ошибке.
/// TDLib возвращает ошибки в стандартном формате.
///
/// **Структура:**
/// - `type` - всегда "error" (константа)
/// - `code: Int` - числовой код ошибки
/// - `message: String` - текстовое описание ошибки
///
/// **Маппинг полей:**
/// - Поля `code` и `message` не требуют преобразования (совпадают с JSON)
///
/// **Conformance:**
/// - `TDLibResponse` - протокол для всех ответов TDLib
/// - `Error` - Swift протокол для ошибок (можно использовать в throw/catch)
/// - `Sendable` - безопасно передавать между async контекстами
///
/// ## Связь с TDLib API
///
/// TDLib возвращает ошибки в формате JSON с полями `code` и `message`.
///
/// **Документация TDLib:**
/// - https://core.telegram.org/tdlib/docs/classtd_1_1td__api_1_1error.html
///
/// ## Типичные коды ошибок
///
/// - `400` - Ошибки валидации (PHONE_NUMBER_INVALID, PHONE_CODE_EMPTY)
/// - `401` - Ошибки авторизации (PHONE_CODE_INVALID, PASSWORD_HASH_INVALID)
/// - `429` - Rate limit (TOO_MANY_REQUESTS)
/// - `500` - Внутренние ошибки TDLib (Network timeout, Connection failed)
@Suite("Декодирование TDLibErrorResponse")
struct TDLibErrorResponseTests {

    let decoder = JSONDecoder()

    /// Декодирование базовой ошибки TDLib.
    ///
    /// Проверяем корректное декодирование ошибки с кодом 400 (валидация).
    @Test("Декодирование TDLibErrorResponse")
    func decodeTDLibErrorResponse() throws {
        // Given: JSON ответ от TDLib с ошибкой валидации
        let json = """
        {
            "code": 400,
            "message": "PHONE_NUMBER_INVALID"
        }
        """
        let data = Data(json.utf8)

        // When: декодируем JSON в модель TDLibErrorResponse
        let error = try decoder.decode(TDLibErrorResponse.self, from: data)

        // Then: поля code, message и type должны быть корректно заполнены
        // Ожидаем: code=400, message="PHONE_NUMBER_INVALID", type="error"
        #expect(error.code == 400)
        #expect(error.message == "PHONE_NUMBER_INVALID")
        #expect(error.type == "error")
    }

    /// Декодирование ошибки сетевого таймаута.
    ///
    /// TDLib возвращает код 500 при внутренних ошибках или проблемах сети.
    @Test("Декодирование TDLibErrorResponse - network timeout")
    func decodeTDLibErrorResponseNetworkTimeout() throws {
        // Given: JSON ответ от TDLib с ошибкой сети
        let json = """
        {
            "code": 500,
            "message": "Network timeout"
        }
        """
        let data = Data(json.utf8)

        // When: декодируем JSON в модель
        let error = try decoder.decode(TDLibErrorResponse.self, from: data)

        // Then: код должен быть 500, сообщение "Network timeout"
        // Ожидаем: это внутренняя ошибка TDLib (сеть или таймаут)
        #expect(error.code == 500)
        #expect(error.message == "Network timeout")
    }

    /// Декодирование ошибки авторизации.
    ///
    /// TDLib возвращает код 401 при неверных credentials (код или пароль).
    @Test("Декодирование TDLibErrorResponse - auth failed")
    func decodeTDLibErrorResponseAuthFailed() throws {
        // Given: JSON ответ от TDLib с ошибкой авторизации
        let json = """
        {
            "code": 401,
            "message": "PHONE_CODE_INVALID"
        }
        """
        let data = Data(json.utf8)

        // When: декодируем JSON в модель
        let error = try decoder.decode(TDLibErrorResponse.self, from: data)

        // Then: код должен быть 401, сообщение "PHONE_CODE_INVALID"
        // Ожидаем: пользователь ввел неверный SMS код
        #expect(error.code == 401)
        #expect(error.message == "PHONE_CODE_INVALID")
    }
}
