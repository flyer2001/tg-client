import Foundation
import Testing
import Logging
import TgClientModels
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
@testable import BotBridge
@testable import DigestCore
@testable import TDLibAdapter
@testable import TestHelpers

/// TDLib-модель сообщения (в DigestCore есть одноимённая модель Bot API).
private typealias TDMessage = TgClientModels.Message

/// Component тесты команд VK-моста: VK сообщение → `CommandProcessor` → TDLib → ответ в VK.
///
/// **User Story:** <doc:VKBridge> — таблица «Команды и критерии приёмки».
///
/// **Mock:** только границы — `MockTDLibFFI` (TDLib: чаты приходят updates через `loadChats`,
/// `getChats`/`getChat` отдаёт кэш, как реальный TDLib) и `GatedHTTPClient` с открытым затвором
/// (шпион `messages.send`: запоминает тексты ответов владельцу).
///
/// Характеризующие тесты: код команд написан в spike до тестов (с разрешения владельца, v0.5.0).
/// Исключение — `/to_alena`: удаление личного ярлыка сделано тест-первым.
@Suite("CommandProcessor: команды VK-моста", .timeLimit(.minutes(1)))
struct CommandProcessorCommandsTests {

    // MARK: - /digest (US-2)

    @Test("/digest без непрочитанных → «Непрочитанных нет»")
    func digestEmpty() async {
        let bridge = Bridge()
        bridge.addChat(id: 10, title: "Read", type: .supergroup(supergroupId: 1, isChannel: true), unread: 0)

        await bridge.send("/digest")

        #expect(await bridge.replies.last == "📭 Непрочитанных нет.")
    }

    @Test("/digest → меню: каналы, группы, ЛС по порядку; архив не попадает")
    func digestMenu() async {
        let bridge = Bridge()
        bridge.addChat(id: 10, title: "Tech", type: .supergroup(supergroupId: 1, isChannel: true), unread: 5)
        bridge.addChat(id: 20, title: "Friends", type: .supergroup(supergroupId: 2, isChannel: false), unread: 2)
        bridge.addChat(id: 30, title: "Alice", type: .private(userId: 30), unread: 1)
        bridge.addChat(id: 40, title: "Archived", type: .supergroup(supergroupId: 4, isChannel: true), unread: 3, list: .archive)

        await bridge.send("/digest")

        let menu = await bridge.replies.last ?? ""
        #expect(menu.contains("1. Tech (5)"))
        #expect(menu.contains("2. Friends (2)"))
        #expect(menu.contains("3. Alice (1)"))
        #expect(!menu.contains("Archived"))
    }

    // MARK: - /get (US-3)

    @Test("/get N до /digest → подсказка вызвать /digest")
    func getBeforeDigest() async {
        let bridge = Bridge()
        await bridge.send("/get 1")
        #expect(await bridge.replies.last?.hasPrefix("ℹ️ Сначала вызови /digest") == true)
    }

    @Test("/get N вне меню → «Номер не найден»")
    func getOutOfRange() async {
        let bridge = Bridge()
        bridge.addChat(id: 10, title: "Tech", type: .supergroup(supergroupId: 1, isChannel: true), unread: 1)
        await bridge.send("/digest")

        await bridge.send("/get 9")

        #expect(await bridge.replies.last == "🤷 Номер 9 не найден в последнем меню.")
    }

    @Test("/get N → тексты непрочитанных, включая подпись к фото, от старых к новым")
    func getChatTexts() async {
        let bridge = Bridge()
        bridge.addChat(id: 10, title: "Tech", type: .supergroup(supergroupId: 1, isChannel: true), unread: 2)
        await bridge.send("/digest")
        bridge.mockHistory([  // TDLib отдаёт newest-first
            TDMessage(id: 102, chatId: 10, date: 2, content: .photo(caption: FormattedText(text: "Подпись к фото", entities: nil))),
            TDMessage(id: 101, chatId: 10, date: 1, content: .text(FormattedText(text: "Первая новость", entities: nil))),
        ])

        await bridge.send("/get 1")

        let chat = await bridge.replies.last ?? ""
        let first = chat.range(of: "Первая новость")
        let second = chat.range(of: "Подпись к фото")
        #expect(first != nil && second != nil)
        if let first, let second { #expect(first.lowerBound < second.lowerBound) }
    }

    // MARK: - /last (US-4)

    @Test("/last N count → последние count сообщений от старых к новым")
    func lastMessages() async {
        let bridge = Bridge()
        bridge.addChat(id: 10, title: "Tech", type: .supergroup(supergroupId: 1, isChannel: true), unread: 1)
        await bridge.send("/digest")
        bridge.mockHistory((1...3).reversed().map {
            TDMessage(id: Int64(100 + $0), chatId: 10, date: Int32($0), content: .text(FormattedText(text: "msg\($0)", entities: nil)))
        })

        await bridge.send("/last 1 3")

        let chat = await bridge.replies.last ?? ""
        #expect(chat.contains("[1] msg1"))
        #expect(chat.contains("[3] msg3"))
    }

    // MARK: - /reply (US-5)

    @Test("/reply N текст → sendMessage в чат N с исходным регистром и эмодзи")
    func replyToChat() async {
        let bridge = Bridge()
        bridge.addChat(id: 10, title: "Tech", type: .supergroup(supergroupId: 1, isChannel: true), unread: 1)
        await bridge.send("/digest")
        bridge.ffi.mockResponse(forRequestType: "sendMessage", return: .success(TDMessage(id: 500, chatId: 10, date: 0, content: .text(FormattedText(text: "Йоу 🚀", entities: nil)))))

        await bridge.send("/reply 1 Йоу 🚀")

        let sent = bridge.ffi.sentRequests(ofType: "sendMessage")
        #expect(sent.count == 1)
        #expect((sent.first?["chat_id"] as? NSNumber)?.int64Value == 10)
        let content = sent.first.map { String(describing: $0["input_message_content"] ?? "") } ?? ""
        #expect(content.contains("Йоу 🚀"))
        #expect(await bridge.replies.last?.hasPrefix("✅ Ушло в Telegram → 'Tech'") == true)
    }

    // MARK: - /to (US-6)

    @Test("/to @username текст → searchPublicChat + sendMessage, «@» не важен")
    func toUsername() async {
        let bridge = Bridge()
        bridge.ffi.mockResponse(forRequestType: "searchPublicChat", return: .success(ChatResponse(id: 77, type: .private(userId: 77), title: "Bob", unreadCount: 0, lastReadInboxMessageId: 0)))
        bridge.ffi.mockResponse(forRequestType: "sendMessage", return: .success(TDMessage(id: 501, chatId: 77, date: 0, content: .text(FormattedText(text: "привет", entities: nil)))))

        await bridge.send("/to @bob привет")

        #expect(bridge.ffi.sentRequests(ofType: "searchPublicChat").first?["username"] as? String == "bob")
        #expect(await bridge.replies.last?.hasPrefix("✅ Ушло в Telegram → 'Bob' (@bob") == true)
    }

    @Test("/to неизвестный → «Не нашёл @…»")
    func toUnknownUsername() async {
        let bridge = Bridge()
        bridge.ffi.mockResponse(forRequestType: "searchPublicChat", return: Result<ChatResponse, TDLibErrorResponse>.failure(TDLibErrorResponse(code: 400, message: "USERNAME_NOT_OCCUPIED")))

        await bridge.send("/to nobody привет")

        #expect(await bridge.replies.last?.hasPrefix("❌ Не нашёл @nobody") == true)
    }

    @Test("/to_alena — личный ярлык удалён: неизвестная команда")
    func toAlenaRemoved() async {
        let bridge = Bridge()

        await bridge.send("/to_alena привет")

        #expect(bridge.ffi.sentRequests(ofType: "searchPublicChat").isEmpty)
        #expect(await bridge.replies.last?.contains("Не знаю команду") == true)
    }

    // MARK: - /read (US-7)

    @Test("/read N → viewMessages(последнее сообщение, forceRead) и подтверждение")
    func readChat() async {
        let bridge = Bridge()
        bridge.addChat(id: 10, title: "Tech", type: .supergroup(supergroupId: 1, isChannel: true), unread: 3)
        await bridge.send("/digest")
        bridge.mockHistory([TDMessage(id: 777, chatId: 10, date: 3, content: .text(FormattedText(text: "last", entities: nil)))])
        bridge.ffi.mockResponse(forRequestType: "viewMessages", return: .success(OkResponse()))

        await bridge.send("/read 1")

        let view = bridge.ffi.sentRequests(ofType: "viewMessages").first
        #expect((view?["message_ids"] as? [NSNumber])?.map(\.int64Value) == [777])
        #expect(view?["force_read"] as? Bool == true)
        #expect(await bridge.replies.last == "✅ 'Tech' помечен прочитанным.")
    }

    // MARK: - Доступ и прочее

    @Test("сообщение не от владельца → игнор, ответа нет")
    func nonOwnerIgnored() async {
        let bridge = Bridge(owner: 1)
        await bridge.processor.handle(message: .owner(999, text: "/test"))
        #expect(await bridge.replies.isEmpty)
    }

    @Test("неизвестная команда → подсказка со списком команд")
    func unknownCommand() async {
        let bridge = Bridge()
        await bridge.send("/foo")
        #expect(await bridge.replies.last?.contains("Не знаю команду '/foo'") == true)
    }
}

// MARK: - Harness

/// Сборка `CommandProcessor` поверх заглушек границ (TDLib FFI + HTTP к VK).
private struct Bridge {
    let ffi = MockTDLibFFI()
    let http = GatedHTTPClient(open: true)
    let processor: CommandProcessor
    let owner: Int64

    init(owner: Int64 = 1) {
        self.owner = owner
        let tdlib = TDLibClient(ffi: ffi, appLogger: .noop)
        tdlib.startUpdatesLoop()
        let source = ChannelMessageSource(
            tdlib: tdlib,
            logger: .noop,
            loadChatsPaginationDelay: .milliseconds(1),
            updatesCollectionTimeout: .milliseconds(20),
            maxParallelHistoryRequests: 5,
            maxLoadChatsBatches: 5
        )
        processor = CommandProcessor(
            messageSource: source,
            tdlib: tdlib,
            vkClient: VKAPIClient(token: "T", httpClient: http, logger: .noop),
            allowedOwners: [Int(owner)],
            logger: .noop
        )
    }

    func send(_ text: String) async {
        await processor.handle(message: .owner(owner, text: text))
    }

    var replies: [String] {
        get async { await http.sentTexts }
    }

    /// Чат приходит в TDLib как `updateNewChat` + `updateChatPosition` (main или archive).
    func addChat(id: Int64, title: String, type: ChatType, unread: Int32, list: ChatList = .main) {
        ffi.queueUpdate(.newChat(chat: ChatResponse(id: id, type: type, title: title, unreadCount: unread, lastReadInboxMessageId: 0)))
        ffi.queueUpdate(.chatPosition(chatId: id, position: ChatPosition(list: list, order: 1000 + id, isPinned: false)))
    }

    /// Ответ `getChatHistory` (newest-first), затем пустой — чтобы итеративная подгрузка остановилась.
    func mockHistory(_ messages: [TDMessage]) {
        ffi.mockResponse(forRequestType: "getChatHistory", return: .success(MessagesResponse(totalCount: Int32(messages.count), messages: messages)))
        ffi.mockResponse(forRequestType: "getChatHistory", return: .success(MessagesResponse(totalCount: 0, messages: [])))
    }
}
