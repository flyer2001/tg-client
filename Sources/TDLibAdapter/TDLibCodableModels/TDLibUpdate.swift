import Foundation

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
    case authorizationState(AuthorizationStateUpdate)

    /// Ошибка от TDLib
    case error(TDLibError)

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
            let error = try JSONDecoder().decode(TDLibError.self, from: data)
            self = .error(error)

        case "updateAuthorizationState":
            let update = try JSONDecoder().decode(AuthorizationStateUpdate.self, from: data)
            self = .authorizationState(update)

        default:
            self = .unknown(type: type)
        }
    }
}

/// Ошибки при декодировании TDLib обновлений.
public enum TDLibUpdateError: Error {
    /// JSON объект не содержит обязательного поля "@type"
    case missingTypeField
}
