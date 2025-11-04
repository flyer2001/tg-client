import Foundation

/// High-level API для TDLibClient.
///
/// Предоставляет типобезопасные методы для работы с TDLib вместо низкоуровневого send/receive.
extension TDLibClient: TDLibClientProtocol {

    // MARK: - Authentication Methods

    public func setAuthenticationPhoneNumber(_ phoneNumber: String) async throws -> AuthorizationStateUpdate {
        // Отправляем запрос на установку номера телефона
        send(SetAuthenticationPhoneNumberRequest(phoneNumber: phoneNumber))

        // Ожидаем обновления состояния авторизации
        return try await waitForAuthorizationUpdate()
    }

    public func checkAuthenticationCode(_ code: String) async throws -> AuthorizationStateUpdate {
        // Отправляем запрос на проверку кода
        send(CheckAuthenticationCodeRequest(code: code))

        // Ожидаем обновления состояния авторизации
        return try await waitForAuthorizationUpdate()
    }

    public func checkAuthenticationPassword(_ password: String) async throws -> AuthorizationStateUpdate {
        // Отправляем запрос на проверку пароля 2FA
        send(CheckAuthenticationPasswordRequest(password: password))

        // Ожидаем обновления состояния авторизации
        return try await waitForAuthorizationUpdate()
    }

    // MARK: - User Methods

    public func getMe() async throws -> User {
        // Отправляем запрос на получение информации о текущем пользователе
        send(GetMeRequest())

        // Ожидаем ответа от TDLib
        return try await waitForResponse(ofType: User.self)
    }

    // MARK: - Helper Methods

    /// Ожидает следующего обновления состояния авторизации от TDLib.
    ///
    /// Метод получает обновления от TDLib через `receive()` и возвращает первое валидное
    /// обновление состояния авторизации. Если получена ошибка, бросает исключение.
    ///
    /// **Таймаут:** использует `authorizationPollTimeout` из конфигурации клиента.
    ///
    /// - Returns: Обновление состояния авторизации
    /// - Throws: `TDLibError` если TDLib вернул ошибку
    private func waitForAuthorizationUpdate() async throws -> AuthorizationStateUpdate {
        // Используем таймаут для каждого receive call
        let timeout = authorizationPollTimeout

        // Пытаемся получить обновление от TDLib
        while true {
            guard let rawResponse = receive(timeout: timeout) else {
                // Если receive вернул nil, пытаемся снова
                await Task.yield()
                continue
            }

            // Парсим ответ через TDLibUpdate enum
            let update = TDLibUpdate(rawResponse)

            switch update {
            case .authorizationState(let authUpdate):
                // Получили обновление состояния авторизации
                return authUpdate

            case .error(let error):
                // TDLib вернул ошибку
                appLogger.error("TDLib error [\(error.code)]: \(error.message)")
                throw error

            case .ok:
                // OK response - не то что нам нужно, ждём дальше
                await Task.yield()
                continue

            case .unknown:
                // Неизвестное обновление, логируем и ждём дальше
                let type = rawResponse["@type"] as? String ?? "unknown"
                appLogger.debug("Received non-authorization update: \(type)")
                await Task.yield()
                continue
            }
        }
    }

    /// Ожидает ответа определенного типа от TDLib.
    ///
    /// Метод получает обновления от TDLib через `receive()` и возвращает первый ответ
    /// указанного типа. Если получена ошибка, бросает исключение.
    ///
    /// **Таймаут:** использует `authorizationPollTimeout` из конфигурации клиента.
    ///
    /// - Parameter ofType: Тип ожидаемого ответа
    /// - Returns: Ответ указанного типа
    /// - Throws: `TDLibError` если TDLib вернул ошибку
    private func waitForResponse<T: TDLibResponse>(ofType: T.Type) async throws -> T {
        let timeout = authorizationPollTimeout

        while true {
            guard let rawResponse = receive(timeout: timeout) else {
                await Task.yield()
                continue
            }

            // Проверяем на ошибку
            let update = TDLibUpdate(rawResponse)
            if case .error(let error) = update {
                appLogger.error("TDLib error [\(error.code)]: \(error.message)")
                throw error
            }

            // Пытаемся декодировать в нужный тип
            do {
                let data = try JSONSerialization.data(withJSONObject: rawResponse)
                let decoder = JSONDecoder()
                let response = try decoder.decode(T.self, from: data)
                return response
            } catch {
                // Не удалось декодировать - это не наш тип, ждём дальше
                await Task.yield()
            }
        }
    }
}
