import Foundation
import Logging
import TDLibAdapter

@main
struct TGClient {
    /// Читает ввод пользователя с промптом (курсор остаётся на той же строке)
    static func readLineSecure(message: String) -> String {
        print(message, terminator: "")
        return readLine() ?? ""
    }

    static func main() async {
        // Настройка логгера: только ошибки в stderr
        var logger = Logger(label: "tg-client")
        logger.logLevel = .error

        let env = ProcessInfo.processInfo.environment
        let apiId = env["TELEGRAM_API_ID"].flatMap { Int32($0) } ?? 0
        let apiHash = env["TELEGRAM_API_HASH"] ?? ""
        let stateDir = env["TDLIB_STATE_DIR"] ?? FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".tdlib").path
        try? FileManager.default.createDirectory(atPath: stateDir, withIntermediateDirectories: true)

        guard apiId > 0, !apiHash.isEmpty else {
            // Вывод ошибки в stderr (отдельный поток для ошибок, не буферизуется)
            // exit(2) - завершение с кодом 2 (ошибка конфигурации)
            FileHandle.standardError.write(Data("Set TELEGRAM_API_ID and TELEGRAM_API_HASH in environment.\n".utf8))
            exit(2)
        }

        let config = TDConfig(
            apiId: apiId,
            apiHash: apiHash,
            stateDir: stateDir,
            logPath: stateDir + "/tdlib.log"
        )

        // ВАЖНО: Настройка TDLib логирования должна быть ДО создания клиента
        TDLibClient.configureTDLibLogging(config: config)

        let td = TDLibClient(appLogger: logger)

        // Запускаем авторизацию и ждём её завершения
        await td.start(config: config) { promptType in
            switch promptType {
            case .phoneNumber:
                return readLineSecure(message: "Phone (E.164, e.g. +31234567890): ")
            case .verificationCode:
                return readLineSecure(message: "Code: ")
            case .twoFactorPassword:
                return readLineSecure(message: "2FA Password: ")
            }
        }

        // Верификация: запросим текущего пользователя
        td.send(GetMeRequest())

        // Подождём и выведем ответ
        let started = Date()
        while Date().timeIntervalSince(started) < 5 {
            if let obj = td.receive(timeout: 0.5), let type = obj["@type"] as? String {
                if type == "user" {
                    let name = (obj["first_name"] as? String ?? "") + " " + (obj["last_name"] as? String ?? "")
                    print("✅ Authorized as: \(name.trimmingCharacters(in: .whitespaces)) (id: \(obj["id"] ?? "?"))")
                    exit(0)
                }
            }
        }
        print("⚠️ Authorized, but 'getMe' didn't return within timeout.")
    }
}
