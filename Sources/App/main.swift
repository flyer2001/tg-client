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

        // Верификация: запросим текущего пользователя через высокоуровневый API
        let user: UserResponse
        do {
            user = try await td.getMe()
            let name = (user.firstName + " " + user.lastName).trimmingCharacters(in: .whitespaces)
            print("✅ Authorized as: \(name) (id: \(user.id))")
        } catch {
            print("⚠️ Failed to get user info: \(error)")
            exit(1)
        }

        // 🧪 Test getChatHistory() - используем Saved Messages (chatId = userId)
        print("\n🧪 Testing getChatHistory()...")
        print("   Using Saved Messages (chatId = \(user.id))...")

        do {
            // Получаем последние 10 сообщений из Saved Messages
            let messages = try await td.getChatHistory(
                chatId: user.id,
                fromMessageId: 0,
                offset: 0,
                limit: 10
            )

            print("   ✅ Received \(messages.messages.count) messages")

            // Показываем первые 3 сообщения
            if messages.messages.isEmpty {
                print("   ℹ️ No messages in Saved Messages")
            } else {
                print("\n   📋 Sample messages:")
                for (idx, message) in messages.messages.prefix(3).enumerated() {
                    let preview: String
                    switch message.content {
                    case .text(let text):
                        preview = text.text.prefix(50).description
                    case .unsupported:
                        preview = "[unsupported]"
                    }
                    print("   \(idx + 1). Message \(message.id): \(preview)")
                }
            }
        } catch {
            print("   ⚠️ Failed to get chat history: \(error)")
            exit(1)
        }

        print("\n✅ All tests completed successfully!")
    }
}
