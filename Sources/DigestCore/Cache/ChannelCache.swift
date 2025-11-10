import Foundation

/// In-memory кэш для списка каналов с непрочитанными сообщениями.
///
/// **Назначение:**
/// - Хранение Chat объектов, полученных через TDLib updates
/// - Фильтрация каналов с unreadCount > 0
/// - Thread-safe операции (actor isolation)
///
/// **Используется в:**
/// - `ChannelMessageSource` для хранения состояния во время работы
///
/// **Не хранит данные между запусками** (StateManager для персистентности).
public actor ChannelCache {
    /// Хранилище каналов (chatId → ChannelInfo).
    private var channels: [Int64: ChannelInfo] = [:]

    public init() {}

    /// Добавить или обновить канал в кэше.
    ///
    /// **Поведение:**
    /// - Если канал с таким `chatId` уже существует, данные обновляются
    /// - Если канал новый, добавляется в кэш
    ///
    /// **Thread-safe:** actor isolation гарантирует безопасность
    ///
    /// - Parameter channel: информация о канале для сохранения
    public func add(_ channel: ChannelInfo) {
        channels[channel.chatId] = channel
    }

    /// Обновить счётчик непрочитанных сообщений для канала.
    ///
    /// **Поведение:**
    /// - Если канал существует, создаётся новый ChannelInfo с обновлённым unreadCount
    /// - Если канал не найден, операция игнорируется (no-op)
    /// - Остальные поля (title, lastReadInboxMessageId, username) не изменяются
    ///
    /// **Используется при:**
    /// - Обработка TDLib update `updateChatReadInbox`
    /// - Прямое обновление счётчика без полного объекта Chat
    ///
    /// - Parameters:
    ///   - chatId: ID чата (канала)
    ///   - count: новое значение непрочитанных сообщений
    public func updateUnreadCount(chatId: Int64, count: Int32) {
        guard let existingChannel = channels[chatId] else {
            // Канал не найден - игнорируем обновление
            return
        }

        // Создаём новый ChannelInfo с обновлённым unreadCount
        let updatedChannel = ChannelInfo(
            chatId: existingChannel.chatId,
            title: existingChannel.title,
            unreadCount: count,
            lastReadInboxMessageId: existingChannel.lastReadInboxMessageId,
            username: existingChannel.username
        )

        channels[chatId] = updatedChannel
    }

    /// Получить список каналов с непрочитанными сообщениями.
    ///
    /// **Фильтрация:**
    /// - Возвращаются только каналы с `unreadCount > 0`
    ///
    /// **Сортировка:**
    /// - По убыванию `unreadCount` (каналы с большим количеством непрочитанных первыми)
    ///
    /// **Используется для:**
    /// - Получение списка каналов для фетчинга сообщений
    /// - Приоритизация обработки (сначала каналы с большим unreadCount)
    ///
    /// - Returns: массив каналов с непрочитанными сообщениями, отсортированный по убыванию unreadCount
    public func getUnreadChannels() -> [ChannelInfo] {
        return channels.values
            .filter { $0.unreadCount > 0 }
            .sorted { $0.unreadCount > $1.unreadCount }
    }

    /// Удалить канал из кэша.
    ///
    /// **Поведение:**
    /// - Если канал существует, удаляется из кэша
    /// - Если канал не найден, операция игнорируется (no-op)
    ///
    /// **Используется при:**
    /// - Обработка TDLib update `updateDeleteChat` (канал удалён)
    /// - Архивация канала (пользователь покинул канал)
    ///
    /// - Parameter chatId: ID чата (канала) для удаления
    public func remove(chatId: Int64) {
        channels.removeValue(forKey: chatId)
    }
}
