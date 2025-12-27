import Foundation

/// Протокол для отправки уведомлений через Telegram бота.
///
/// ## Использование
///
/// ```swift
/// let notifier = TelegramBotNotifier(
///     token: botToken,
///     chatId: chatId,
///     httpClient: httpClient,
///     logger: logger
/// )
///
/// try await notifier.send("Дайджест непрочитанных сообщений...")
/// ```
///
/// ## Ссылки
///
/// - Telegram Bot API: https://core.telegram.org/bots/api#sendmessage
///
/// **Реализации:**
/// - ``TelegramBotNotifier`` — отправка через Telegram Bot API
public protocol BotNotifierProtocol: Sendable {
    /// Отправляет текстовое сообщение пользователю через Telegram бота.
    ///
    /// - Parameter message: Текст дайджеста
    /// - Throws: ``BotNotifierError`` при ошибках API
    func send(_ message: String) async throws
}
