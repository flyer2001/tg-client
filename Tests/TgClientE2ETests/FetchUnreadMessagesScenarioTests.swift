import Foundation
import Testing
import Logging
@testable import TDLibAdapter
@testable import DigestCore

/// E2E тест для сценария получения непрочитанных сообщений из каналов.
///
/// **User Story:** Получить список всех непрочитанных сообщений из подписанных Telegram каналов
/// для создания AI-дайджеста.
///
/// **Сценарий:** <doc:FetchUnreadMessages>
///
/// **Предусловия:**
/// - Пользователь авторизован в TDLib (сохранённая сессия в ~/.tdlib/)
/// - У пользователя есть подписки на Telegram каналы
/// - В некоторых каналах есть непрочитанные сообщения
@Suite("E2E: Получение непрочитанных сообщений из каналов")
struct FetchUnreadMessagesScenarioTests {

    /// E2E тест: получение непрочитанных сообщений из реальных каналов.
    ///
    /// **Что тестируем:**
    /// - Полный цикл: loadChats → getChat → фильтрация каналов → getChatHistory
    /// - Структуру возвращаемых данных (SourceMessage)
    /// - Корректность ссылок на сообщения (для публичных каналов)
    @Test("Получение непрочитанных сообщений через реальный TDLib")
    func fetchUnreadMessagesFromRealChannels() async throws {
        // 1. Создание TDLib клиента (предполагаем что сессия уже сохранена)
        let logger = Logger(label: "tg-client.e2e")
        let tdlib = TDLibClient(appLogger: logger)

        // TODO: start() с config - добавим позже, сейчас фокус на ChannelMessageSource

        // 2. Создание ChannelMessageSource
        let messageSource = ChannelMessageSource(tdlib: tdlib)

        // 3. Получение непрочитанных сообщений
        let messages = try await messageSource.fetchUnreadMessages()

        // 4. Проверка результата
        if messages.isEmpty {
            // Edge case: нет непрочитанных — это валидный сценарий
            print("No unread messages found (valid scenario)")
        } else {
            // Проверяем структуру первого сообщения
            let firstMessage = messages[0]
            #expect(firstMessage.chatId > 0)
            #expect(firstMessage.messageId > 0)
            #expect(!firstMessage.content.isEmpty)
            #expect(!firstMessage.channelTitle.isEmpty)

            // Для публичных каналов должна быть ссылка
            if let link = firstMessage.link {
                #expect(link.starts(with: "https://t.me/"))
            }

            print("✅ Fetched \(messages.count) unread messages from channels")
        }
    }
}
