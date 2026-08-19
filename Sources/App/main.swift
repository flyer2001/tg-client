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

        // Парсим режим из CLI: oneshot (default), service или dump
        let args = Array(CommandLine.arguments.dropFirst())
        let mode: RunMode
        if args.contains("service") {
            mode = .service
        } else if args.first == "send" {
            guard args.count >= 3 else {
                FileHandle.standardError.write(Data("Usage: tg-client send <@bot_username> <blocks.txt>\n".utf8))
                exit(2)
            }
            mode = .send(username: args[1], input: args[2])
        } else if args.first == "dump" {
            guard args.count >= 2 else {
                FileHandle.standardError.write(Data("Usage: tg-client dump <@bot_username> [output.jsonl]\n".utf8))
                exit(2)
            }
            let output = args.count >= 3 ? args[2] : "/root/dumps/\(args[1].trimmingCharacters(in: CharacterSet(charactersIn: "@"))).jsonl"
            mode = .dump(username: args[1], output: output)
        } else {
            mode = .oneshot
        }

        var logger = Logger(label: "tg-client")
        logger.logLevel = mode == .oneshot ? .warning : .info

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
                case .oneshot, .dump, .send:
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
        case .dump(let username, let output):
            await runDump(td: td, username: username, output: output, logger: logger)
        case .send(let username, let input):
            await runSend(td: td, username: username, input: input, logger: logger)
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

    // MARK: - Dump mode (полная выгрузка истории одного чата в JSONL)

    /// Выгружает всю переписку с ботом/пользователем в JSONL.
    ///
    /// **Приватность:** тексты сообщений не печатаются — только счётчики и диапазон дат.
    private static func runDump(td: TDLibClient, username: String, output: String, logger: Logger) async {
        let handle = username.hasPrefix("@") ? String(username.dropFirst()) : username

        let chat: ChatResponse
        do {
            chat = try await td.searchPublicChat(username: handle)
        } catch {
            print("⚠️ Чат @\(handle) не найден: \(error)")
            exit(1)
        }

        let url = URL(fileURLWithPath: output)
        try? FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )

        print("📥 Выгружаю историю чата \(chat.id) → \(output)")

        do {
            let stats = try await dumpChatHistory(
                chatId: chat.id,
                to: url,
                logger: logger
            ) { fromMessageId, limit in
                try await td.getChatHistory(
                    chatId: chat.id,
                    fromMessageId: fromMessageId,
                    offset: 0,
                    limit: limit
                ).messages
            }

            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd"
            let oldest = stats.oldestDate.map { formatter.string(from: Date(timeIntervalSince1970: TimeInterval($0))) } ?? "—"
            let newest = stats.newestDate.map { formatter.string(from: Date(timeIntervalSince1970: TimeInterval($0))) } ?? "—"
            let bytes = ((try? FileManager.default.attributesOfItem(atPath: output))?[.size] as? Int) ?? 0

            print("✅ Готово: \(stats.messageCount) сообщений (текст \(stats.textCount), прочее \(stats.otherCount))")
            print("   Период: \(oldest) … \(newest), запросов: \(stats.pages), файл: \(bytes) байт")
        } catch {
            print("⚠️ Выгрузка упала: \(error)")
            exit(1)
        }
    }

    // MARK: - Send mode (отправка подготовленного документа боту чанками)

    /// Читает документ (блоки через `===`), режет под лимит Telegram и шлёт по очереди.
    ///
    /// Пауза между сообщениями — `TG_SEND_DELAY_SECONDS` (default 7) — защита от flood wait
    /// и время боту прожевать. Прогресс в `<input>.sent` (номер последнего успешного чанка):
    /// после обрыва перезапуск той же командой продолжает со следующего.
    private static func runSend(td: TDLibClient, username: String, input: String, logger: Logger) async {
        let handle = username.hasPrefix("@") ? String(username.dropFirst()) : username
        let delaySeconds = ProcessInfo.processInfo.environment["TG_SEND_DELAY_SECONDS"].flatMap { Int($0) } ?? 7

        guard let document = try? String(contentsOfFile: input, encoding: .utf8) else {
            print("⚠️ Не могу прочитать файл \(input)")
            exit(1)
        }
        let chunks = splitIntoTelegramChunks(document: document)
        guard !chunks.isEmpty else {
            print("⚠️ Файл пуст — отправлять нечего")
            exit(1)
        }

        // Resume: в .sent лежит количество уже отправленных чанков
        let progressPath = input + ".sent"
        let alreadySent = (try? String(contentsOfFile: progressPath, encoding: .utf8))
            .flatMap { Int($0.trimmingCharacters(in: .whitespacesAndNewlines)) } ?? 0
        if alreadySent >= chunks.count {
            print("✅ Все \(chunks.count) чанков уже отправлены ранее (\(progressPath)). Для повторной отправки удали этот файл.")
            return
        }
        if alreadySent > 0 {
            print("▶️ Продолжаю с чанка \(alreadySent + 1)/\(chunks.count) (по \(progressPath))")
        }

        let chat: ChatResponse
        do {
            chat = try await td.searchPublicChat(username: handle)
        } catch {
            print("⚠️ Чат @\(handle) не найден: \(error)")
            exit(1)
        }

        print("📤 Отправляю \(chunks.count - alreadySent) сообщений в чат \(chat.id), пауза \(delaySeconds) сек...")
        for (index, chunk) in chunks.enumerated() where index >= alreadySent {
            do {
                _ = try await td.sendMessage(chatId: chat.id, text: chunk)
                try? "\(index + 1)\n".write(toFile: progressPath, atomically: true, encoding: .utf8)
                print("   \(index + 1)/\(chunks.count) отправлено (\(chunk.count) символов)")
            } catch {
                print("⚠️ Чанк \(index + 1)/\(chunks.count) не отправился: \(error)")
                print("   Успешно: \(index). Перезапусти ту же команду — продолжит с чанка \(index + 1).")
                exit(1)
            }
            // Пауза и после последнего чанка: иначе выход убивает TDLib до того,
            // как сообщение реально улетит на сервер (висит в "отправляется").
            // ponytail: sleep вместо ожидания updateMessageSendSucceeded; менять если 7 сек перестанет хватать
            try? await Task.sleep(for: .seconds(Int64(delaySeconds)))
        }
        print("✅ Все \(chunks.count) сообщений отправлены")
    }

    enum RunMode: Equatable {
        case oneshot
        case service
        case dump(username: String, output: String)
        case send(username: String, input: String)
    }
}
