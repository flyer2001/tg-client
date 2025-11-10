import Foundation
import FoundationExtensions

/// Type-safe представление всех возможных обновлений и ответов от TDLib.
///
/// TDLib может присылать различные типы событий непредсказуемо.
/// Этот enum позволяет безопасно обрабатывать все типы с помощью pattern matching.
///
/// ## Для кодогенерации
///
/// При автоматической генерации из `td_api.tl`:
/// - Добавляются новые case для каждого типа события
/// - Обновляется `init(from:)` для декодирования
public enum TDLibUpdate: Sendable {
    /// Обновление состояния авторизации
    case authorizationState(AuthorizationStateUpdateResponse)

    /// Ошибка от TDLib
    case error(TDLibErrorResponse)

    /// Успешный ответ без данных (ok)
    case ok

    /// Неизвестный тип обновления (для обратной совместимости)
    case unknown(type: String)

    /// Создаёт обновление из сырого JSON объекта.
    ///
    /// Определяет тип обновления по полю `@type` и декодирует в соответствующий case.
    ///
    /// - Parameter json: JSON объект от TDLib с обязательным полем `@type`
    /// - Throws: `TDLibUpdateError.missingTypeField` если поле `@type` отсутствует,
    ///           `DecodingError` если JSON не соответствует ожидаемой структуре
    public init(from json: [String: Any]) throws {
        guard let type = json["@type"] as? String else {
            throw TDLibUpdateError.missingTypeField
        }

        let data = try JSONSerialization.data(withJSONObject: json)

        switch type {
        case "error":
            let error = try JSONDecoder.tdlib().decode(TDLibErrorResponse.self, from: data)
            self = .error(error)

        case "updateAuthorizationState":
            let update = try JSONDecoder.tdlib().decode(AuthorizationStateUpdateResponse.self, from: data)
            self = .authorizationState(update)

        case "ok":
            self = .ok

        default:
            self = .unknown(type: type)
        }
    }

    /// Удобный инициализатор для работы с необязательным JSON.
    ///
    /// Если JSON отсутствует или не содержит поле `@type`, возвращает `.unknown`.
    ///
    /// - Parameter json: Необязательный JSON объект от TDLib
    public init(_ json: [String: Any]?) {
        guard let json = json else {
            self = .unknown(type: "nil")
            return
        }

        do {
            self = try TDLibUpdate(from: json)
        } catch {
            let type = json["@type"] as? String ?? "parsing_error"
            self = .unknown(type: type)
        }
    }
}

/// Ошибки при декодировании TDLib обновлений.
public enum TDLibUpdateError: Error {
    /// JSON объект не содержит обязательного поля "@type"
    case missingTypeField
}
