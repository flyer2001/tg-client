import TgClientModels
import Foundation
import Logging
import TDLibAdapter
import DigestCore
import FoundationExtensions

@main
struct TGClient {
    /// Читает ввод пользователя с промптом (курсор остаётся на той же строке)
    static func readLineSecure(message: String) -> String {
        print(message, terminator: "")
        return readLine() ?? ""
    }

    static func main() async {
        // Загрузка .env файла (если существует)
        try? EnvFileLoader.loadDotEnv()

        // Настройка логгера: только warning, error, critical
        var logger = Logger(label: "tg-client")
        logger.logLevel = .warning

        let env = ProcessInfo.processInfo.environment
        let apiId = env["TELEGRAM_API_ID"].flatMap { Int32($0) } ?? 0
        let apiHash = env["TELEGRAM_API_HASH"] ?? ""
        let stateDir = env["TDLIB_STATE_DIR"] ?? FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".tdlib").path
        let databaseEncryptionKey = env["TDLIB_DATABASE_ENCRYPTION_KEY"] ?? ""
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
            logPath: stateDir + "/tdlib.log",
            databaseEncryptionKey: databaseEncryptionKey
        )

        // ВАЖНО: Настройка TDLib логирования должна быть ДО создания клиента
        TDLibClient.configureTDLibLogging(config: config)

        let td = TDLibClient(appLogger: logger)

        // Запускаем авторизацию и ждём её завершения
        do {
            try await td.start(config: config) { promptType in
                switch promptType {
                case .phoneNumber:
                    return readLineSecure(message: "Phone (E.164, e.g. +31234567890): ")
                case .verificationCode:
                    return readLineSecure(message: "Code: ")
                case .twoFactorPassword:
                    return readLineSecure(message: "2FA Password: ")
                }
            }
        } catch {
            print("⚠️ Failed to start TDLib client: \(error)")
            exit(1)
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

        // 🧪 Test ChannelMessageSource.fetchUnreadMessages()
        print("\n🧪 Testing ChannelMessageSource.fetchUnreadMessages()...")

        // Настраиваем logger для ChannelMessageSource (показываем всё)
        var channelLogger = Logger(label: "ChannelMessageSource")
        channelLogger.logLevel = .info

        let messageSource = ChannelMessageSource(
            tdlib: td,
            logger: channelLogger,
            loadChatsPaginationDelay: .seconds(2),
            updatesCollectionTimeout: .seconds(5),
            maxParallelHistoryRequests: 5,
            maxLoadChatsBatches: 20
        )

        let messages: [SourceMessage]
        do {
            messages = try await messageSource.fetchUnreadMessages()

            print("\n✅ fetchUnreadMessages() completed!")
            print("   Total messages: \(messages.count)")

            // Группируем по каналам
            let messagesByChannel = Dictionary(grouping: messages) { $0.channelTitle }
            print("   Channels with unread: \(messagesByChannel.count)")

            // Показываем топ-3 канала
            let top3 = messagesByChannel.sorted { $0.value.count > $1.value.count }.prefix(3)
            if !top3.isEmpty {
                print("\n   📊 Top 3 channels by unread count:")
                for (idx, (title, msgs)) in top3.enumerated() {
                    print("   \(idx + 1). \(title): \(msgs.count) messages")
                }
            }
        } catch {
            print("   ⚠️ Failed to fetch unread messages: \(error)")
            exit(1)
        }

        // 🧪 Test DigestOrchestrator + OpenAISummaryGenerator (v0.3.0 pipeline)
        print("\n🧪 Testing DigestOrchestrator.generateDigest()...")

        guard !messages.isEmpty else {
            print("   ℹ️  No unread messages to generate digest. Skipping.")
            print("\n✅ All tests completed successfully!")
            return
        }

        // Проверяем OPENAI_API_KEY
        guard let openaiKey = env["OPENAI_API_KEY"], !openaiKey.isEmpty else {
            print("   ⚠️  OPENAI_API_KEY not found. Skipping digest generation.")
            print("   Set OPENAI_API_KEY in .env file to test AI digest.")
            print("\n✅ All tests completed successfully!")
            return
        }

        var digestLogger = Logger(label: "DigestOrchestrator")
        digestLogger.logLevel = .info

        let httpClient = URLSessionHTTPClient()
        let summaryGenerator = OpenAISummaryGenerator(apiKey: openaiKey, httpClient: httpClient, logger: digestLogger)
        let orchestrator = DigestOrchestrator(summaryGenerator: summaryGenerator, logger: digestLogger)

        do {
            let digest = try await orchestrator.generateDigest(from: messages)

            print("\n✅ Digest generated successfully!")
            print("   Length: \(digest.count) chars")
            print("\n" + String(repeating: "=", count: 60))
            print(digest)
            print(String(repeating: "=", count: 60))
        } catch {
            print("   ⚠️ Failed to generate digest: \(error)")
            exit(1)
        }

        print("\n✅ All tests completed successfully!")
    }
}
