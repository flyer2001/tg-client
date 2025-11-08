import Foundation

/// Протокол для получения непрочитанных сообщений из различных источников (каналы, группы, личные чаты).
///
/// **Реализации:**
/// - `ChannelMessageSource` - получение из Telegram каналов
/// - `GroupChatMessageSource` - получение из групп (будущая версия)
/// - `PrivateChatMessageSource` - получение из личных чатов (будущая версия)
public protocol MessageSourceProtocol: Sendable {
    /// Получить список непрочитанных сообщений.
    ///
    /// - Returns: Массив `SourceMessage` с непрочитанными сообщениями.
    /// - Throws: Ошибки TDLib при получении данных.
    func fetchUnreadMessages() async throws -> [SourceMessage]

    /// Отметить сообщения как прочитанные.
    ///
    /// - Parameter messages: Сообщения для отметки.
    /// - Throws: Ошибки TDLib при отметке сообщений.
    func markAsRead(messages: [SourceMessage]) async throws
}
