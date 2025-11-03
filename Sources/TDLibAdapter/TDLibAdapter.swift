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

    deinit { if let c = client { td_json_client_destroy(c) } }

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
    public func send(_ request: TDLibRequest) {
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
    public func receive(timeout: Double) -> [String: Any]? {
        guard let client, let cstr = td_json_client_receive(client, timeout) else { return nil }
        let json = String(cString: cstr)
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
    /// См. https://core.telegram.org/tdlib/docs/classtd_1_1td__api_1_1update_authorization_state.html
    ///
    /// **2. Прямой ответ на getAuthorizationState()** (когда мы явно запрашиваем):
    /// ```json
    /// {
    ///   "@type": "authorizationStateWaitTdlibParameters"
    /// }
    /// ```
    /// См. https://core.telegram.org/tdlib/docs/classtd_1_1td__api_1_1get_authorization_state.html
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
        // Kickstart: request current auth state
        send(GetAuthorizationStateRequest())

        var attemptCount = 0
        var lastActivity: AuthorizationLoopActivity?
        let startTime = Date()

        while true {
            // Проверка превышения лимита попыток
            attemptCount += 1
            if attemptCount > maxAuthorizationAttempts {
                appLogger.error("Authorization loop exceeded max attempts (\(maxAuthorizationAttempts)). Last activity: \(lastActivity?.description ?? "none")")
                return
            }

            // Проверка таймаута
            let elapsed = Date().timeIntervalSince(startTime)
            if elapsed > authorizationTimeout {
                appLogger.error("Authorization timeout (\(authorizationTimeout)s). Last activity: \(lastActivity?.description ?? "none")")
                return
            }

            guard let obj = receive(timeout: authorizationPollTimeout) else {
                lastActivity = .emptyReceive
                await Task.yield()
                continue
            }
            guard let type = obj["@type"] as? String else {
                lastActivity = .missingType
                appLogger.warning("Received object without @type")
                await Task.yield()
                continue
            }

            // Не логируем обычные обновления (только ошибки)

            // Логируем ошибки от TDLib
            if type == "error" {
                let code = obj["code"] as? Int ?? 0
                let message = obj["message"] as? String ?? "unknown"
                lastActivity = .tdlibError(code: code, message: message)
                appLogger.error("TDLib error [\(code)]: \(message)")
                continue
            }

            // Парсим состояние авторизации
            guard let (state, originalType) = parseAuthorizationState(from: obj) else {
                // Не авторизационное событие - логируем и пропускаем
                lastActivity = .nonAuthorizationEvent(type: type)
                appLogger.debug("Received non-authorization event: \(type)")
                await Task.yield()
                continue
            }

            // Отслеживаем текущее состояние авторизации
            lastActivity = .authorizationState(state, originalType: originalType)
            appLogger.info("Authorization state: \(originalType)")

            switch state {
            case .waitTdlibParameters:
                if !parametersSet {
                    appLogger.info("Setting TDLib parameters...")
                    let request = SetTdlibParametersRequest(
                        useTestDc: false,
                        databaseDirectory: config.stateDir + "/db",
                        filesDirectory: config.stateDir + "/files",
                        databaseEncryptionKey: "",
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
                appLogger.warning("Unknown authorization state: \(originalType)")
            }

            // Позволяем другим Task выполняться
            await Task.yield()
        }
    }
}
