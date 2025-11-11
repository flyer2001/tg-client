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
        do {
            let user = try await td.getMe()
            let name = (user.firstName + " " + user.lastName).trimmingCharacters(in: .whitespaces)
            print("✅ Authorized as: \(name) (id: \(user.id))")
        } catch {
            print("⚠️ Failed to get user info: \(error)")
            exit(1)
        }

        // Manual test: loadChats + getChat
        do {
            print("\n📋 Manual test: loadChats")
            _ = try await td.loadChats(chatList: .main, limit: 100)
            print("✅ loadChats: Ok")

            print("\n📋 Manual test: getChats (first 3 IDs)")
            let chats = try await td.getChats(chatList: .main, limit: 3)
            print("✅ getChats: \(chats.chatIds.count) chat IDs")

            if let firstChatId = chats.chatIds.first {
                print("\n📋 Manual test: getChat(chatId: \(firstChatId))")
                let chat = try await td.getChat(chatId: firstChatId)
                print("✅ getChat:")
                print("   Title: \(chat.title)")
                print("   Type: \(chat.chatType)")
                print("   Unread: \(chat.unreadCount)")
                print("   LastRead: \(chat.lastReadInboxMessageId)")
            }

            print("\n✅ All manual tests passed!")
        } catch {
            print("⚠️ Manual test failed: \(error)")
            exit(1)
        }
    }
}
