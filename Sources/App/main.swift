import Foundation
import Logging
import TDLibAdapter

@main
struct TGClient {
    static func readLineSecure(prompt: String) -> String {
        FileHandle.standardOutput.write(Data((prompt).utf8))
        fflush(stdout)
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
            fputs("Set TELEGRAM_API_ID and TELEGRAM_API_HASH in environment.\n", stderr)
            exit(2)
        }

        let td = TDLibClient(logger: logger)

        let phoneProvider: @Sendable () async -> String = { readLineSecure(prompt: "Phone (E.164, e.g. +31234567890): ") }
        let codeProvider: @Sendable () async -> String = { readLineSecure(prompt: "Code: ") }
        let passProvider: @Sendable () async -> String = { readLineSecure(prompt: "2FA Password: ") }

        // Запускаем авторизацию и ждём её завершения
        await td.start(config: .init(apiId: apiId, apiHash: apiHash, stateDir: stateDir, logPath: stateDir + "/tdlib.log"),
                       askPhone: phoneProvider,
                       askCode: codeProvider,
                       askPassword: passProvider)

        // Верификация: запросим текущего пользователя
        td.send(["@type":"getMe"])

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
