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
    /// **Процесс:**
    /// 1. ✅ Тест написан → НЕ КОМПИЛИРУЕТСЯ (RED)
    /// 2. ⏭️ Создать заглушки (ChannelMessageSource, SourceMessage)
    /// 3. ⏭️ Попытаться реализовать fetchUnreadMessages() → обнаружим недостающий функционал
    /// 4. ⏭️ Добавить тесты для недостающего функционала (здесь же, ниже)
    @Test("fetchUnreadMessages: получение непрочитанных из каналов")
    func fetchUnreadMessagesFromChannels() async throws {
        // Given: MockTDLibClient + no-op logger
        let mockClient = MockTDLibClient()
        let logger = Logger(label: "test") { _ in SwiftLogNoOpLogHandler() }

        // When: Вызываем fetchUnreadMessages()
        let messageSource = ChannelMessageSource(tdlib: mockClient, logger: logger)
        let messages = try await messageSource.fetchUnreadMessages()

        // Then: Проверяем результат
        #expect(messages.count == 2)

        let first = messages[0]
        #expect(first.chatId == 123)
        #expect(first.messageId == 101)
        #expect(first.content == "Breaking news today")
        #expect(first.channelTitle == "Tech News")
        #expect(first.link == "https://t.me/technews/101")  // Публичный канал

        let second = messages[1]
        #expect(second.chatId == 123)
        #expect(second.messageId == 102)
        #expect(second.content == "Another update")
        #expect(second.link == "https://t.me/technews/102")
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
