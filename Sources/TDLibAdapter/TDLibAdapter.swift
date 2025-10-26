import Foundation
import CTDLib
import Logging

/// Тип запроса данных для авторизации в Telegram.
public enum AuthenticationPrompt {
    /// Запрос номера телефона
    case phoneNumber
    /// Запрос кода подтверждения из SMS/Telegram
    case verificationCode
    /// Запрос пароля двухфакторной аутентификации (2FA)
    case twoFactorPassword
}

/// Swift-обёртка над TDLib C API для взаимодействия с Telegram.
///
/// Подробнее см. `Sources/TDLibAdapter/README.md`
public final class TDLibClient: @unchecked Sendable {
    private var client: UnsafeMutableRawPointer?
    private let appLogger: Logger
    private var parametersSet = false
    private let authorizationPollTimeout: Double

    /// Инициализирует TDLib клиент.
    ///
    /// - Parameters:
    ///   - appLogger: Логгер для событий приложения
    ///   - authorizationPollTimeout: Таймаут для polling обновлений от TDLib во время авторизации (в секундах).
    ///                               По умолчанию 1.0 секунда. Увеличение значения снижает CPU нагрузку,
    ///                               но увеличивает время отклика на состояния авторизации.
    public init(appLogger: Logger, authorizationPollTimeout: Double = 1.0) {
        self.appLogger = appLogger
        self.authorizationPollTimeout = authorizationPollTimeout
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
                await self.receiveLoop(config: config, promptFor: promptFor, onReady: {
                    continuation.resume()
                })
            }
        }
    }

    /// Отправляет запрос в TDLib.
    ///
    /// - Parameter json: JSON-объект с обязательным полем `@type`
    public func send(_ json: [String: Any]) {
        guard let client else {
            appLogger.error("Cannot send: client is nil")
            return
        }
        let data = try! JSONSerialization.data(withJSONObject: json)
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

    private func receiveLoop(config: TDConfig,
                             promptFor: @escaping @Sendable (AuthenticationPrompt) async -> String,
                             onReady: @escaping @Sendable () -> Void) async {
        // Kickstart: request current auth state
        send(["@type":"getAuthorizationState"])

        while true {
            guard let obj = receive(timeout: authorizationPollTimeout) else {
                await Task.yield()
                continue
            }
            guard let type = obj["@type"] as? String else {
                appLogger.warning("Received object without @type")
                await Task.yield()
                continue
            }

            // Не логируем обычные обновления (только ошибки)

            // Логируем ошибки от TDLib
            if type == "error" {
                let code = obj["code"] as? Int ?? 0
                let message = obj["message"] as? String ?? "unknown"
                appLogger.error("TDLib error [\(code)]: \(message)")
                continue
            }

            // Обрабатываем состояния авторизации
            let authState: [String: Any]?
            let stType: String?

            if type == "updateAuthorizationState" {
                authState = obj["authorization_state"] as? [String:Any]
                stType = authState?["@type"] as? String
            } else if type.hasPrefix("authorizationState") {
                // Прямой ответ на getAuthorizationState
                authState = obj
                stType = type
            } else {
                authState = nil
                stType = nil
            }

            if let stType = stType {
                appLogger.info("Authorization state: \(stType)")

                if stType == "authorizationStateWaitTdlibParameters" {
                    if !parametersSet {
                        appLogger.info("Setting TDLib parameters...")
                        // TDLib >= 1.8.6 требует inline параметры (без вложенного объекта parameters)
                        let request: [String: Any] = [
                            "@type": "setTdlibParameters",
                            "use_test_dc": false,
                            "database_directory": config.stateDir + "/db",
                            "files_directory": config.stateDir + "/files",
                            "use_file_database": true,
                            "use_chat_info_database": true,
                            "use_message_database": true,
                            "use_secret_chats": false,
                            "api_id": config.apiId,
                            "api_hash": config.apiHash,
                            "system_language_code": "en",
                            "device_model": "macOS",
                            "application_version": "0.1.0",
                            "enable_storage_optimizer": true,
                            "ignore_file_names": false
                        ]
                        send(request)
                        parametersSet = true
                        appLogger.info("TDLib parameters sent")
                    } else {
                        appLogger.info("TDLib parameters already set, skipping...")
                    }

                } else if stType == "authorizationStateWaitEncryptionKey" {
                    appLogger.info("Setting encryption key (empty for no encryption)...")
                    send(["@type": "checkDatabaseEncryptionKey", "encryption_key": ""])
                    appLogger.info("Encryption key sent")

                } else if stType == "authorizationStateWaitPhoneNumber" {
                    appLogger.info("Requesting phone number...")
                    let phone = await promptFor(.phoneNumber)
                    appLogger.info("Phone number received: \(phone)")
                    send(["@type":"setAuthenticationPhoneNumber","phone_number":phone])
                    appLogger.info("Phone number sent to TDLib")

                } else if stType == "authorizationStateWaitCode" {
                    let code = await promptFor(.verificationCode)
                    send(["@type":"checkAuthenticationCode","code":code])

                } else if stType == "authorizationStateWaitPassword" {
                    let pwd = await promptFor(.twoFactorPassword)
                    send(["@type":"checkAuthenticationPassword","password":pwd])

                } else if stType == "authorizationStateReady" {
                    self.appLogger.info("TDLib authorization READY")
                    onReady()
                    return

                } else if stType == "authorizationStateClosed" {
                    self.appLogger.info("TDLib closed"); return
                }
            }

            // Позволяем другим Task выполняться
            await Task.yield()
        }
    }
}
