import Foundation
import CTDLib
import Logging

/// Swift-обёртка над TDLib C API для взаимодействия с Telegram.
///
/// Подробнее см. `Sources/TDLibAdapter/README.md`
public final class TDLibClient: @unchecked Sendable {
    private let ffi: TDLibFFI
    internal let appLogger: Logger
    private var parametersSet = false
    internal let authorizationPollTimeout: Double
    private let maxAuthorizationAttempts: Int
    private let authorizationTimeout: TimeInterval

    // AsyncStream для updates от TDLib
    var updatesStream: AsyncStream<Update>?
    var updatesContinuation: AsyncStream<Update>.Continuation?
    var updatesTask: Task<Void, Never>?

    /// ResponseWaiters для управления async continuations
    let responseWaiters = ResponseWaiters()

    /// Dedicated queue для блокирующего td_json_client_receive()
    private let receiveQueue = DispatchQueue(
        label: "com.tg-client.tdlib.receive",
        qos: .userInitiated
    )

    private var isStopped = false
    private let stopLock = NSLock()

    /// Инициализирует TDLib клиент.
    ///
    /// - Parameters:
    ///   - appLogger: Логгер для событий приложения
    ///   - authorizationPollTimeout: Таймаут для polling обновлений от TDLib во время авторизации (в секундах).
    ///   - maxAuthorizationAttempts: Максимальное количество итераций цикла авторизации перед выходом с ошибкой.
    ///   - authorizationTimeout: Общий таймаут на весь процесс авторизации (в секундах).
    public init(
        appLogger: Logger,
        authorizationPollTimeout: Double = 1.0,
        maxAuthorizationAttempts: Int = 500,
        authorizationTimeout: TimeInterval = 300
    ) {
        self.ffi = CTDLibFFI()
        self.appLogger = appLogger
        self.authorizationPollTimeout = authorizationPollTimeout
        self.maxAuthorizationAttempts = maxAuthorizationAttempts
        self.authorizationTimeout = authorizationTimeout
    }

    /// Инициализирует TDLib клиент с внедрённым FFI (для тестов).
    init(
        ffi: TDLibFFI,
        appLogger: Logger,
        authorizationPollTimeout: Double = 1.0,
        maxAuthorizationAttempts: Int = 500,
        authorizationTimeout: TimeInterval = 300
    ) {
        self.ffi = ffi
        self.appLogger = appLogger
        self.authorizationPollTimeout = authorizationPollTimeout
        self.maxAuthorizationAttempts = maxAuthorizationAttempts
        self.authorizationTimeout = authorizationTimeout
    }

    deinit {
        stopLock.lock()
        isStopped = true
        stopLock.unlock()

        updatesContinuation?.finish()
        updatesTask?.cancel()
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
                      promptFor: @escaping @Sendable (AuthenticationPrompt) async -> String) async throws {
        try ffi.create()

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
        let encoder = TDLibRequestEncoder()
        guard let data = try? encoder.encode(request) else {
            appLogger.error("Failed to encode request: \(request.type)")
            return
        }
        data.withUnsafeBytes { raw in
            let s = String(decoding: raw.bindMemory(to: UInt8.self), as: UTF8.self)
            ffi.send(s)
        }
    }

    /// Получает ответ или обновление от TDLib.
    ///
    /// **⚠️ ЕДИНСТВЕННАЯ ТОЧКА ПРЕОБРАЗОВАНИЯ [String: Any] → TDLibJSON**
    ///
    /// Блокирует текущий поток на время `timeout`.
    ///
    /// - Parameter timeout: Максимальное время ожидания в секундах
    /// - Returns: Sendable-safe JSON объект с полем `@type`, или `nil` если timeout
    /// - Throws:
    ///   - `TDLibClientError.invalidJSONStructure` если TDLib вернул не Dictionary
    ///   - `TDLibClientError.nonSendableValue` если JSON содержит non-Sendable типы
    func receive(timeout: Double) throws -> TDLibJSON? {
        guard let json = ffi.receive(timeout: timeout) else {
            // Нет данных - это нормально при timeout
            return nil
        }

        // Парсим JSON → [String: Any]
        guard let parsed = try JSONSerialization.jsonObject(with: Data(json.utf8)) as? [String: Any] else {
            throw TDLibClientError.invalidJSONStructure(json: json)
        }

        // Логируем @type для trace
        if let type = parsed["@type"] as? String {
            appLogger.trace("receive: got @type='\(type)'")
        }

        // ✅ ВАЛИДАЦИЯ: преобразуем в Sendable-safe TDLibJSON
        return try TDLibJSON(parsing: parsed)
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
    /// TDLib имеет ЕДИНУЮ очередь сообщений через `td_json_client_receive()`.
    /// ТОЛЬКО этот loop вызывает `receive()` (serial, DispatchQueue).
    ///
    /// Все остальные части кода получают данные через:
    /// - AsyncStream<Update> для updates (updateNewChat, updateUser и т.д.)
    /// - ResponseWaiters для request/response (ok, user, chats и т.д.)
    func startUpdatesLoop() {
        // КРИТИЧНО: Инициализируем updates stream ДО запуска loop
        // Иначе если никто не подписался на updates → updatesContinuation = nil → updates теряются
        if updatesContinuation == nil {
            let (stream, continuation) = AsyncStream<Update>.makeStream()
            updatesStream = stream
            updatesContinuation = continuation
            appLogger.debug("startUpdatesLoop: initialized updates stream and continuation")
        }

        appLogger.info("startUpdatesLoop: background loop started")

        let (stream, continuation) = AsyncStream.makeStream(of: TDLibJSON.self)

        // DispatchQueue для блокирующего td_json_client_receive()
        receiveQueue.async { [weak self] in
            guard let self else {
                continuation.finish()
                return
            }

            var loopCount = 0
            while true {
                self.stopLock.lock()
                let stopped = self.isStopped
                self.stopLock.unlock()

                if stopped { break }

                loopCount += 1
                if loopCount % 500 == 0 {
                    self.appLogger.debug("startUpdatesLoop: iteration \(loopCount)")
                }

                do {
                    guard let json = try self.receive(timeout: 0.1) else {
                        continue
                    }
                    continuation.yield(json)
                } catch {
                    self.appLogger.error("startUpdatesLoop: receive() error: \(error)")
                }
            }

            self.appLogger.info("Updates loop stopped")
            continuation.finish()
        }

        // Task для async обработки результатов
        updatesTask = Task { [weak self] in
            guard let self else { return }

            for await tdlibJSON in stream {
                guard let type = tdlibJSON["@type"] as? String else {
                    appLogger.trace("startUpdatesLoop: received object without @type")
                    continue
                }

                appLogger.trace("startUpdatesLoop: received @type='\(type)'")

                // 1. Ошибки — пробрасываем в первый ожидающий waiter (FIFO)
                if type == "error" {
                    do {
                        let data = try JSONSerialization.data(withJSONObject: tdlibJSON.data)
                        let error = try JSONDecoder.tdlib().decode(TDLibErrorResponse.self, from: data)
                        appLogger.debug("startUpdatesLoop: error response [\(error.code)]: \(error.message)")
                        var result: ResponseWaiters.ResumeResult = .noWaiter
                        for expectedType in ["ok", "user", "chats", "chat", "messages", "updateAuthorizationState"] {
                            result = await self.responseWaiters.resumeWaiter(for: expectedType, with: error)
                            if result.wasResumed {
                                break
                            }
                        }
                        if !result.wasResumed {
                            appLogger.warning("startUpdatesLoop: no waiter for error [\(error.code)]: \(error.message)")
                        }
                    } catch {
                        appLogger.error("startUpdatesLoop: failed to decode error response: \(error)")
                    }
                    continue
                }

                // 2. Updates (updateNewChat, updateUser и т.д.) — отправляем в AsyncStream
                if type.hasPrefix("update") && type != "updateAuthorizationState" {
                    do {
                        let data = try JSONSerialization.data(withJSONObject: tdlibJSON.data)
                        let update = try JSONDecoder.tdlib().decode(Update.self, from: data)
                        appLogger.trace("startUpdatesLoop: decoded Update, yielding to stream")
                        updatesContinuation?.yield(update)
                    } catch {
                        appLogger.warning("startUpdatesLoop: failed to decode update type '\(type)': \(error)")
                    }
                    continue
                }

                // 3. Responses (ok, user, chats и т.д.) — отправляем в responseWaiters
                appLogger.debug("startUpdatesLoop: response type '\(type)', notifying waiter")
                let result = await self.responseWaiters.resumeWaiter(for: type, with: tdlibJSON)
                if !result.wasResumed {
                    appLogger.warning("startUpdatesLoop: no waiter for response type '\(type)'")
                }
            }

            await self.responseWaiters.cancelAll()
        }
    }
}

