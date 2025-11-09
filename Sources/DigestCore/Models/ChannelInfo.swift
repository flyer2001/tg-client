import Foundation

/// Информация о канале для кэширования в ChannelCache.
///
/// **Назначение:**
/// Упрощённая модель канала для внутреннего использования в DigestCore.
/// Содержит только необходимые поля для работы с непрочитанными сообщениями.
///
/// **Маппинг из TDLib:**
/// `Chat` (TDLib Response) → `ChannelInfo` (DigestCore Model)
///
/// **Используется в:**
/// - `ChannelCache` - кэширование списка каналов
/// - `MessageFetcher` - получение сообщений из каналов
///
/// **Отличие от `Chat` (TDLib):**
/// - Не содержит избыточные поля (permissions, photo, etc.)
/// - Содержит только данные для фильтрации и получения сообщений
public struct ChannelInfo: Sendable, Codable, Equatable {
    /// ID чата (канала).
    ///
    /// Используется для вызова TDLib методов: `getChatHistory`, `viewMessages`.
    public let chatId: Int64

    /// Название канала.
    ///
    /// Отображается в дайджесте для группировки сообщений по каналам.
    public let title: String

    /// Количество непрочитанных сообщений.
    ///
    /// **Используется для фильтрации:**
    /// - `getUnreadChannels()` возвращает только каналы с `unreadCount > 0`
    ///
    /// **Обновляется через:**
    /// - TDLib updates: `updateChatReadInbox`
    /// - `ChannelCache.updateUnreadCount(chatId:count:)`
    public let unreadCount: Int32

    /// ID последнего прочитанного сообщения.
    ///
    /// **Используется для:**
    /// - Параметр `fromMessageId` в `getChatHistory` (получить непрочитанные)
    /// - Валидация корректности `unreadCount`
    ///
    /// **TDLib docs:** https://core.telegram.org/tdlib/docs/classtd_1_1td__api_1_1chat.html#a8c0c4d1f9c5c5f5e5f5f5f5f5f5f5f5f
    public let lastReadInboxMessageId: Int64

    /// Username канала (для публичных каналов).
    ///
    /// **Используется для формирования ссылок:**
    /// - Публичные каналы: `https://t.me/{username}/{messageId}`
    /// - Приватные каналы: `username == nil`, ссылка не создаётся
    ///
    /// **Пример:**
    /// ```swift
    /// if let username = channelInfo.username {
    ///     let link = "https://t.me/\(username)/\(messageId)"
    /// }
    /// ```
    public let username: String?

    public init(
        chatId: Int64,
        title: String,
        unreadCount: Int32,
        lastReadInboxMessageId: Int64,
        username: String?
    ) {
        self.chatId = chatId
        self.title = title
        self.unreadCount = unreadCount
        self.lastReadInboxMessageId = lastReadInboxMessageId
        self.username = username
    }
}
