import Foundation
import CTDLib
import Logging

/// Swift-обёртка над TDLib C API для взаимодействия с Telegram.
///
/// Подробнее см. `Sources/TDLibAdapter/README.md`
public final class TDLibClient: @unchecked Sendable {
    private var client: UnsafeMutableRawPointer?
    internal let appLogger: Logger
    private var parametersSet = false
    internal let authorizationPollTimeout: Double
    private let maxAuthorizationAttempts: Int
    private let authorizationTimeout: TimeInterval

    // AsyncStream для updates от TDLib
    var updatesContinuation: AsyncStream<Update>.Continuation?
    var updatesTask: Task<Void, Never>?

    // Response handling через единый background loop
    //
    // **АРХИТЕКТУРНОЕ РЕШЕНИЕ: C interop с TDLib**
    // TDLib — C библиотека с блокирующим `td_json_client_receive()`.
    // Swift Concurrency (actor) не подходит для C interop — используем NSLock.
    //
    // **Thread-safety:** NSLock защищает mutable state (waiters dictionary).
    // **@unchecked Sendable:** Класс содержит mutable state, но защищён NSLock.
    final class ResponseWaiters: @unchecked Sendable {
        private let lock = NSLock()
        private var waiters: [String: CheckedContinuation<[String: Any], Error>] = [:]

        func addWaiter(for type: String, continuation: CheckedContinuation<[String: Any], Error>) {
            lock.lock()
            waiters[type] = continuation
            lock.unlock()
        }

        func resumeWaiter(for type: String, with response: [String: Any]) -> Bool {
            lock.lock()
            let continuation = waiters.removeValue(forKey: type)
            lock.unlock()

            guard let continuation else {
                return false
            }
            // SAFETY: Dictionary [String: Any] не Sendable, но:
            // - TDLib возвращает immutable JSON dictionary
            // - NSLock гарантирует что continuation извлечён thread-safe
            // - Копия dictionary передаётся через continuation один раз
            nonisolated(unsafe) let unsafeResponse = response
            continuation.resume(returning: unsafeResponse)
            return true
        }

        func resumeWaiterWithError(for type: String, error: Error) -> Bool {
            lock.lock()
            let continuation = waiters.removeValue(forKey: type)
            lock.unlock()

            guard let continuation else {
                return false
            }
            continuation.resume(throwing: error)
            return true
        }

        func cancelAll() {
            lock.lock()
            let allWaiters = waiters
            waiters.removeAll()
            lock.unlock()

            for (_, continuation) in allWaiters {
                continuation.resume(throwing: CancellationError())
            }
        }
    }

    let responseWaiters = ResponseWaiters()

    /// Инициализирует TDLib клиент.
    ///
    /// - Parameters:
    ///   - appLogger: Логгер для событий приложения
    ///   - authorizationPollTimeout: Таймаут для polling обновлений от TDLib во время авторизации (в секундах).
    ///                               По умолчанию 1.0 секунда. Увеличение значения снижает CPU нагрузку,
    ///                               но увеличивает время отклика на состояния авторизации.
    ///   - maxAuthorizationAttempts: Максимальное количество итераций цикла авторизации перед выходом с ошибкой.
    ///                               По умолчанию 500. Защита от бесконечного цикла при проблемах с TDLib.
    ///   - authorizationTimeout: Общий таймаут на весь процесс авторизации (в секундах).
    ///                           По умолчанию 300 секунд (5 минут). После превышения авторизация прерывается с ошибкой.
    public init(
        appLogger: Logger,
        authorizationPollTimeout: Double = 1.0,
        maxAuthorizationAttempts: Int = 500,
        authorizationTimeout: TimeInterval = 300
    ) {
        self.appLogger = appLogger
        self.authorizationPollTimeout = authorizationPollTimeout
        self.maxAuthorizationAttempts = maxAuthorizationAttempts
        self.authorizationTimeout = authorizationTimeout
    }

    deinit {
        updatesContinuation?.finish()
        updatesTask?.cancel()
        if let c = client { td_json_client_destroy(c) }
    }

    /// Настраивает логирование TDLib библиотеки.
    ///
    /// Применяет настройки уровня детализации и пути к лог-файлу из конфигурации.
    ///
    /// - Parameter config: Конфигурация с параметрами логирования
    public static func configureTDLibLogging(config: TDConfig) {
        // Устанавливаем уровень детализации логов
        _ = td_execute("{\"@type\":\"setLogVerbosityLevel\",\"new_verbosity_level\":\(config.logVerbosity.rawValue)}")

        // Настраиваем вывод в файл
        let logStreamRequest = """
        {
            "@type":"setLogStream",
            "log_stream":{
                "@type":"logStreamFile",
                "path":"\(config.logPath)",
                "max_file_size":\(100*1024*1024)
            }
        }
        """
        _ = td_execute(logStreamRequest)
    }

    /// Запускает TDLib клиент и выполняет авторизацию.
    ///
    /// Метод блокируется до завершения авторизации. Автоматически проходит все состояния
    /// авторизации TDLib, запрашивая необходимые данные через колбэк.
    ///
    /// - Parameters:
    ///   - config: Конфигурация с API credentials и путями к директориям
    ///   - promptFor: Колбэк для запроса данных авторизации (номер телефона, код, пароль 2FA)
    public func start(config: TDConfig,
                      promptFor: @escaping @Sendable (AuthenticationPrompt) async -> String) async {
        client = td_json_client_create()

        // КРИТИЧНО: Запускаем background loop ДО authorization
        // Иначе processAuthorizationStates() будет конкурировать за receive()
        startUpdatesLoop()
        appLogger.info("Background updates loop started before authorization")

        // run receive loop in background Task
        await withCheckedContinuation { continuation in
            Task {
                await self.processAuthorizationStates(config: config, promptFor: promptFor, onReady: {
                    continuation.resume()
                })
            }
        }
    }

    /// Отправляет типизированный запрос в TDLib.
    ///
    /// - Parameter request: Типизированный запрос TDLibRequest
    func send(_ request: TDLibRequest) {
        guard let client else {
            appLogger.error("Cannot send: client is nil")
            return
        }
        let encoder = TDLibRequestEncoder()
        guard let data = try? encoder.encode(request) else {
            appLogger.error("Failed to encode request: \(request.type)")
            return
        }
        data.withUnsafeBytes { raw in
            let s = String(decoding: raw.bindMemory(to: UInt8.self), as: UTF8.self)
            td_json_client_send(client, s)
        }
    }

    /// Получает ответ или обновление от TDLib.
    ///
    /// Блокирует текущий поток на время `timeout`.
    ///
    /// - Parameter timeout: Максимальное время ожидания в секундах
    /// - Returns: JSON-объект с полем `@type` или `nil`
    func receive(timeout: Double) -> [String: Any]? {
        guard let client, let cstr = td_json_client_receive(client, timeout) else {
            // Нет данных - это нормально при timeout
            return nil
        }
        let json = String(cString: cstr)

        // Логируем только @type для краткости
        if let parsed = (try? JSONSerialization.jsonObject(with: Data(json.utf8))) as? [String: Any],
           let type = parsed["@type"] as? String {
            appLogger.trace("receive: got @type='\(type)'")
            return parsed
        }

        return (try? JSONSerialization.jsonObject(with: Data(json.utf8))) as? [String: Any]
    }

    /// Извлекает состояние авторизации из JSON-ответа TDLib.
    ///
    /// TDLib присылает состояния авторизации двумя способами:
    ///
    /// **1. updateAuthorizationState** (автоматическое уведомление при изменении):
    /// ```json
    /// {
    ///   "@type": "updateAuthorizationState",
    ///   "authorization_state": {
    ///     "@type": "authorizationStateWaitPhoneNumber"
    ///   }
    /// }
    /// ```
    /// См. https://core.telegram.org/tdlib/.claude/classtd_1_1td__api_1_1update_authorization_state.html
    ///
    /// **2. Прямой ответ на getAuthorizationState()** (когда мы явно запрашиваем):
    /// ```json
    /// {
    ///   "@type": "authorizationStateWaitTdlibParameters"
    /// }
    /// ```
    /// См. https://core.telegram.org/tdlib/.claude/classtd_1_1td__api_1_1get_authorization_state.html
    ///
    /// - Parameter obj: JSON-объект от TDLib
    /// - Returns: Кортеж (состояние, оригинальная строка типа) или `nil` если это не авторизационное событие
    private func parseAuthorizationState(from obj: [String: Any]) -> (state: AuthorizationState, originalType: String)? {
        guard let type = obj["@type"] as? String else { return nil }

        let stateTypeString: String?

        if type == "updateAuthorizationState" {
            // Update: состояние вложено в поле authorization_state
            let authState = obj["authorization_state"] as? [String: Any]
            stateTypeString = authState?["@type"] as? String
        } else if type.hasPrefix("authorizationState") {
            // Прямой ответ: само состояние в поле @type
            stateTypeString = type
        } else {
            // Не авторизационное событие
            return nil
        }

        guard let stateTypeString = stateTypeString else { return nil }
        let state = AuthorizationState(fromTDLibType: stateTypeString)
        return (state, stateTypeString)
    }

    private func processAuthorizationStates(config: TDConfig,
                                            promptFor: @escaping @Sendable (AuthenticationPrompt) async -> String,
                                            onReady: @escaping @Sendable () -> Void) async {
        // TDLib автоматически присылает updateAuthorizationState при запуске
        // НЕ нужно вызывать GetAuthorizationStateRequest() - это создаёт race condition

        var attemptCount = 0
        let startTime = Date()

        while true {
            // Проверка превышения лимита попыток
            attemptCount += 1
            if attemptCount > maxAuthorizationAttempts {
                appLogger.error("Authorization loop exceeded max attempts (\(maxAuthorizationAttempts)).")
                return
            }

            // Проверка таймаута
            let elapsed = Date().timeIntervalSince(startTime)
            if elapsed > authorizationTimeout {
                appLogger.error("Authorization timeout (\(authorizationTimeout)s).")
                return
            }

            // Ждём следующего updateAuthorizationState через единый background loop
            let authUpdate: AuthorizationStateUpdateResponse
            do {
                authUpdate = try await waitForAuthorizationUpdate()
            } catch {
                appLogger.error("Failed to wait for authorization update: \(error)")
                continue
            }

            let stateType = authUpdate.authorizationState.type
            let state = AuthorizationState(fromTDLibType: stateType)
            appLogger.info("Authorization state: \(stateType)")

            switch state {
            case .waitTdlibParameters:
                if !parametersSet {
                    appLogger.info("Setting TDLib parameters...")

                    // Проверка наличия ключа шифрования БД
                    if config.databaseEncryptionKey.isEmpty {
                        appLogger.warning("⚠️  TDLIB_DATABASE_ENCRYPTION_KEY не задан! База данных НЕ будет зашифрована. Это НЕБЕЗОПАСНО для production. Рекомендуется установить ключ через переменную окружения.")
                    } else {
                        appLogger.info("✓ Database encryption enabled (key length: \(config.databaseEncryptionKey.count) chars)")
                    }

                    let request = SetTdlibParametersRequest(
                        useTestDc: false,
                        databaseDirectory: config.stateDir + "/db",
                        filesDirectory: config.stateDir + "/files",
                        databaseEncryptionKey: config.databaseEncryptionKey,
                        useFileDatabase: true,
                        useChatInfoDatabase: true,
                        useMessageDatabase: true,
                        useSecretChats: false,
                        apiId: config.apiId,
                        apiHash: config.apiHash,
                        systemLanguageCode: "en",
                        deviceModel: "macOS",
                        systemVersion: "",
                        applicationVersion: "0.1.0"
                    )
                    send(request)
                    parametersSet = true
                    appLogger.info("TDLib parameters sent")
                } else {
                    appLogger.info("TDLib parameters already set, skipping...")
                }

            case .waitEncryptionKey:
                appLogger.info("Setting encryption key (empty for no encryption)...")
                send(CheckDatabaseEncryptionKeyRequest(encryptionKey: ""))
                appLogger.info("Encryption key sent")

            case .waitPhoneNumber:
                appLogger.info("Requesting phone number...")
                let phone = await promptFor(.phoneNumber)
                appLogger.info("Phone number received: \(phone)")
                send(SetAuthenticationPhoneNumberRequest(phoneNumber: phone))
                appLogger.info("Phone number sent to TDLib")

            case .waitVerificationCode:
                let code = await promptFor(.verificationCode)
                send(CheckAuthenticationCodeRequest(code: code))

            case .waitTwoFactorPassword:
                let password = await promptFor(.twoFactorPassword)
                send(CheckAuthenticationPasswordRequest(password: password))

            case .ready:
                appLogger.info("TDLib authorization READY")
                onReady()
                return

            case .closed:
                appLogger.info("TDLib closed")
                return

            case .unknown:
                appLogger.warning("Unknown authorization state: \(stateType)")
            }

            // Позволяем другим Task выполняться
            await Task.yield()
        }
    }

    /// Запускает фоновый receive loop для обработки ВСЕХ сообщений от TDLib.
    ///
    /// **АРХИТЕКТУРНОЕ РЕШЕНИЕ:**
    /// TDLib имеет ЕДИНУЮ очередь сообщений через `td_json_client_receive()`.
    /// Если несколько мест вызывают `receive()` одновременно → race condition!
    ///
    /// **Решение:** ТОЛЬКО этот background loop вызывает `receive()`.
    /// Все остальные части кода получают данные через:
    /// - AsyncStream<Update> для updates (updateNewChat, updateUser и т.д.)
    /// - ResponseWaiters для request/response (ok, user, chats и т.д.)
    ///
    /// Вызывается автоматически при первом обращении к `updates` property.
    func startUpdatesLoop() {
        appLogger.info("startUpdatesLoop: background loop started")
        updatesTask = Task { [weak self] in
            guard let self else { return }

            var loopCount = 0
            while !Task.isCancelled {
                loopCount += 1
                if loopCount % 500 == 0 {
                    appLogger.debug("startUpdatesLoop: iteration \(loopCount)")
                }

                guard let obj = self.receive(timeout: 0.1) else {
                    await Task.yield()
                    continue
                }

                guard let type = obj["@type"] as? String else {
                    appLogger.trace("startUpdatesLoop: received object without @type")
                    await Task.yield()
                    continue
                }

                appLogger.trace("startUpdatesLoop: received @type='\(type)'")

                // 1. Ошибки — пробрасываем в первый ожидающий waiter
                //    TODO (post-MVP): использовать @extra для маршрутизации по request_id
                if type == "error" {
                    if let code = obj["code"] as? Int, let message = obj["message"] as? String {
                        appLogger.debug("startUpdatesLoop: error response [\(code)]: \(message)")
                        let error = TDLibErrorResponse(code: code, message: message)
                        // Пытаемся resume любой ожидающий waiter с ошибкой
                        // На MVP мы делаем запросы последовательно, поэтому это безопасно
                        // Проходим по всем зарегистрированным типам и пытаемся resume
                        // FIXME: Это упрощение! Нужен @extra для точной маршрутизации
                        var resumed = false
                        for expectedType in ["ok", "user", "chats", "chat", "messages", "updateAuthorizationState"] {
                            if self.responseWaiters.resumeWaiterWithError(for: expectedType, error: error) {
                                resumed = true
                                break
                            }
                        }
                        if !resumed {
                            appLogger.warning("startUpdatesLoop: no waiter for error [\(code)]: \(message)")
                        }
                    }
                    await Task.yield()
                    continue
                }

                // 2. Updates (updateNewChat, updateUser и т.д.) — отправляем в AsyncStream
                // ИСКЛЮЧЕНИЕ: updateAuthorizationState идёт в responseWaiters (обрабатывается waitForAuthorizationUpdate)
                if type.hasPrefix("update") && type != "updateAuthorizationState" {
                    do {
                        let data = try JSONSerialization.data(withJSONObject: obj)
                        let update = try JSONDecoder.tdlib().decode(Update.self, from: data)
                        appLogger.trace("startUpdatesLoop: decoded Update, yielding to stream")
                        updatesContinuation?.yield(update)
                    } catch {
                        appLogger.warning("startUpdatesLoop: failed to decode update type '\(type)': \(error)")
                    }
                    await Task.yield()
                    continue
                }

                // 3. Responses (ok, user, chats, authorizationState* и т.д.) — отправляем в responseWaiters
                appLogger.debug("startUpdatesLoop: response type '\(type)', notifying waiter")
                let resumed = self.responseWaiters.resumeWaiter(for: type, with: obj)
                if !resumed {
                    appLogger.warning("startUpdatesLoop: no waiter for response type '\(type)'")
                }

                await Task.yield()
            }

            appLogger.info("Updates loop stopped")
            self.responseWaiters.cancelAll()
        }
    }
}

