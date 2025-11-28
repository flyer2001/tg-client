#if ENABLE_E2E_TESTS

import TgClientModels
import TGClientInterfaces
import Foundation
import Testing
import Logging
@testable import TDLibAdapter
@testable import DigestCore
@testable import TestHelpers

/// E2E тест для сценария получения непрочитанных сообщений из каналов.
///
/// **User Story:** Получить список всех непрочитанных сообщений из подписанных Telegram каналов
/// для создания AI-дайджеста.
///
/// **Сценарий:** <doc:FetchUnreadMessages>
///
/// **Предусловия:**
/// - **КРИТИЧНО:** Пользователь уже авторизован в TDLib (сохранённая сессия в ~/.tdlib/)
///   - Для первой авторизации: запустите `swift run tg-client` и пройдите процедуру авторизации
///   - Введите номер телефона, OTP код, 2FA пароль (если требуется)
///   - После успешной авторизации сессия сохраняется в ~/.tdlib/
/// - Переменные окружения настроены:
///   - `TELEGRAM_API_ID`
///   - `TELEGRAM_API_HASH`
/// - У пользователя есть подписки на Telegram каналы
/// - В некоторых каналах есть непрочитанные сообщения
@Suite("E2E: Получение непрочитанных сообщений из каналов")
struct FetchUnreadMessagesScenarioTests {

    /// E2E тест: получение непрочитанных сообщений из реальных каналов.
    ///
    /// **Что тестируем:**
    /// - Полный цикл: авторизация → loadChats → getChat → фильтрация каналов → getChatHistory
    /// - Структуру возвращаемых данных (SourceMessage)
    /// - Корректность ссылок на сообщения (для публичных каналов)
    @Test("Получение непрочитанных сообщений через реальный TDLib")
    func fetchUnreadMessagesFromRealChannels() async throws {
        // 1. Создание TDLib клиента и загрузка config из переменных окружения
        let logger = Logger(label: "tg-client.e2e")
        let tdlib = TDLibClient(appLogger: logger)

        let config = try TDConfig.forTesting()

        // 2. Запуск TDLib с авторизацией (если сессия сохранена в ~/.tdlib, авторизация пропускается)
        try await tdlib.start(config: config, promptFor: { prompt in
            // ⚠️ E2E тест предполагает что авторизация УЖЕ выполнена (сессия сохранена)
            // Если попали сюда - значит нужна интерактивная авторизация (сессия отсутствует)
            let message = """
            ❌ E2E тест требует предварительной авторизации!

            Выполните следующие шаги:
            1. Запустите: swift run tg-client
            2. Пройдите процедуру авторизации (номер телефона, OTP, 2FA пароль)
            3. После успешной авторизации сессия сохранится в ~/.tdlib/
            4. Повторите запуск E2E теста

            Prompt запрошенный TDLib: \(prompt)
            """
            fatalError(message)
        })

        // 3. Создание ChannelMessageSource
        let sourceLogger = Logger(label: "tg-client.e2e.message-source")
        let messageSource = ChannelMessageSource(tdlib: tdlib, logger: sourceLogger)

        // 4. Получение непрочитанных сообщений
        let messages = try await messageSource.fetchUnreadMessages()

        // 5. Проверка результата
        if messages.isEmpty {
            // Edge case: нет непрочитанных — это валидный сценарий
            print("No unread messages found (valid scenario)")
        } else {
            // Проверяем структуру первого сообщения
            let firstMessage = messages[0]
            // chatId для каналов/супергрупп отрицательный (начинается с -100)
            #expect(firstMessage.chatId != 0)
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

#endif // ENABLE_E2E_TESTS
