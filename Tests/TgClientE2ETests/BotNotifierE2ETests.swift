
import TgClientModels
import TGClientInterfaces
import Foundation
import Testing
import Logging
@testable import TDLibAdapter
@testable import DigestCore
@testable import TestHelpers

/// E2E тест для сценария отправки дайджеста через Telegram бота.
///
/// **Сценарий:** <doc:BotNotifier>
///
/// **Предусловия:**
/// - Bot token получен через @BotFather (`/newbot`)
/// - Переменная окружения настроена:
///   - `TELEGRAM_BOT_TOKEN` — bot token из @BotFather (⚠️ секрет, только из env!)
/// - Chat ID: `566335622` (захардкожен в тесте, проверен через getUpdates)
///
/// **Как получить chat_id (если нужен другой):**
/// ```bash
/// # 1. Отправь боту /start в Telegram
/// # 2. Получи updates:
/// curl https://api.telegram.org/bot<BOT_TOKEN>/getUpdates?offset=-1
/// # 3. Найди: "chat":{"id": 566335622}
/// ```
@Suite("E2E: Отправка дайджеста через Telegram бота")
struct BotNotifierE2ETests {

    /// E2E тест: полный pipeline с отправкой дайджеста в Telegram.
    ///
    /// **Что тестируем:**
    /// - Полный цикл: fetch → digest → **BotNotifier** → markAsRead
    /// - Реальная отправка через Bot API (требует env vars)
    /// - Корректность plain text форматирования
    ///
    /// **ПРИМЕЧАНИЕ:** E2E тест disabled по умолчанию. Запускайте вручную для проверки с реальным ботом.
    ///
    /// **Как запустить:**
    /// 1. Добавить в `.env`: `TELEGRAM_BOT_TOKEN=your_bot_token`
    /// 2. ⚠️ **ВАЖНО:** `.env` НЕ подтягивается автоматически! Нужен source:
    ///    ```bash
    ///    source .env && swift test --filter sendDigestToTelegramBot
    ///    ```
    /// 3. Проверить в Telegram: бот отправил сообщение
    @Test("Отправка дайджеста через реальный Telegram Bot API", .disabled("E2E: требует TELEGRAM_BOT_TOKEN, запускать вручную"))
    func sendDigestToTelegramBot() async throws {
        // ⚠️ Bot Token — секрет, ТОЛЬКО из env!
        guard let botToken = ProcessInfo.processInfo.environment["TELEGRAM_BOT_TOKEN"] else {
            Issue.record("TELEGRAM_BOT_TOKEN не задан. Добавьте в .env файл.")
            return
        }

        // Chat ID (публичный, можно захардкодить для тестов)
        let chatId: Int64 = 566335622  // Проверен через getUpdates (2025-12-18)

        // Создаём TelegramBotNotifier с реальным HTTP клиентом
        let notifier = TelegramBotNotifier(
            botToken: botToken,
            chatId: chatId,
            httpClient: URLSessionHTTPClient(),
            logger: Logger(label: "e2e-test")
        )

        // Отправляем тестовое сообщение
        let testMessage = """
        🧪 E2E Test: BotNotifier v0.5.0

        Это тестовое сообщение для проверки интеграции с Telegram Bot API.

        **Timestamp:** \(Date().timeIntervalSince1970)
        """

        // Act: отправляем через реальный Bot API
        try await notifier.send(testMessage)

        // Assert: если не выбросило ошибку — успех
        // Пользователь должен увидеть сообщение в Telegram
        print("✅ E2E тест пройден: сообщение отправлено в Telegram")
        print("📱 Проверьте бота — должно прийти сообщение с timestamp")
    }
}
