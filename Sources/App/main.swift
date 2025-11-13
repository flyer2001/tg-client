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

        // 🧪 Experiment: loadChats pagination with updates stream
        print("\n🧪 Starting loadChats pagination experiment...")
        print("   Strategy: loadChats() + 2 sec timeout")
        print("   Goal: Load ALL chats and measure timing\n")

        let startTime = Date()
        var allChats: [ChatResponse] = []
        var loadChatsCallCount = 0
        var lastBatchSize = 0

        // Task 1: Listen to updates stream (background)
        let updatesTask = Task {
            var updateCount = 0
            for await update in td.updates {
                if case .newChat(let chat) = update {
                    allChats.append(chat)
                    updateCount += 1
                    lastBatchSize += 1

                    // Логируем каждый 50-й чат для прогресса
                    if updateCount % 50 == 0 {
                        let elapsed = Date().timeIntervalSince(startTime)
                        print("   📥 Updates: \(updateCount) chats received (elapsed: \(String(format: "%.1f", elapsed))s)")
                    }
                }
            }
        }

        // Task 2: Call loadChats() in loop with 2 sec timeout
        do {
            while true {
                loadChatsCallCount += 1
                let callStartTime = Date()

                print("🔄 loadChats() call #\(loadChatsCallCount) (total chats: \(allChats.count))...")

                do {
                    _ = try await td.loadChats(chatList: .main, limit: 100)
                    let callElapsed = Date().timeIntervalSince(callStartTime)
                    print("   ✅ Ok (took \(String(format: "%.3f", callElapsed))s)")

                    // Wait 2 seconds for updates to arrive
                    print("   ⏳ Waiting 2 sec for updates...")
                    try await Task.sleep(for: .seconds(2))
                    print("   ✅ Batch: +\(lastBatchSize) chats (total: \(allChats.count))")
                    lastBatchSize = 0

                } catch let error as TDLibErrorResponse where error.isAllChatsLoaded {
                    let totalElapsed = Date().timeIntervalSince(startTime)
                    print("\n✅ All chats loaded!")
                    print("\n📊 Statistics:")
                    print("   Total chats: \(allChats.count)")
                    print("   loadChats() calls: \(loadChatsCallCount)")
                    print("   Total time: \(String(format: "%.1f", totalElapsed))s")
                    print("   Avg per call: \(String(format: "%.2f", totalElapsed / Double(loadChatsCallCount)))s")

                    // Wait for remaining updates (if any)
                    print("\n⏳ Waiting 3 sec for remaining updates...")
                    try await Task.sleep(for: .seconds(3))
                    print("   Final count: \(allChats.count) chats")

                    // Show sample chats
                    print("\n📋 Sample chats (first 5):")
                    for (idx, chat) in allChats.prefix(5).enumerated() {
                        print("   \(idx + 1). \(chat.title) (type: \(chat.chatType), unread: \(chat.unreadCount))")
                    }

                    updatesTask.cancel()
                    break
                }
            }
        } catch {
            print("⚠️ Experiment failed: \(error)")
            updatesTask.cancel()
            exit(1)
        }

        print("\n✅ Experiment completed successfully!")
    }
}
