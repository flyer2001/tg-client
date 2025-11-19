import Foundation
import Logging
import Testing
@testable import TDLibAdapter
@testable import DigestCore

/// Component тесты для ChannelMessageSource - Outside-In TDD.
///
/// **Процесс разработки (итеративный):**
/// 1. Написали высокоуровневый тест → НЕ КОМПИЛИРУЕТСЯ
/// 2. Создаём заглушки → компилируется, падает
/// 3. Пытаемся реализовать → СТОП, не хватает функционала → пишем тест для недостающего
/// 4. Реализуем недостающее → возвращаемся на шаг выше
/// 5. Повторяем пока высокоуровневый тест не станет GREEN
///
/// **Текущее состояние:** УРОВЕНЬ 1 - высокоуровневый тест (не компилируется)
///
/// **Связанная документация:**
/// - E2E сценарий: <doc:FetchUnreadMessages>
@Suite("Component: ChannelMessageSource - Outside-In TDD")
struct ChannelMessageSourceTests {

    /// Получение непрочитанных сообщений из каналов.
    ///
    /// **Outside-In TDD - стартовая точка (высокий уровень).**
    ///
    /// **Given:** MockTDLibClient возвращает 3 чата через updates:
    /// - Канал "Tech News" (unreadCount=2)
    /// - Канал "Dev Updates" (unreadCount=0) - прочитан
    /// - Группа "Random" (unreadCount=5) - НЕ канал
    ///
    /// **When:** Вызываем `messageSource.fetchUnreadMessages()`
    ///
    /// **Then:** Получаем 2 сообщения только из "Tech News" (канал с unreadCount > 0)
    ///
    /// **Алгоритм:**
    /// 1. loadChats() → OkResponse + эмитит 3x updateNewChat
    /// 2. Фильтрация: только .supergroup(isChannel=true) + unreadCount > 0 → 1 канал
    /// 3. getChatHistory() для отфильтрованного канала → 2 сообщения
    @Test("fetchUnreadMessages: получение непрочитанных из каналов")
    func fetchUnreadMessagesFromChannels() async throws {
        // Given: MockTDLibClient с настроенными ответами
        let mockClient = MockTDLibClient()
        let logger = Logger(label: "test") { _ in SwiftLogNoOpLogHandler() }

        // 1. Настраиваем loadChats() → Ok
        mockClient.setMockResponse(
            for: LoadChatsRequest(chatList: .main, limit: 100),
            response: .success(OkResponse())
        )

        // 2. Буферизуем updates (будут эмитированы при loadChats)
        // Канал с непрочитанными (должен попасть в результат)
        let techNews = ChatResponse(
            id: 123,
            type: .supergroup(supergroupId: 1, isChannel: true),
            title: "Tech News",
            unreadCount: 2,
            lastReadInboxMessageId: 100
        )
        mockClient.emitUpdate(.newChat(chat: techNews))

        // Канал БЕЗ непрочитанных (фильтруется)
        let devUpdates = ChatResponse(
            id: 456,
            type: .supergroup(supergroupId: 2, isChannel: true),
            title: "Dev Updates",
            unreadCount: 0,
            lastReadInboxMessageId: 200
        )
        mockClient.emitUpdate(.newChat(chat: devUpdates))

        // Группа с непрочитанными (НЕ канал, фильтруется)
        let randomGroup = ChatResponse(
            id: 789,
            type: .supergroup(supergroupId: 3, isChannel: false),
            title: "Random",
            unreadCount: 5,
            lastReadInboxMessageId: 300
        )
        mockClient.emitUpdate(.newChat(chat: randomGroup))

        // 3. Настраиваем getChatHistory() для канала "Tech News"
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
        mockClient.setMockResponse(
            for: GetChatHistoryRequest(chatId: 123, fromMessageId: 0, offset: 0, limit: 100, onlyLocal: false),
            response: .success(MessagesResponse(totalCount: 2, messages: [message1, message2]))
        )

        // When: Вызываем fetchUnreadMessages() с быстрыми таймаутами для тестов
        let messageSource = ChannelMessageSource(
            tdlib: mockClient,
            logger: logger,
            loadChatsPaginationDelay: .milliseconds(50),      // Быстро для тестов
            updatesCollectionTimeout: .milliseconds(100),     // Быстро для тестов
            maxParallelHistoryRequests: 5,
            maxLoadChatsBatches: 5                             // Лимит для тестов
        )
        let messages = try await messageSource.fetchUnreadMessages()

        // Then: Проверяем результат — только 2 сообщения из "Tech News"
        #expect(messages.count == 2)

        let first = messages[0]
        #expect(first.chatId == 123)
        #expect(first.messageId == 101)
        #expect(first.content == "Breaking news today")
        #expect(first.channelTitle == "Tech News")
        #expect(first.link == nil)  // Нет username → nil (приватный канал)

        let second = messages[1]
        #expect(second.chatId == 123)
        #expect(second.messageId == 102)
        #expect(second.content == "Another update")
        #expect(second.link == nil)
    }

    // MARK: - Тесты для недостающего функционала
    // (Добавляются по мере обнаружения при попытке реализации fetchUnreadMessages)

    /// loadChats отправляет updateNewChat через updates stream.
    ///
    /// **Контекст:** При попытке реализовать `fetchUnreadMessages()` обнаружили,
    /// что `loadChats()` возвращает `Ok`, а Chat приходят через `updates` AsyncStream.
    ///
    /// **TDLib behavior:**
    /// 1. `loadChats()` возвращает `Ok` (не список чатов!)
    /// 2. TDLib посылает `updateNewChat` для каждого загруженного чата через AsyncStream
    ///
    /// **Given:** MockTDLibClient настроен эмитить 3 updateNewChat
    /// **When:** Вызываем loadChats() и слушаем updates stream
    /// **Then:** Получаем 3 Chat объекта через updateNewChat
    ///
    /// **Docs:** https://core.telegram.org/tdlib/docs/classtd_1_1td__api_1_1load_chats.html
    @Test("loadChats + updates stream → updateNewChat")
    func loadChatsEmitsUpdateNewChat() async throws {
        // Given: MockTDLibClient
        let mockClient = MockTDLibClient()

        // When: Загружаем чаты
        // ⚠️ НЕ КОМПИЛИРУЕТСЯ: нет loadChats() метода
        try await mockClient.loadChats(chatList: .main, limit: 100)

        // Then: Получаем updateNewChat через updates stream
        var receivedChats: [ChatResponse] = []
        for await update in await mockClient.updates {
            if case .newChat(let chat) = update {
                receivedChats.append(chat)
            }
            if receivedChats.count >= 3 { break }
        }

        #expect(receivedChats.count == 3)
        #expect(receivedChats[0].id == 123)
        #expect(receivedChats[0].title == "Tech News")
    }
}
