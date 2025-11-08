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
    // TODO: Реализовать хранилище каналов
    // private var channels: [Int64: ChannelInfo] = [:]

    public init() {}

    // TODO: Добавить методы:
    // func add(_ chat: Chat)
    // func updateUnreadCount(chatId: Int64, count: Int32)
    // func getUnreadChannels() -> [ChannelInfo]
    // func remove(chatId: Int64)
}
