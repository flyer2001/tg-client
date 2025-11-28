import TgClientModels
import TGClientInterfaces
import Foundation
import Logging
import Testing
@testable import TDLibAdapter
@testable import DigestCore
import TestHelpers

/// Component тесты для ChannelMessageSource.
///
/// **Scope:**
/// - Загрузка каналов через LoadChatsRequest + updates stream
/// - Фильтрация: только каналы (isChannel=true) с unreadCount > 0
/// - Получение сообщений через GetChatHistoryRequest
///
/// **Связанная документация:**
/// - E2E сценарий: <doc:FetchUnreadMessages>
@Suite("Component: ChannelMessageSource")
struct ChannelMessageSourceTests {

    /// Получение непрочитанных сообщений из каналов.
    ///
    /// **Given:** TDLibClient (MockTDLibFFI) возвращает 3 чата:
    /// - Канал "Tech News" (unreadCount=2)
    /// - Канал "Dev Updates" (unreadCount=0) - прочитан
    /// - Группа "Random" (unreadCount=5) - НЕ канал
    ///
    /// **When:** Вызываем `messageSource.fetchUnreadMessages()`
    ///
    /// **Then:** Получаем 2 сообщения только из "Tech News"
    @Test("fetchUnreadMessages: каналы с непрочитанными")
    func fetchUnreadMessagesFromChannels() async throws {

        // Given: TDLibClient с MockTDLibFFI
        let mockFFI = MockTDLibFFI()
        let logger = Logger(label: "test") { _ in SwiftLogNoOpLogHandler() }
        let tdlibClient = TDLibClient(
            ffi: mockFFI,
            appLogger: logger,
            authorizationPollTimeout: 0.1,
            maxAuthorizationAttempts: 10,
            authorizationTimeout: 5
        )

        // Запускаем TDLib background loop для обработки updates
        tdlibClient.startUpdatesLoop()


        // 1. Настраиваем loadChats → Ok (после эмиссии updates)
        let techNews = ChatResponse(
            id: 123,
            type: .supergroup(supergroupId: 1, isChannel: true),
            title: "Tech News",
            unreadCount: 2,
            lastReadInboxMessageId: 100
        )
        mockFFI.queueUpdate(.newChat(chat: techNews))

        let devUpdates = ChatResponse(
            id: 456,
            type: .supergroup(supergroupId: 2, isChannel: true),
            title: "Dev Updates",
            unreadCount: 0,
            lastReadInboxMessageId: 200
        )
        mockFFI.queueUpdate(.newChat(chat: devUpdates))

        let randomGroup = ChatResponse(
            id: 789,
            type: .supergroup(supergroupId: 3, isChannel: false),
            title: "Random",
            unreadCount: 5,
            lastReadInboxMessageId: 300
        )
        mockFFI.queueUpdate(.newChat(chat: randomGroup))

        // loadChats вернёт 404 после эмиссии всех updates (все чаты загружены)
        // MockTDLibFFI автоматически эмитит updates и возвращает 404

        // 2. Настраиваем getChatHistory для канала "Tech News"
        let message1 = Message(
            id: 101,
            chatId: 123,
            date: 1234567890,
            content: .text(FormattedText(text: "Breaking news today", entities: nil))
        )
        let message2 = Message(
            id: 102,
            chatId: 123,
            date: 1234567891,
            content: .text(FormattedText(text: "Another update", entities: nil))
        )
        mockFFI.mockResponse(
            forRequestType: "getChatHistory",
            return: .success(MessagesResponse(totalCount: 2, messages: [message1, message2]))
        )


        // When: Вызываем fetchUnreadMessages() с быстрыми таймаутами для тестов
        let messageSource = ChannelMessageSource(
            tdlib: tdlibClient,
            logger: logger,
            loadChatsPaginationDelay: .milliseconds(10),
            updatesCollectionTimeout: .milliseconds(50),
            maxParallelHistoryRequests: 5,
            maxLoadChatsBatches: 5
        )

        let messages = try await messageSource.fetchUnreadMessages()

        // Then: Получили 2 сообщения из "Tech News" (единственный канал с unreadCount > 0)
        #expect(messages.count == 2)

        let first = messages[0]
        #expect(first.chatId == 123)
        #expect(first.messageId == 101)
        #expect(first.content == "Breaking news today")
        #expect(first.channelTitle == "Tech News")
        #expect(first.link == nil)

        let second = messages[1]
        #expect(second.chatId == 123)
        #expect(second.messageId == 102)
        #expect(second.content == "Another update")
        #expect(second.link == nil)
    }
}
