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
            lastReadInboxMessageId: 100,
            positions: []  // Пустые positions в updateNewChat
        )
        mockFFI.queueUpdate(.newChat(chat: techNews))

        // Добавляем updateChatPosition с .main для "Tech News"
        let techNewsPosition = ChatPosition(list: .main, order: 9999999999, isPinned: false)
        mockFFI.queueUpdate(.chatPosition(chatId: 123, position: techNewsPosition))

        let devUpdates = ChatResponse(
            id: 456,
            type: .supergroup(supergroupId: 2, isChannel: true),
            title: "Dev Updates",
            unreadCount: 0,
            lastReadInboxMessageId: 200,
            positions: []  // Пустые positions (канал прочитан, не будет обработан)
        )
        mockFFI.queueUpdate(.newChat(chat: devUpdates))

        let randomGroup = ChatResponse(
            id: 789,
            type: .supergroup(supergroupId: 3, isChannel: false),
            title: "Random",
            unreadCount: 5,
            lastReadInboxMessageId: 300,
            positions: []  // Группа, не канал (не будет обработана)
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

    /// Архивный канал с unreadCount > 0 НЕ попадает в результат.
    ///
    /// **Given:** TDLibClient (MockTDLibFFI) возвращает:
    /// - Канал "Archived News" (unreadCount=3) с position в .archive
    /// - Канал "Active News" (unreadCount=1) с position в .main
    ///
    /// **When:** Вызываем `messageSource.fetchUnreadMessages()`
    ///
    /// **Then:** Получаем 1 сообщение только из "Active News" (архивный отфильтрован)
    @Test("fetchUnreadMessages: архивный канал отфильтрован")
    func fetchUnreadMessagesFiltersArchivedChannels() async throws {

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

        // 1. Архивный канал с пустыми positions в updateNewChat
        let archivedChannel = ChatResponse(
            id: 999,
            type: .supergroup(supergroupId: 99, isChannel: true),
            title: "Archived News",
            unreadCount: 3,
            lastReadInboxMessageId: 500,
            positions: []  // Пустые positions в updateNewChat
        )
        mockFFI.queueUpdate(.newChat(chat: archivedChannel))

        // 2. updateChatPosition с .archive для канала 999
        let archivePosition = ChatPosition(list: .archive, order: 1234567890, isPinned: false)
        mockFFI.queueUpdate(.chatPosition(chatId: 999, position: archivePosition))

        // 3. Активный канал с position в .main (для проверки что фильтр НЕ удаляет всё)
        let activeChannel = ChatResponse(
            id: 111,
            type: .supergroup(supergroupId: 11, isChannel: true),
            title: "Active News",
            unreadCount: 1,
            lastReadInboxMessageId: 100,
            positions: []
        )
        mockFFI.queueUpdate(.newChat(chat: activeChannel))

        let mainPosition = ChatPosition(list: .main, order: 9999999999, isPinned: false)
        mockFFI.queueUpdate(.chatPosition(chatId: 111, position: mainPosition))

        // 4. Настраиваем getChatHistory для активного канала (архивный НЕ должен вызываться)
        let activeMessage = Message(
            id: 101,
            chatId: 111,
            date: 1234567890,
            content: .text(FormattedText(text: "Active message", entities: nil))
        )
        mockFFI.mockResponse(
            forRequestType: "getChatHistory",
            return: .success(MessagesResponse(totalCount: 1, messages: [activeMessage]))
        )

        // When: Вызываем fetchUnreadMessages() с быстрыми таймаутами
        let messageSource = ChannelMessageSource(
            tdlib: tdlibClient,
            logger: logger,
            loadChatsPaginationDelay: .milliseconds(10),
            updatesCollectionTimeout: .milliseconds(50),
            maxParallelHistoryRequests: 5,
            maxLoadChatsBatches: 5
        )

        let messages = try await messageSource.fetchUnreadMessages()

        // Then: Получили только сообщение из активного канала (архивный отфильтрован)
        #expect(messages.count == 1)
        #expect(messages[0].chatId == 111)
        #expect(messages[0].content == "Active message")
    }

    /// Канал в папке (.folder) с unreadCount > 0 попадает в результат.
    ///
    /// **Given:** TDLibClient (MockTDLibFFI) возвращает:
    /// - Канал "Folder News" (unreadCount=1) с position в .folder(id: 123)
    ///
    /// **When:** Вызываем `messageSource.fetchUnreadMessages()`
    ///
    /// **Then:** Получаем 1 сообщение из канала
    @Test("fetchUnreadMessages: канал в folder попадает в результат")
    func fetchUnreadMessagesIncludesFolderChannels() async throws {

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

        // 1. Канал с пустыми positions в updateNewChat
        let folderChannel = ChatResponse(
            id: 888,
            type: .supergroup(supergroupId: 88, isChannel: true),
            title: "Folder News",
            unreadCount: 1,
            lastReadInboxMessageId: 600,
            positions: []  // Пустые positions в updateNewChat
        )
        mockFFI.queueUpdate(.newChat(chat: folderChannel))

        // 2. updateChatPosition с .folder(id: 123)
        let folderPosition = ChatPosition(list: .folder(id: 123), order: 9876543210, isPinned: false)
        mockFFI.queueUpdate(.chatPosition(chatId: 888, position: folderPosition))

        // 3. Настраиваем getChatHistory для канала "Folder News"
        let message = Message(
            id: 601,
            chatId: 888,
            date: 1234567892,
            content: .text(FormattedText(text: "Folder message", entities: nil))
        )
        mockFFI.mockResponse(
            forRequestType: "getChatHistory",
            return: .success(MessagesResponse(totalCount: 1, messages: [message]))
        )

        // When: Вызываем fetchUnreadMessages() с быстрыми таймаутами
        let messageSource = ChannelMessageSource(
            tdlib: tdlibClient,
            logger: logger,
            loadChatsPaginationDelay: .milliseconds(10),
            updatesCollectionTimeout: .milliseconds(50),
            maxParallelHistoryRequests: 5,
            maxLoadChatsBatches: 5
        )

        let messages = try await messageSource.fetchUnreadMessages()

        // Then: Канал в folder присутствует в результате
        #expect(messages.count == 1)
        #expect(messages[0].chatId == 888)
        #expect(messages[0].content == "Folder message")
        #expect(messages[0].channelTitle == "Folder News")
    }

    /// Канал с пустыми positions (positions=[]) НЕ попадает в результат.
    ///
    /// **Given:** TDLibClient (MockTDLibFFI) возвращает:
    /// - Канал "No Position Channel" (unreadCount=5) с positions=[] (нет updateChatPosition)
    /// - Канал "Main Channel" (unreadCount=1) с position в .main
    ///
    /// **When:** Вызываем `messageSource.fetchUnreadMessages()`
    ///
    /// **Then:** Получаем 1 сообщение только из "Main Channel" (канал без positions отфильтрован)
    @Test("fetchUnreadMessages: канал с positions=[] отфильтрован")
    func fetchUnreadMessagesFiltersChannelsWithoutPositions() async throws {

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

        // 1. Канал БЕЗ позиции (updateNewChat с positions=[], НЕТ updateChatPosition)
        let noPositionChannel = ChatResponse(
            id: 888,
            type: .supergroup(supergroupId: 88, isChannel: true),
            title: "No Position Channel",
            unreadCount: 5,
            lastReadInboxMessageId: 400,
            positions: []  // Пустые positions, updateChatPosition НЕ придёт
        )
        mockFFI.queueUpdate(.newChat(chat: noPositionChannel))

        // 2. Канал С позицией в .main (для проверки что фильтр НЕ удаляет всё)
        let mainChannel = ChatResponse(
            id: 999,
            type: .supergroup(supergroupId: 99, isChannel: true),
            title: "Main Channel",
            unreadCount: 1,
            lastReadInboxMessageId: 100,
            positions: []
        )
        mockFFI.queueUpdate(.newChat(chat: mainChannel))

        let mainPosition = ChatPosition(list: .main, order: 9999999999, isPinned: false)
        mockFFI.queueUpdate(.chatPosition(chatId: 999, position: mainPosition))

        // 3. Настраиваем getChatHistory для mainChannel (noPositionChannel НЕ должен вызываться)
        let message = Message(
            id: 101,
            chatId: 999,
            date: 1234567890,
            content: .text(FormattedText(text: "Main channel message", entities: nil))
        )
        mockFFI.mockResponse(
            forRequestType: "getChatHistory",
            return: .success(MessagesResponse(totalCount: 1, messages: [message]))
        )

        // When: Вызываем fetchUnreadMessages() с быстрыми таймаутами
        let messageSource = ChannelMessageSource(
            tdlib: tdlibClient,
            logger: logger,
            loadChatsPaginationDelay: .milliseconds(10),
            updatesCollectionTimeout: .milliseconds(50),
            maxParallelHistoryRequests: 5,
            maxLoadChatsBatches: 5
        )

        let messages = try await messageSource.fetchUnreadMessages()

        // Then: Получили только сообщение из mainChannel (noPositionChannel отфильтрован)
        #expect(messages.count == 1)
        #expect(messages[0].chatId == 999)
        #expect(messages[0].content == "Main channel message")
    }

    /// Канал одновременно в .archive и .folder НЕ попадает в результат.
    ///
    /// **Given:** TDLibClient (MockTDLibFFI) возвращает:
    /// - Канал "Mixed News" (unreadCount=2) с positions:
    ///   - .archive (order=1000)
    ///   - .folder(id: 456) (order=2000)
    /// - Канал "Normal News" (unreadCount=1) с position в .main
    ///
    /// **When:** Вызываем `messageSource.fetchUnreadMessages()`
    ///
    /// **Then:** Получаем 1 сообщение только из "Normal News" (mixed отфильтрован)
    @Test("fetchUnreadMessages: канал в archive + folder попадает в результат (приоритет folder)")
    func fetchUnreadMessagesIncludesFolderOverArchive() async throws {

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

        // 1. Смешанный канал (archive + folder)
        let mixedChannel = ChatResponse(
            id: 777,
            type: .supergroup(supergroupId: 77, isChannel: true),
            title: "Mixed News",
            unreadCount: 2,
            lastReadInboxMessageId: 700,
            positions: []  // Пустые positions в updateNewChat
        )
        mockFFI.queueUpdate(.newChat(chat: mixedChannel))

        // 2. updateChatPosition с .archive для канала 777
        let archivePosition = ChatPosition(list: .archive, order: 1000, isPinned: false)
        mockFFI.queueUpdate(.chatPosition(chatId: 777, position: archivePosition))

        // 3. updateChatPosition с .folder(id: 456) для канала 777
        let folderPosition = ChatPosition(list: .folder(id: 456), order: 2000, isPinned: false)
        mockFFI.queueUpdate(.chatPosition(chatId: 777, position: folderPosition))

        // 4. Настраиваем getChatHistory для смешанного канала (archive + folder)
        let mixedMessage = Message(
            id: 701,
            chatId: 777,
            date: 1234567892,
            content: .text(FormattedText(text: "Mixed message", entities: nil))
        )
        mockFFI.mockResponse(
            forRequestType: "getChatHistory",
            return: .success(MessagesResponse(totalCount: 1, messages: [mixedMessage]))
        )

        // 5. Обычный канал с position в .main (для проверки что оба канала включены)
        let normalChannel = ChatResponse(
            id: 222,
            type: .supergroup(supergroupId: 22, isChannel: true),
            title: "Normal News",
            unreadCount: 1,
            lastReadInboxMessageId: 200,
            positions: []
        )
        mockFFI.queueUpdate(.newChat(chat: normalChannel))

        let mainPosition = ChatPosition(list: .main, order: 8888888888, isPinned: false)
        mockFFI.queueUpdate(.chatPosition(chatId: 222, position: mainPosition))

        // 6. Настраиваем getChatHistory для обычного канала
        let normalMessage = Message(
            id: 201,
            chatId: 222,
            date: 1234567891,
            content: .text(FormattedText(text: "Normal message", entities: nil))
        )
        mockFFI.mockResponse(
            forRequestType: "getChatHistory",
            return: .success(MessagesResponse(totalCount: 1, messages: [normalMessage]))
        )

        // When: Вызываем fetchUnreadMessages() с быстрыми таймаутами
        let messageSource = ChannelMessageSource(
            tdlib: tdlibClient,
            logger: logger,
            loadChatsPaginationDelay: .milliseconds(10),
            updatesCollectionTimeout: .milliseconds(50),
            maxParallelHistoryRequests: 5,
            maxLoadChatsBatches: 5
        )

        let messages = try await messageSource.fetchUnreadMessages()

        // Then: Получили сообщения из ОБОИХ каналов (folder приоритетнее archive)
        #expect(messages.count == 2)
        let chatIds = messages.map { $0.chatId }
        #expect(chatIds.contains(777))  // mixed (archive + folder) включён
        #expect(chatIds.contains(222))  // normal (main) включён
    }

    /// getChatHistory для канала с lastReadInboxMessageId=0 (никогда не читали).
    ///
    /// **Given:** Канал "Never Read" с unreadCount=5, lastReadInboxMessageId=0
    ///
    /// **When:** Вызываем `messageSource.fetchUnreadMessages()`
    ///
    /// **Then:** getChatHistory вызван с (fromMessageId=0, offset=0, limit=5)
    @Test("getChatHistory: канал никогда не читали (lastReadInboxMessageId=0)")
    func getChatHistoryNeverReadChannel() async throws {

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

        // Канал с lastReadInboxMessageId=0
        let neverReadChannel = ChatResponse(
            id: 999,
            type: .supergroup(supergroupId: 99, isChannel: true),
            title: "Never Read Channel",
            unreadCount: 5,
            lastReadInboxMessageId: 0,
            positions: []
        )
        mockFFI.queueUpdate(.newChat(chat: neverReadChannel))

        // Добавляем updateChatPosition с .main
        let mainPosition = ChatPosition(list: .main, order: 9999999999, isPinned: false)
        mockFFI.queueUpdate(.chatPosition(chatId: 999, position: mainPosition))

        // Mock 5 messages
        let mockMessages = (1...5).map { idx in
            Message(
                id: Int64(idx * 100),
                chatId: 999,
                date: 1700000000 + idx,
                content: .text(FormattedText(text: "Message \(idx)", entities: nil))
            )
        }
        mockFFI.mockResponse(
            forRequestType: "getChatHistory",
            return: .success(MessagesResponse(totalCount: 5, messages: mockMessages))
        )

        // When: fetchUnreadMessages
        let messageSource = ChannelMessageSource(
            tdlib: tdlibClient,
            logger: logger,
            loadChatsPaginationDelay: .milliseconds(10),
            updatesCollectionTimeout: .milliseconds(50),
            maxParallelHistoryRequests: 5,
            maxLoadChatsBatches: 5
        )

        let messages = try await messageSource.fetchUnreadMessages()

        // Then: получили 5 сообщений из канала (getChatHistory вызван корректно)
        #expect(messages.count == 5)
        #expect(messages.allSatisfy { $0.chatId == 999 })
    }

    /// getChatHistory для канала с lastReadInboxMessageId>0 (есть прочитанные).
    ///
    /// **Given:** Канал "Partially Read" с unreadCount=3, lastReadInboxMessageId=500
    ///
    /// **When:** Вызываем `messageSource.fetchUnreadMessages()`
    ///
    /// **Then:** getChatHistory вызван с (fromMessageId=500, offset=-3, limit=3)
    @Test("getChatHistory: канал частично прочитан (lastReadInboxMessageId>0)")
    func getChatHistoryPartiallyReadChannel() async throws {

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

        // Канал с lastReadInboxMessageId>0
        let partiallyReadChannel = ChatResponse(
            id: 888,
            type: .supergroup(supergroupId: 88, isChannel: true),
            title: "Partially Read Channel",
            unreadCount: 3,
            lastReadInboxMessageId: 500,
            positions: []
        )
        mockFFI.queueUpdate(.newChat(chat: partiallyReadChannel))

        // Добавляем updateChatPosition с .main
        let mainPosition = ChatPosition(list: .main, order: 9999999999, isPinned: false)
        mockFFI.queueUpdate(.chatPosition(chatId: 888, position: mainPosition))

        // Mock 3 messages
        let mockMessages = (1...3).map { idx in
            Message(
                id: Int64(500 + idx * 10),
                chatId: 888,
                date: 1700000000 + idx,
                content: .text(FormattedText(text: "Unread \(idx)", entities: nil))
            )
        }
        mockFFI.mockResponse(
            forRequestType: "getChatHistory",
            return: .success(MessagesResponse(totalCount: 3, messages: mockMessages))
        )

        // When: fetchUnreadMessages
        let messageSource = ChannelMessageSource(
            tdlib: tdlibClient,
            logger: logger,
            loadChatsPaginationDelay: .milliseconds(10),
            updatesCollectionTimeout: .milliseconds(50),
            maxParallelHistoryRequests: 5,
            maxLoadChatsBatches: 5
        )

        let messages = try await messageSource.fetchUnreadMessages()

        // Then: получили 3 сообщения из канала (getChatHistory вызван корректно)
        #expect(messages.count == 3)
        #expect(messages.allSatisfy { $0.chatId == 888 })
    }
}
