import TgClientModels
import TGClientInterfaces
import Foundation
import Testing
import Logging
@testable import TDLibAdapter
@testable import DigestCore
@testable import TestHelpers

/// E2E тест для сценария отметки сообщений как прочитанных.
///
/// **User Story:** <doc:MarkAsRead>
///
/// **Цель spike:** Проверить реальное поведение TDLib `viewMessages` API:
/// - Request/Response JSON формат
/// - Идемпотентность (повторный вызов)
/// - Синхронизация unreadCount с Telegram
/// - Edge cases (несуществующий chatId/messageId, пустой массив)
///
/// **Предусловия:**
/// - **КРИТИЧНО:** Пользователь уже авторизован в TDLib (сохранённая сессия в ~/.tdlib/)
/// - Переменные окружения настроены (`TELEGRAM_API_ID`, `TELEGRAM_API_HASH`)
/// - Есть хотя бы один канал с непрочитанными сообщениями
@Suite("E2E: Отметка сообщений как прочитанных")
struct MarkAsReadE2ETests {

    /// E2E тест: отметка сообщений как прочитанных через viewMessages API.
    ///
    /// **Сценарий:**
    /// 1. Получить непрочитанные сообщения (fetchUnreadMessages)
    /// 2. Пометить первый чат как прочитанный (viewMessages)
    /// 3. Проверить что чат исчез из непрочитанных (fetchUnreadMessages повторно)
    ///
    /// **Предусловия:**
    /// - Пользователь авторизован в TDLib
    /// - Есть хотя бы один канал с непрочитанными сообщениями
    ///
    /// **Если нет непрочитанных:**
    /// Тест пропускается с инструкцией создать отложенное сообщение в канале.
    @Test("E2E: Mark messages as read", .disabled())
    func markMessagesAsRead_e2e() async throws {
        // 1. Инициализация TDLib + ChannelMessageSource
        let logger = Logger(label: "tg-client.e2e.mark-as-read")
        let tdlib = TDLibClient(appLogger: logger)
        let config = try TDConfig.forTesting()

        try await tdlib.start(config: config, promptFor: { prompt in
            fatalError("""
            ❌ E2E тест требует предварительной авторизации!

            Выполните: swift run tg-client
            Prompt: \(prompt)
            """)
        })

        let sourceLogger = Logger(label: "tg-client.e2e.message-source")
        let messageSource = ChannelMessageSource(tdlib: tdlib, logger: sourceLogger)

        // 2. Получить непрочитанные сообщения ДО
        let unreadBefore = try await messageSource.fetchUnreadMessages()

        #expect(!unreadBefore.isEmpty, """
            ⚠️ Нет непрочитанных сообщений в каналах!

            Для запуска теста:
            1. Откройте Telegram клиент
            2. Создайте отложенное сообщение в любом канале (где вы админ)
            3. Дождитесь доставки
            4. Запустите тест повторно
            """)

        // 3. Берём первый чат из непрочитанных
        let messagesByChatId = Dictionary(grouping: unreadBefore, by: { $0.chatId })
        let (chatId, messages) = messagesByChatId.first!
        let messageIds = messages.map { $0.messageId }
        let chatTitle = messages.first?.channelTitle ?? "Unknown"

        print("📝 Testing with chat: \(chatTitle) (\(messageIds.count) unread messages)")

        // 4. Помечаем прочитанным через viewMessages
        let request = ViewMessagesRequest(chatId: chatId, messageIds: messageIds, forceRead: true)
        let response = try await tdlib.sendAndWait(request, expecting: OkResponse.self)

        #expect(response.type == "ok", "viewMessages should return Ok response")

        // Небольшая задержка для синхронизации TDLib state
        try await Task.sleep(for: .milliseconds(500))

        // 5. Получить непрочитанные сообщения ПОСЛЕ
        let unreadAfter = try await messageSource.fetchUnreadMessages()

        // 6. Проверяем что этого чата больше нет в непрочитанных
        let chatIdsAfter = Set(unreadAfter.map { $0.chatId })
        #expect(!chatIdsAfter.contains(chatId),
                "Chat \(chatId) should be marked as read and removed from unread list")

        print("✅ Chat '\(chatTitle)' successfully marked as read")
        print("   Unread chats before: \(messagesByChatId.count)")
        print("   Unread chats after: \(Dictionary(grouping: unreadAfter, by: { $0.chatId }).count)")
    }
}

// MARK: - Temporary Models для Spike

/// Временная модель ViewMessagesRequest для spike тестирования.
///
/// **Будет заменена на полноценную модель в Sources/TgClientModels после spike.**
///
/// **TDLib API:** https://core.telegram.org/tdlib/docs/classtd_1_1td__api_1_1view_messages.html
struct ViewMessagesRequest: TDLibRequest, Sendable {
    let type = "viewMessages"

    let chatId: Int64
    let messageIds: [Int64]
    let forceRead: Bool

    // Только @type требует явного маппинга, остальное через .convertToSnakeCase
    enum CodingKeys: String, CodingKey {
        case type = "@type"
        case chatId
        case messageIds
        case forceRead
    }

    init(chatId: Int64, messageIds: [Int64], forceRead: Bool) {
        self.chatId = chatId
        self.messageIds = messageIds
        self.forceRead = forceRead
    }
}
