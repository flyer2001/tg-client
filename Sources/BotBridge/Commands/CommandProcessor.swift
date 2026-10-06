import Foundation
import Logging
import TgClientModels
import DigestCore

/// Обработчик команд от пользователя VK.
///
/// **Гарантии:**
/// - Whitelist: только `from_id ∈ allowedOwners` → исполнение, остальные молча игнорируются.
/// - Concurrent guard: если предыдущая команда ещё выполняется → отказываем "уже занят".
/// - Все ошибки логируются, наружу не пробрасываются (webhook должен всегда отвечать `"ok"`).
///
/// **Команды:**
/// - `/test` — диагностика (TDLib статус, версия, uptime)
/// - `/digest` — построить меню непрочитанных (группированное по типу чата)
/// - `/get N` — забрать сообщения чата N из последнего меню
/// - `/get all` — забрать сообщения всех чатов из меню (старое поведение `/digest`)
/// - `/get channels|groups|dm` — забрать конкретную категорию из меню
/// - `/last N [count]` — последние `count` сообщений (включая прочитанные) чата N (default count=5)
/// - `/reply N <text>` — отправить ответ в чат N от имени пользователя
public actor CommandProcessor {
    private let messageSource: ChannelMessageSource
    private let tdlib: any TDLibClientProtocol
    private let vkClient: VKAPIClient
    private let allowedOwners: Set<Int>
    private let sessionState: BotSessionState
    private let logger: Logger
    private let startedAt: Date

    private var isBusy: Bool = false

    public init(
        messageSource: ChannelMessageSource,
        tdlib: any TDLibClientProtocol,
        vkClient: VKAPIClient,
        allowedOwners: Set<Int>,
        logger: Logger,
        sessionState: BotSessionState = BotSessionState(),
        startedAt: Date = Date()
    ) {
        self.messageSource = messageSource
        self.tdlib = tdlib
        self.vkClient = vkClient
        self.allowedOwners = allowedOwners
        self.sessionState = sessionState
        self.logger = logger
        self.startedAt = startedAt
    }

    /// Обрабатывает входящее VK сообщение.
    public func handle(message: VKMessage) async {
        let fromId = Int(message.fromId)

        guard allowedOwners.contains(fromId) else {
            logger.info("Ignoring message from non-owner", metadata: [
                "from_id": .stringConvertible(fromId),
                "text": .string(message.text.prefix(100).description)
            ])
            return
        }

        let cmd = parseCommand(message.text)
        logger.info("Command received", metadata: [
            "from_id": .stringConvertible(fromId),
            "command": .string(cmd.summary),
            "peer_id": .stringConvertible(message.peerId)
        ])

        if isBusy {
            await reply(to: message.peerId, text: "⚠️ Уже обрабатываю предыдущую команду, подожди.")
            return
        }
        isBusy = true
        defer { isBusy = false }

        switch cmd {
        case .digest:
            await runDigestMenu(peerId: message.peerId)
        case .test:
            await runTest(peerId: message.peerId)
        case .getByIndex(let n):
            await runGetByIndex(peerId: message.peerId, index: n)
        case .getAll:
            await runGetChats(peerId: message.peerId, chats: await sessionState.resolveAll(), label: "все")
        case .getCategory(let kind):
            let chats = await sessionState.resolveByKind(kind)
            await runGetChats(peerId: message.peerId, chats: chats, label: kind.displayName.lowercased())
        case .lastByIndex(let n, let count):
            await runLastByIndex(peerId: message.peerId, index: n, count: count)
        case .replyByIndex(let n, let text):
            await runReplyByIndex(peerId: message.peerId, index: n, text: text)
        case .toUsername(let username, let text):
            await runToUsername(peerId: message.peerId, username: username, text: text)
        case .readByIndex(let n):
            await runReadByIndex(peerId: message.peerId, index: n)
        case .unknown(let raw):
            await reply(to: message.peerId, text: helpText(unknown: raw))
        }
    }

    private func helpText(unknown: String) -> String {
        return """
        🤔 Не знаю команду '\(unknown)'.

        Доступно:
        /digest — меню непрочитанных
        /get N — взять чат N
        /get all|channels|groups|dm — категория
        /last N [count] — последние сообщения чата N (default count=5)
        /reply N <text> — ответить в чат N
        /to <username> <text> — отправить @username
        /to_alena <text> — alias для @alenoch13
        /read N — пометить чат N как прочитанный
        /test — диагностика
        """
    }

    // MARK: - Command implementations

    private func runDigestMenu(peerId: Int64) async {
        await reply(to: peerId, text: "⏳ Собираю список непрочитанных… 5-30 сек.")

        let chats: [UnreadChatInfo]
        do {
            chats = try await messageSource.fetchUnreadChats()
        } catch {
            logger.error("fetchUnreadChats failed: \(error)")
            await reply(to: peerId, text: "❌ Не смог получить список чатов: \(error)")
            return
        }

        if chats.isEmpty {
            await reply(to: peerId, text: "📭 Непрочитанных нет.")
            return
        }

        // Сортируем: внутри категории — по unreadCount убыв., категории по приоритету: каналы → группы → ЛС
        let sortedChannels = chats.filter { $0.kind == .channel }.sorted { $0.unreadCount > $1.unreadCount }
        let sortedGroups   = chats.filter { $0.kind == .group   }.sorted { $0.unreadCount > $1.unreadCount }
        let sortedDM       = chats.filter { $0.kind == .dm      }.sorted { $0.unreadCount > $1.unreadCount }
        let ordered = sortedChannels + sortedGroups + sortedDM

        let indexed = await sessionState.recordMenu(ordered)
        let menuText = formatMenu(indexed: indexed, totals: (channels: sortedChannels.count, groups: sortedGroups.count, dm: sortedDM.count))

        for chunk in splitForVK(menuText) {
            await reply(to: peerId, text: chunk)
        }
    }

    private func runGetByIndex(peerId: Int64, index: Int) async {
        guard let chat = await sessionState.resolve(index: index) else {
            if await sessionState.isEmpty {
                await reply(to: peerId, text: "ℹ️ Сначала вызови /digest, чтобы появился список номеров.")
            } else {
                await reply(to: peerId, text: "🤷 Номер \(index) не найден в последнем меню.")
            }
            return
        }
        await runGetChats(peerId: peerId, chats: [chat], label: "чат #\(index)")
    }

    private func runGetChats(peerId: Int64, chats: [UnreadChatInfo], label: String) async {
        if chats.isEmpty {
            await reply(to: peerId, text: "📭 В меню нет чатов категории '\(label)'.")
            return
        }

        await reply(to: peerId, text: "📥 Подгружаю \(chats.count) чат(а/ов): \(label)…")

        var totalSent = 0
        for chat in chats {
            let messages: [SourceMessage]
            do {
                messages = try await messageSource.fetchMessages(for: chat)
            } catch {
                logger.error("fetchMessages(\(chat.id)) failed: \(error)")
                await reply(to: peerId, text: "⚠️ '\(chat.title)' — не смог подгрузить: \(error)")
                continue
            }

            let chunks = formatChat(chat: chat, messages: messages)
            for chunk in chunks {
                await reply(to: peerId, text: chunk)
            }
            totalSent += messages.count
        }

        if chats.count > 1 {
            await reply(to: peerId, text: "✅ Готово. Сообщений: \(totalSent), чатов: \(chats.count).")
        }
    }

    private func runLastByIndex(peerId: Int64, index: Int, count: Int) async {
        guard let chat = await sessionState.resolve(index: index) else {
            if await sessionState.isEmpty {
                await reply(to: peerId, text: "ℹ️ Сначала вызови /digest, чтобы появился список номеров.")
            } else {
                await reply(to: peerId, text: "🤷 Номер \(index) не найден в последнем меню.")
            }
            return
        }

        let messages: [SourceMessage]
        do {
            messages = try await messageSource.fetchLastMessages(for: chat, count: count)
        } catch {
            logger.error("fetchLastMessages(\(chat.id), \(count)) failed: \(error)")
            await reply(to: peerId, text: "❌ Не смог подгрузить '\(chat.title)': \(error)")
            return
        }

        let chunks = formatChat(chat: chat, messages: messages)
        for chunk in chunks {
            await reply(to: peerId, text: chunk)
        }
    }

    private func runReadByIndex(peerId: Int64, index: Int) async {
        guard let chat = await sessionState.resolve(index: index) else {
            if await sessionState.isEmpty {
                await reply(to: peerId, text: "ℹ️ Сначала вызови /digest, чтобы появился список номеров.")
            } else {
                await reply(to: peerId, text: "🤷 Номер \(index) не найден в последнем меню.")
            }
            return
        }

        // Берём ID последнего сообщения чата (TDLib пометит весь диапазон до него)
        let lastMessageId: Int64
        do {
            let resp = try await tdlib.getChatHistory(chatId: chat.id, fromMessageId: 0, offset: 0, limit: 1)
            guard let msg = resp.messages.first else {
                await reply(to: peerId, text: "ℹ️ В '\(chat.title)' нет сообщений для пометки.")
                return
            }
            lastMessageId = msg.id
        } catch {
            logger.error("getChatHistory(\(chat.id)) for read failed: \(error)")
            await reply(to: peerId, text: "❌ Не смог получить последнее сообщение '\(chat.title)': \(error)")
            return
        }

        do {
            _ = try await tdlib.viewMessages(chatId: chat.id, messageIds: [lastMessageId], forceRead: true)
            logger.info("viewMessages success: chat=\(chat.id) lastMsg=\(lastMessageId)")
            await reply(to: peerId, text: "✅ '\(chat.title)' помечен прочитанным.")
        } catch {
            logger.error("viewMessages(\(chat.id)) failed: \(error)")
            await reply(to: peerId, text: "❌ Не смог пометить '\(chat.title)': \(error)")
        }
    }

    private func runToUsername(peerId: Int64, username: String, text: String) async {
        guard !text.isEmpty else {
            await reply(to: peerId, text: "⚠️ Пустой текст. Формат: /to <username> <text>")
            return
        }

        let chat: ChatResponse
        do {
            chat = try await tdlib.searchPublicChat(username: username)
        } catch {
            logger.error("searchPublicChat(@\(username)) failed: \(error)")
            await reply(to: peerId, text: "❌ Не нашёл @\(username): \(error)")
            return
        }

        do {
            let sent = try await tdlib.sendMessage(chatId: chat.id, text: text)
            logger.info("toUsername success: @\(username) chat=\(chat.id) msgId=\(sent.id)")
            await reply(to: peerId, text: "✅ Ушло в Telegram → '\(chat.title)' (@\(username), \(text.count) симв.)\nСерверы TG приняли.")
        } catch {
            logger.error("sendMessage(@\(username), \(chat.id)) failed: \(error)")
            await reply(to: peerId, text: "❌ Не смог отправить @\(username): \(error)")
        }
    }

    private func runReplyByIndex(peerId: Int64, index: Int, text: String) async {
        guard let chat = await sessionState.resolve(index: index) else {
            if await sessionState.isEmpty {
                await reply(to: peerId, text: "ℹ️ Сначала вызови /digest, чтобы появился список номеров.")
            } else {
                await reply(to: peerId, text: "🤷 Номер \(index) не найден в последнем меню.")
            }
            return
        }

        guard !text.isEmpty else {
            await reply(to: peerId, text: "⚠️ Пустой текст ответа. Формат: /reply N текст ответа")
            return
        }

        do {
            let sent = try await tdlib.sendMessage(chatId: chat.id, text: text)
            logger.info("sendMessage success: chat=\(chat.id) msgId=\(sent.id) chars=\(text.count)")
            await reply(to: peerId, text: "✅ Ушло в Telegram → '\(chat.title)' (\(text.count) симв.)\nСерверы TG приняли. Если не дошло — проверь чат.")
        } catch {
            logger.error("sendMessage(\(chat.id)) failed: \(error)")
            await reply(to: peerId, text: "❌ Не смог отправить в '\(chat.title)': \(error)")
        }
    }

    private func runTest(peerId: Int64) async {
        let uptime = Date().timeIntervalSince(startedAt)
        let report = """
        ✅ tg-client bot bridge alive

        Uptime: \(formatDuration(uptime))
        Started: \(ISO8601DateFormatter().string(from: startedAt))
        Allowed owners: \(allowedOwners.count)
        TDLib: подключён

        Команды:
        /digest — меню непрочитанных
        /get N — взять чат N
        /get all|channels|groups|dm — категории
        /last N [count] — последние сообщения чата (default 5)
        /reply N <текст> — ответить в чат N
        /to <username> <текст> — отправить любому по @username
        /to_alena <текст> — alias для @alenoch13
        /test — этот ответ
        """
        await reply(to: peerId, text: report)
    }

    // MARK: - Helpers

    private func reply(to peerId: Int64, text: String) async {
        do {
            _ = try await vkClient.sendMessage(peerId: peerId, text: text)
        } catch {
            logger.error("Failed to send reply to peer \(peerId): \(error)")
        }
    }

    private func parseCommand(_ raw: String) -> Command {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        let lowered = trimmed.lowercased()

        switch lowered {
        case "/test", "test", "тест", "ping", "пинг":
            return .test
        case "/digest", "digest", "дайджест":
            return .digest
        default:
            break
        }

        // /get <arg>
        if let arg = stripCommandPrefix(lowered, prefixes: ["/get ", "get "]) {
            return parseGetArg(arg)
        }

        // /last N [count]
        if let arg = stripCommandPrefix(lowered, prefixes: ["/last ", "last "]) {
            let parts = arg.split(separator: " ", omittingEmptySubsequences: true).map(String.init)
            if parts.count == 1, let n = Int(parts[0]) {
                return .lastByIndex(n, count: 5)
            }
            if parts.count >= 2, let n = Int(parts[0]), let c = Int(parts[1]) {
                return .lastByIndex(n, count: c)
            }
            return .unknown(raw)
        }

        // /reply N <text> — текст берём из ОРИГИНАЛЬНОГО raw (с регистром, эмодзи, переводами)
        if let _ = stripCommandPrefix(lowered, prefixes: ["/reply ", "reply "]) {
            return parseReply(raw: trimmed)
        }

        // /to_alena <text> — alias на /to alenoch13 <text>
        if let _ = stripCommandPrefix(lowered, prefixes: ["/to_alena ", "to_alena "]) {
            // achievable text — из оригинала, без префикса
            let prefix = lowered.hasPrefix("/to_alena ") ? "/to_alena " : "to_alena "
            let text = String(trimmed.dropFirst(prefix.count)).trimmingCharacters(in: .whitespacesAndNewlines)
            return .toUsername("alenoch13", text: text)
        }

        // /to <username> <text> — общая
        if let _ = stripCommandPrefix(lowered, prefixes: ["/to ", "to "]) {
            return parseTo(raw: trimmed)
        }

        // /read N — пометить чат N как прочитанный
        if let arg = stripCommandPrefix(lowered, prefixes: ["/read ", "read "]) {
            if let n = Int(arg) { return .readByIndex(n) }
            return .unknown(raw)
        }

        return .unknown(raw)
    }

    private func parseTo(raw: String) -> Command {
        let lower = raw.lowercased()
        let prefix = lower.hasPrefix("/to ") ? "/to " : (lower.hasPrefix("to ") ? "to " : nil)
        guard let prefix = prefix else { return .unknown(raw) }
        let afterPrefix = String(raw.dropFirst(prefix.count))
        guard let firstSpace = afterPrefix.firstIndex(of: " ") else {
            return .unknown(raw)
        }
        let username = afterPrefix[..<firstSpace].trimmingCharacters(in: .whitespaces).trimmingCharacters(in: CharacterSet(charactersIn: "@"))
        let text = afterPrefix[afterPrefix.index(after: firstSpace)...].trimmingCharacters(in: .whitespacesAndNewlines)
        guard !username.isEmpty else { return .unknown(raw) }
        return .toUsername(username, text: String(text))
    }

    private func stripCommandPrefix(_ text: String, prefixes: [String]) -> String? {
        for prefix in prefixes {
            if text.hasPrefix(prefix) {
                return String(text.dropFirst(prefix.count)).trimmingCharacters(in: .whitespaces)
            }
        }
        return nil
    }

    private func parseGetArg(_ arg: String) -> Command {
        switch arg {
        case "all", "всё", "все":
            return .getAll
        case "channels", "каналы":
            return .getCategory(.channel)
        case "groups", "группы":
            return .getCategory(.group)
        case "dm", "лс":
            return .getCategory(.dm)
        default:
            if let n = Int(arg) { return .getByIndex(n) }
            return .unknown("/get \(arg)")
        }
    }

    /// Парсит `/reply N <свободный текст>` сохраняя оригинальный регистр и форматирование текста.
    private func parseReply(raw: String) -> Command {
        // Найти позицию первого пробела после "/reply" — там начинается N
        // Затем найти пробел после N — там начинается text
        let lower = raw.lowercased()
        let prefix = lower.hasPrefix("/reply ") ? "/reply " : (lower.hasPrefix("reply ") ? "reply " : nil)
        guard let prefix = prefix else { return .unknown(raw) }

        let afterPrefix = String(raw.dropFirst(prefix.count))
        // afterPrefix = "N <text>"
        guard let firstSpace = afterPrefix.firstIndex(of: " ") else {
            // только N, без текста
            if let n = Int(afterPrefix.trimmingCharacters(in: .whitespaces)) {
                return .replyByIndex(n, text: "")
            }
            return .unknown(raw)
        }
        let nPart = afterPrefix[..<firstSpace].trimmingCharacters(in: .whitespaces)
        let textPart = afterPrefix[afterPrefix.index(after: firstSpace)...].trimmingCharacters(in: .whitespacesAndNewlines)

        guard let n = Int(nPart) else { return .unknown(raw) }
        return .replyByIndex(n, text: String(textPart))
    }

    /// Разделитель строк для VK. VK схлопывает множественные `\n` в один, поэтому
    /// между блоками вставляем строку из символов вместо пустой.
    private static let sectionDivider = "\n━━━━━━━━━━━━━━━\n"

    private func formatMenu(indexed: [(index: Int, chat: UnreadChatInfo)], totals: (channels: Int, groups: Int, dm: Int)) -> String {
        var sections: [String] = []
        sections.append("📋 Непрочитанные (\(indexed.count) чатов)")

        for kind in [ChatKind.channel, .group, .dm] {
            let items = indexed.filter { $0.chat.kind == kind }
            guard !items.isEmpty else { continue }
            var section = "\(kind.emoji) \(kind.displayName.uppercased()) (\(items.count)):\n"
            section += items
                .map { "\($0.index). \($0.chat.title) (\($0.chat.unreadCount))" }
                .joined(separator: "\n")
            sections.append(section)
        }

        sections.append("""
        Команды:
        /get N — взять чат
        /get all — взять всё
        /get channels|groups|dm — категория
        /last N [count] — последние сообщения чата (default 5)
        /reply N <текст> — ответить в чат
        """)

        return sections.joined(separator: Self.sectionDivider)
    }

    private func formatChat(chat: UnreadChatInfo, messages: [SourceMessage]) -> [String] {
        let header = "\(chat.kind.emoji) \(chat.title) (\(messages.count)):"

        if messages.isEmpty {
            return splitForVK(header + "\n(нет текстовых сообщений)")
        }

        // Разделяем сообщения линией — VK схлопывает пустые строки, поэтому реальный разделитель
        let messageBlocks = messages.enumerated().map { idx, msg -> String in
            let prefix = "[\(idx + 1)] "
            return prefix + msg.content
        }

        let body = messageBlocks.joined(separator: "\n———\n")
        return splitForVK(header + Self.sectionDivider + body)
    }

    private func splitForVK(_ text: String) -> [String] {
        let limit = 4000
        if text.count <= limit { return [text] }

        var chunks: [String] = []
        var current = ""
        for line in text.split(separator: "\n", omittingEmptySubsequences: false) {
            if current.count + line.count + 1 > limit {
                if !current.isEmpty { chunks.append(current) }
                current = String(line) + "\n"
            } else {
                current += line + "\n"
            }
        }
        if !current.isEmpty { chunks.append(current) }
        return chunks
    }

    private func formatDuration(_ seconds: TimeInterval) -> String {
        let secs = Int(seconds)
        let h = secs / 3600
        let m = (secs % 3600) / 60
        let s = secs % 60
        return String(format: "%d:%02d:%02d", h, m, s)
    }

    private enum Command {
        case test
        case digest
        case getByIndex(Int)
        case getAll
        case getCategory(ChatKind)
        case lastByIndex(Int, count: Int)
        case replyByIndex(Int, text: String)
        case toUsername(String, text: String)
        case readByIndex(Int)
        case unknown(String)

        var summary: String {
            switch self {
            case .test: return "test"
            case .digest: return "digest"
            case .getByIndex(let n): return "get \(n)"
            case .getAll: return "get all"
            case .getCategory(let k): return "get \(k.rawValue)"
            case .lastByIndex(let n, let c): return "last \(n) \(c)"
            case .replyByIndex(let n, let t): return "reply \(n) (\(t.count) chars)"
            case .toUsername(let u, let t): return "to @\(u) (\(t.count) chars)"
            case .readByIndex(let n): return "read \(n)"
            case .unknown(let s): return "unknown(\(s.prefix(40)))"
            }
        }
    }
}
