import Foundation
import CTDLib
import Logging

public struct TDConfig: Sendable {
    public let apiId: Int32
    public let apiHash: String
    public let stateDir: String
    public let logPath: String
    public init(apiId: Int32, apiHash: String, stateDir: String, logPath: String) {
        self.apiId = apiId; self.apiHash = apiHash; self.stateDir = stateDir; self.logPath = logPath
    }
}

public final class TDLibClient: @unchecked Sendable {
    private var client: UnsafeMutableRawPointer?
    private let logger: Logger
    private var parametersSet = false

    public init(logger: Logger) { self.logger = logger }

    deinit { if let c = client { td_json_client_destroy(c) } }

    public func start(config: TDConfig,
                      askPhone: @escaping @Sendable () async -> String,
                      askCode: @escaping @Sendable () async -> String,
                      askPassword: @escaping @Sendable () async -> String) async {
        // Настройка логирования до создания клиента через синхронный API
        // См. https://core.telegram.org/tdlib/docs/classtd_1_1td__api_1_1set_log_verbosity_level.html
        _ = td_execute("{\"@type\":\"setLogVerbosityLevel\",\"new_verbosity_level\":0}")

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

        client = td_json_client_create()

        // run receive loop in background Task
        await withCheckedContinuation { continuation in
            Task {
                await self.receiveLoop(config: config, askPhone: askPhone, askCode: askCode, askPassword: askPassword, onReady: {
                    continuation.resume()
                })
            }
        }
    }

    public func send(_ json: [String: Any]) {
        guard let client else {
            logger.error("Cannot send: client is nil")
            return
        }
        let data = try! JSONSerialization.data(withJSONObject: json)
        data.withUnsafeBytes { raw in
            let s = String(decoding: raw.bindMemory(to: UInt8.self), as: UTF8.self)
            td_json_client_send(client, s)
        }
    }

    public func receive(timeout: Double) -> [String: Any]? {
        guard let client, let cstr = td_json_client_receive(client, timeout) else { return nil }
        let json = String(cString: cstr)
        return (try? JSONSerialization.jsonObject(with: Data(json.utf8))) as? [String: Any]
    }

    private func receiveLoop(config: TDConfig,
                             askPhone: @escaping @Sendable () async -> String,
                             askCode: @escaping @Sendable () async -> String,
                             askPassword: @escaping @Sendable () async -> String,
                             onReady: @escaping @Sendable () -> Void) async {
        // Kickstart: request current auth state
        send(["@type":"getAuthorizationState"])

        while true {
            guard let obj = receive(timeout: 1.0) else {
                await Task.yield()
                continue
            }
            guard let type = obj["@type"] as? String else {
                logger.warning("Received object without @type")
                await Task.yield()
                continue
            }

            // Не логируем обычные обновления (только ошибки)

            // Логируем ошибки от TDLib
            if type == "error" {
                let code = obj["code"] as? Int ?? 0
                let message = obj["message"] as? String ?? "unknown"
                logger.error("TDLib error [\(code)]: \(message)")
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
                logger.info("Authorization state: \(stType)")

                if stType == "authorizationStateWaitTdlibParameters" {
                    if !parametersSet {
                        logger.info("Setting TDLib parameters...")
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
                        logger.info("TDLib parameters sent")
                    } else {
                        logger.info("TDLib parameters already set, skipping...")
                    }

                } else if stType == "authorizationStateWaitEncryptionKey" {
                    logger.info("Setting encryption key (empty for no encryption)...")
                    send(["@type": "checkDatabaseEncryptionKey", "encryption_key": ""])
                    logger.info("Encryption key sent")

                } else if stType == "authorizationStateWaitPhoneNumber" {
                    logger.info("Requesting phone number...")
                    let phone = await askPhone()
                    logger.info("Phone number received: \(phone)")
                    send(["@type":"setAuthenticationPhoneNumber","phone_number":phone])
                    logger.info("Phone number sent to TDLib")

                } else if stType == "authorizationStateWaitCode" {
                    let code = await askCode()
                    send(["@type":"checkAuthenticationCode","code":code])

                } else if stType == "authorizationStateWaitPassword" {
                    let pwd = await askPassword()
                    send(["@type":"checkAuthenticationPassword","password":pwd])

                } else if stType == "authorizationStateReady" {
                    self.logger.info("TDLib authorization READY")
                    onReady()
                    return

                } else if stType == "authorizationStateClosed" {
                    self.logger.info("TDLib closed"); return
                }
            }

            // Позволяем другим Task выполняться
            await Task.yield()
        }
    }
}
