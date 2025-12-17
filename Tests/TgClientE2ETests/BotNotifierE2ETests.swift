
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
/// - **КРИТИЧНО:** Пользователь уже авторизован в TDLib (сохранённая сессия в ~/.tdlib/)
///   - Для первой авторизации: запустите `swift run tg-client` и пройдите процедуру авторизации
/// - Bot token получен через @BotFather (`/newbot`)
/// - Chat ID получен через `/start` + `curl https://api.telegram.org/bot<TOKEN>/getUpdates`
/// - Переменные окружения настроены:
///   - `TELEGRAM_BOT_TOKEN` — bot token из @BotFather
///   - `TELEGRAM_BOT_CHAT_ID` — chat_id пользователя (Int64)
///   - `TELEGRAM_API_ID`, `TELEGRAM_API_HASH` — для TDLib
///   - `OPENAI_API_KEY` — для SummaryGenerator
/// - У пользователя есть подписки на Telegram каналы с непрочитанными сообщениями
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
    /// 1. Создать бота через @BotFather, получить token
    /// 2. Отправить боту `/start`, получить chat_id через `getUpdates`
    /// 3. Установить env vars: `TELEGRAM_BOT_TOKEN`, `TELEGRAM_BOT_CHAT_ID`
    /// 4. Запустить тест вручную (убрать `.disabled()`)
    /// 5. Проверить в Telegram: бот отправил дайджест
    @Test("Отправка дайджеста через реальный Telegram Bot API", .disabled())
    func sendDigestToTelegramBot() async throws {
        // ⚠️ TODO: Реализовать после создания BotNotifierProtocol и TelegramBotNotifier
        //
        // 1. Создание TDLib клиента (для fetch)
        // 2. Создание OpenAISummaryGenerator (для digest)
        // 3. Создание TelegramBotNotifier (для send)
        // 4. Создание DigestOrchestrator (интеграция pipeline)
        // 5. Запуск orchestrator.run()
        // 6. Проверка: бот отправил дайджест (message_id > 0)
        //
        // Ожидаемый результат:
        // - Дайджест отправлен в Telegram (пользователь видит сообщение)
        // - Логи: "Message sent successfully" с message_id
        // - Сообщения помечены как прочитанные (markAsRead)
    }
}
