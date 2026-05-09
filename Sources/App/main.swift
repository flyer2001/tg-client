import TgClientModels
import Foundation
import Logging
import TDLibAdapter
import DigestCore
import BotBridge
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

        // Парсим режим из CLI: oneshot (default) или service
        let args = CommandLine.arguments.dropFirst()
        let mode: RunMode = args.contains("service") ? .service : .oneshot

        var logger = Logger(label: "tg-client")
        logger.logLevel = mode == .service ? .info : .warning

        let env = ProcessInfo.processInfo.environment
        let apiId = env["TELEGRAM_API_ID"].flatMap { Int32($0) } ?? 0
        let apiHash = env["TELEGRAM_API_HASH"] ?? ""
        let stateDir = env["TDLIB_STATE_DIR"] ?? FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".tdlib").path
        try? FileManager.default.createDirectory(atPath: stateDir, withIntermediateDirectories: true)

        guard apiId > 0, !apiHash.isEmpty else {
            FileHandle.standardError.write(Data("Set TELEGRAM_API_ID and TELEGRAM_API_HASH in environment.\n".utf8))
            exit(2)
        }

        let config = TDConfig(
            apiId: apiId,
            apiHash: apiHash,
            stateDir: stateDir,
            logPath: stateDir + "/tdlib.log"
        )

        // ВАЖНО: настройка TDLib логирования должна быть ДО создания клиента
        TDLibClient.configureTDLibLogging(config: config)

        let td = TDLibClient(appLogger: logger)

        // Авторизация: интерактив доступен только в oneshot. В service mode неинтерактивно
        // (предполагаем что oneshot уже был запущен ранее и сессия в stateDir сохранена).
        do {
            try await td.start(config: config) { promptType in
                switch mode {
                case .oneshot:
                    switch promptType {
                    case .phoneNumber:
                        return readLineSecure(message: "Phone (E.164, e.g. +31234567890): ")
                    case .verificationCode:
                        return readLineSecure(message: "Code: ")
                    case .twoFactorPassword:
                        return readLineSecure(message: "2FA Password: ")
                    }
                case .service:
                    FileHandle.standardError.write(Data(
                        "TDLib запросил \(promptType) — service mode неинтерактивен. Запусти 'tg-client' (без аргумента) для первичной авторизации.\n".utf8
                    ))
                    exit(3)
                }
            }
        } catch {
            print("⚠️ Failed to start TDLib client: \(error)")
            exit(1)
        }

        // Верификация авторизации
        do {
            let user = try await td.getMe()
            let name = (user.firstName + " " + user.lastName).trimmingCharacters(in: .whitespaces)
            logger.info("Authorized as \(name) (id: \(user.id))")
            if mode == .oneshot {
                print("✅ Authorized as: \(name) (id: \(user.id))")
            }
        } catch {
            print("⚠️ Failed to get user info: \(error)")
            exit(1)
        }

        switch mode {
        case .oneshot:
            await runOneshot(td: td, env: env, logger: logger)
        case .service:
            await runService(td: td, logger: logger)
        }
    }

    // MARK: - Oneshot mode (CLI for debug, manual auth, cron)

    private static func runOneshot(td: TDLibClient, env: [String: String], logger: Logger) async {
        print("\n🧪 Testing ChannelMessageSource.fetchUnreadMessages()...")

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

            let messagesByChannel = Dictionary(grouping: messages) { $0.channelTitle }
            print("   Channels with unread: \(messagesByChannel.count)")

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

        print("\n🧪 Testing DigestOrchestrator.generateDigest()...")
        guard !messages.isEmpty else {
            print("   ℹ️  No unread messages to generate digest. Skipping.")
            print("\n✅ All tests completed successfully!")
            return
        }

        guard let openaiKey = env["OPENAI_API_KEY"], !openaiKey.isEmpty else {
            print("   ⚠️  OPENAI_API_KEY not found. Skipping digest generation.")
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

    // MARK: - Service mode (long-running, VK webhook bridge)

    private static func runService(td: TDLibClient, logger: Logger) async {
        let botConfig: BotBridgeConfig
        do {
            botConfig = try BotBridgeConfig.fromEnvironment()
        } catch {
            FileHandle.standardError.write(Data("BotBridge config: \(error)\n".utf8))
            exit(2)
        }

        var sourceLogger = Logger(label: "ChannelMessageSource")
        sourceLogger.logLevel = .info

        let messageSource = ChannelMessageSource(tdlib: td, logger: sourceLogger)
        let httpClient = URLSessionHTTPClient()
        let vkClient = VKAPIClient(
            token: botConfig.vkBotToken,
            apiVersion: botConfig.vkApiVersion,
            httpClient: httpClient,
            logger: Logger(label: "VKAPIClient")
        )

        let processor = CommandProcessor(
            messageSource: messageSource,
            tdlib: td,
            vkClient: vkClient,
            allowedOwners: botConfig.vkBotOwnerIds,
            logger: Logger(label: "CommandProcessor")
        )

        let webhookHandler = VKWebhookHandler(
            config: botConfig,
            processor: processor,
            logger: Logger(label: "VKWebhookHandler")
        )

        let server = BotBridgeServer(
            config: botConfig,
            webhookHandler: webhookHandler,
            logger: Logger(label: "BotBridgeServer")
        )

        logger.info("Service mode: BotBridge starting on \(botConfig.httpHost):\(botConfig.httpPort)")

        do {
            try await server.run()
        } catch {
            logger.error("BotBridge server failed: \(error)")
            exit(1)
        }
    }

    enum RunMode {
        case oneshot
        case service
    }
}
