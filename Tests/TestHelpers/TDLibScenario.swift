import TgClientModels
import Foundation
import Testing
import Logging
@testable import TDLibAdapter
@testable import DigestCore

/// DSL над `MockTDLibFFI` для Component-тестов сценариев (testing-v1-plan.md, И3).
///
/// Тест говорит на языке предметной области — «есть канал с двумя непрочитанными», «помечено до 105» —
/// а не собирает `ChatResponse`/`MessagesResponse` и не разбирает сырой JSON запросов.
/// Сборка `sut` — в одном месте (`makeCollector()`, `makeBroker()`), с короткими таймаутами для тестов.
///
/// ```swift
/// let tg = TDLibScenario()
/// tg.givenChat(123, title: "Tech", unread: 2)
/// tg.givenHistory(123, [.text(101, "First"), .text(102, "Second")])   // как в чате: старые → новые
///
/// let snapshot = try await tg.makeCollector().collect()
///
/// tg.expectNothingViewed()
/// ```
///
/// Ошибки настройки (забытый стаб) указывают на строку `TDLibScenario()` в тесте.
public struct TDLibScenario: Sendable {
    public let ffi: MockTDLibFFI
    public let client: TDLibClient
    public let source: ChannelMessageSource
    public let markAsRead: MarkAsReadService
    private let logger: Logger

    public init(sourceLocation: SourceLocation = #_sourceLocation) {
        let logger = Logger(label: "test") { _ in SwiftLogNoOpLogHandler() }
        let ffi = MockTDLibFFI(sourceLocation: sourceLocation)
        let client = TDLibClient(ffi: ffi, appLogger: logger, authorizationPollTimeout: 0.1,
                                 maxAuthorizationAttempts: 10, authorizationTimeout: 5)
        client.startUpdatesLoop()
        self.ffi = ffi
        self.client = client
        self.logger = logger
        self.source = ChannelMessageSource(tdlib: client, logger: logger, loadChatsPaginationDelay: .milliseconds(1),
                                           updatesCollectionTimeout: .milliseconds(20), maxParallelHistoryRequests: 5,
                                           maxLoadChatsBatches: 5)
        self.markAsRead = MarkAsReadService(tdlib: client, logger: logger)
    }

    // MARK: - SUT

    public func makeCollector() -> SummaryCollector { SummaryCollector(source: source) }

    public func makeBroker() -> Broker { Broker(source: source, markAsRead: markAsRead, logger: logger) }

    // MARK: - Given

    public enum Kind: Sendable { case channel, group, dm }

    /// Чат в главном списке (приходит через `loadChats`, как у Real TDLib).
    public func givenChat(_ id: Int64, title: String? = nil, kind: Kind = .channel, unread: Int32, lastRead: Int64 = 0) {
        let type: ChatType = switch kind {
        case .channel: .supergroup(supergroupId: id, isChannel: true)
        case .group: .supergroup(supergroupId: id, isChannel: false)
        case .dm: .private(userId: id)
        }
        ffi.queueUpdate(.newChat(chat: ChatResponse(id: id, type: type, title: title ?? "Chat \(id)",
                                                    unreadCount: unread, lastReadInboxMessageId: lastRead)))
        ffi.queueUpdate(.chatPosition(chatId: id, position: ChatPosition(list: .main, order: 1_000 + id, isPinned: false)))
        if kind == .group {   // обычная группа — не форум (сбор спрашивает getSupergroup)
            ffi.mockResponse(forRequestType: "getSupergroup", matching: ["supergroup_id": id],
                             return: .success(SupergroupResponse(id: id, isChannel: false, isForum: false)))
        }
    }

    public struct Topic: Sendable {
        public let id: Int32
        public let name: String
        public let unread: Int32
        public let lastRead: Int64
        public let history: [Msg]
        /// `history` — как в теме: старые → новые, включая уже прочитанные (до `lastRead`).
        public init(id: Int32, name: String, unread: Int32, lastRead: Int64, history: [Msg]) {
            self.id = id; self.name = name; self.unread = unread; self.lastRead = lastRead; self.history = history
        }
    }

    /// Форум (супергруппа с темами): чатовый `unread` = сумма тем (как у Real TDLib, спайк 2026-10-16).
    /// История отдаётся только темам с непрочитанным — запрос истории прочитанной темы = issue «нет стаба».
    public func givenForum(_ id: Int64, title: String? = nil, topics: [Topic]) {
        ffi.queueUpdate(.newChat(chat: ChatResponse(id: id, type: .supergroup(supergroupId: id, isChannel: false),
                                                    title: title ?? "Forum \(id)", unreadCount: topics.reduce(0) { $0 + $1.unread },
                                                    lastReadInboxMessageId: 0)))
        ffi.queueUpdate(.chatPosition(chatId: id, position: ChatPosition(list: .main, order: 1_000 + id, isPinned: false)))
        ffi.mockResponse(forRequestType: "getSupergroup", matching: ["supergroup_id": id],
                         return: .success(SupergroupResponse(id: id, isChannel: false, isForum: true)))
        let forumTopics = topics.map { t in
            ForumTopic(info: ForumTopicInfo(chatId: id, forumTopicId: t.id, name: t.name, isGeneral: t.id == 1),
                       lastMessage: messages(id, t.history).map(\.id).max().map(MessageRef.init(id:)),
                       unreadCount: t.unread, lastReadInboxMessageId: t.lastRead)
        }
        ffi.mockResponse(forRequestType: "getForumTopics", matching: ["chat_id": id],
                         return: .success(ForumTopicsResponse(totalCount: Int32(topics.count), topics: forumTopics)))
        for t in topics where t.unread > 0 {
            let page = messages(id, t.history)
            let params = ["chat_id": id, "forum_topic_id": Int64(t.id)]
            ffi.mockResponse(forRequestType: "getForumTopicHistory", matching: params,
                             return: .success(MessagesResponse(totalCount: Int32(page.count), messages: page.reversed())))
            ffi.mockResponse(forRequestType: "getForumTopicHistory", matching: params,   // конец истории
                             return: .success(MessagesResponse(totalCount: 0, messages: [])))
        }
    }

    public enum Msg: Sendable {
        case text(Int64, String)
        case photo(Int64, caption: String? = nil)
    }

    /// История чата **как в Telegram: старые → новые**; фейк отдаёт её newest-first, как TDLib.
    /// После неё чат отвечает пустой страницей (конец истории).
    public func givenHistory(_ chat: Int64, _ messages: [Msg]) {
        let models = self.messages(chat, messages)
        ffi.mockHistory(chatId: chat, MessagesResponse(totalCount: Int32(models.count), messages: models.reversed()))
    }

    private func messages(_ chat: Int64, _ messages: [Msg]) -> [TgClientModels.Message] {
        messages.map { msg in
            switch msg {
            case let .text(id, text):
                TgClientModels.Message(id: id, chatId: chat, date: Int32(id), content: .text(FormattedText(text: text, entities: nil)))
            case let .photo(id, caption):
                TgClientModels.Message(id: id, chatId: chat, date: Int32(id),
                                       content: .photo(caption: caption.map { FormattedText(text: $0, entities: nil) }))
            }
        }
    }

    /// `viewMessages` отвечает Ok `times` раз (пометка прочитанным проходит).
    public func givenMarkAsReadSucceeds(times: Int = 1) {
        for _ in 0..<times { ffi.mockResponse(forRequestType: "viewMessages", return: .success(OkResponse())) }
    }

    // MARK: - Then

    /// Что ушло в `viewMessages` без источника (обычные чаты): чат → id сообщений (по возрастанию).
    public func viewed() -> [Int64: [Int64]] { viewMessages(source: nil) }

    /// Что ушло в `viewMessages` с источником темы форума: чат → id сообщений (по возрастанию).
    public func viewedInTopics() -> [Int64: [Int64]] { viewMessages(source: "messageSourceForumTopicHistory") }

    private func viewMessages(source: String?) -> [Int64: [Int64]] {
        Dictionary(ffi.sentRequests(ofType: "viewMessages").compactMap { req -> (Int64, [Int64])? in
            guard (req["source"] as? [String: Any])?["@type"] as? String == source,
                  let chat = req["chat_id"] as? Int64, let ids = req["message_ids"] as? [NSNumber] else { return nil }
            return (chat, ids.map(\.int64Value))
        }, uniquingKeysWith: { a, b in a + b }).mapValues { $0.sorted() }
    }

    public func expectViewed(_ expected: [Int64: [Int64]], sourceLocation: SourceLocation = #_sourceLocation) {
        #expect(viewed() == expected, sourceLocation: sourceLocation)
    }

    public func expectViewedInTopics(_ expected: [Int64: [Int64]], sourceLocation: SourceLocation = #_sourceLocation) {
        #expect(viewedInTopics() == expected, sourceLocation: sourceLocation)
    }

    /// Состояние аккаунта не тронуто — ни одного `viewMessages` (ни чатов, ни тем).
    public func expectNothingViewed(sourceLocation: SourceLocation = #_sourceLocation) {
        let sent = ffi.sentRequests(ofType: "viewMessages").count
        #expect(sent == 0, "ожидали без пометки прочитанным, ушло viewMessages: \(sent)", sourceLocation: sourceLocation)
    }
}
