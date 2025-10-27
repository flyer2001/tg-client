import Foundation

/// Базовый протокол для всех запросов к TDLib API.
///
/// Все запросы должны содержать поле `type`, которое определяет тип запроса в TDLib.
///
/// ## Кодирование
///
/// При кодировании структура автоматически добавляет поле `@type` с помощью `TDLibRequestEncoder`.
///
/// ## Для кодогенерации
///
/// Этот протокол спроектирован для автоматической генерации из `td_api.tl` схемы.
/// Кодогенератор должен создавать структуры conforming к этому протоколу.
public protocol TDLibRequest: Encodable, Sendable {
    /// TDLib тип запроса (значение для поля "@type" в JSON).
    ///
    /// Например: "getAuthorizationState", "setTdlibParameters", "checkAuthenticationCode"
    var type: String { get }
}
