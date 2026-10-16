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
    }

    public enum Msg: Sendable {
        case text(Int64, String)
        case photo(Int64, caption: String? = nil)
    }

    /// История чата **как в Telegram: старые → новые**; фейк отдаёт её newest-first, как TDLib.
    /// После неё чат отвечает пустой страницей (конец истории).
    public func givenHistory(_ chat: Int64, _ messages: [Msg]) {
        let models = messages.map { msg -> TgClientModels.Message in
            switch msg {
            case let .text(id, text):
                TgClientModels.Message(id: id, chatId: chat, date: Int32(id), content: .text(FormattedText(text: text, entities: nil)))
            case let .photo(id, caption):
                TgClientModels.Message(id: id, chatId: chat, date: Int32(id),
                                       content: .photo(caption: caption.map { FormattedText(text: $0, entities: nil) }))
            }
        }
        ffi.mockHistory(chatId: chat, MessagesResponse(totalCount: Int32(models.count), messages: models.reversed()))
    }

    /// `viewMessages` отвечает Ok `times` раз (пометка прочитанным проходит).
    public func givenMarkAsReadSucceeds(times: Int = 1) {
        for _ in 0..<times { ffi.mockResponse(forRequestType: "viewMessages", return: .success(OkResponse())) }
    }

    // MARK: - Then

    /// Что ушло в `viewMessages`: чат → id сообщений.
    public func viewed() -> [Int64: [Int64]] {
        Dictionary(ffi.sentRequests(ofType: "viewMessages").compactMap { req -> (Int64, [Int64])? in
            guard let chat = req["chat_id"] as? Int64, let ids = req["message_ids"] as? [NSNumber] else { return nil }
            return (chat, ids.map(\.int64Value))
        }, uniquingKeysWith: { a, b in a + b })
    }

    public func expectViewed(_ expected: [Int64: [Int64]], sourceLocation: SourceLocation = #_sourceLocation) {
        #expect(viewed() == expected, sourceLocation: sourceLocation)
    }

    /// Состояние аккаунта не тронуто — ни одного `viewMessages`.
    public func expectNothingViewed(sourceLocation: SourceLocation = #_sourceLocation) {
        #expect(viewed().isEmpty, "ожидали без пометки прочитанным, ушло: \(viewed())", sourceLocation: sourceLocation)
    }
}
