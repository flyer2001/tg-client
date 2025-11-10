import Foundation
import Testing
@testable import DigestCore

/// Unit-тесты для ChannelCache.
///
/// **Тестируемая функциональность:**
/// - Добавление каналов (обновление при дубликатах)
/// - Обновление unreadCount
/// - Получение списка непрочитанных каналов (фильтрация + сортировка)
/// - Удаление каналов
/// - Thread-safety (actor isolation)
///
/// **RED фаза (TDD):**
/// Тесты написаны ДО реализации ChannelCache.
/// Ожидаемое поведение задокументировано в комментариях.
@Suite("Unit-тесты для ChannelCache")
struct ChannelCacheTests {

    // MARK: - Test Data Helpers

    /// Создать тестовый ChannelInfo.
    private func makeChannelInfo(
        chatId: Int64 = 1,
        title: String = "Test Channel",
        unreadCount: Int32 = 5,
        lastReadInboxMessageId: Int64 = 100,
        username: String? = "testchannel"
    ) -> ChannelInfo {
        ChannelInfo(
            chatId: chatId,
            title: title,
            unreadCount: unreadCount,
            lastReadInboxMessageId: lastReadInboxMessageId,
            username: username
        )
    }

    // MARK: - Tests: add(_:)

    /// Тест: добавление канала в пустой кэш.
    ///
    /// **Ожидается:**
    /// - Канал сохранён с правильными данными
    /// - getUnreadChannels() возвращает этот канал (если unreadCount > 0)
    @Test("Добавление канала в пустой кэш")
    func addChannelToEmptyCache() async throws {
        let cache = ChannelCache()
        let channel = makeChannelInfo(chatId: 1, title: "Test", unreadCount: 3)

        await cache.add(channel)

        let unreadChannels = await cache.getUnreadChannels()
        #expect(unreadChannels.count == 1)
        #expect(unreadChannels.first?.chatId == 1)
        #expect(unreadChannels.first?.title == "Test")
        #expect(unreadChannels.first?.unreadCount == 3)
    }

    /// Тест: добавление канала с unreadCount = 0 (не должен появиться в getUnreadChannels).
    ///
    /// **Ожидается:**
    /// - Канал сохранён в кэше
    /// - getUnreadChannels() не возвращает этот канал
    @Test("Добавление канала с unreadCount=0")
    func addChannelWithZeroUnreadCount() async throws {
        let cache = ChannelCache()
        let channel = makeChannelInfo(chatId: 1, unreadCount: 0)

        await cache.add(channel)

        let unreadChannels = await cache.getUnreadChannels()
        #expect(unreadChannels.isEmpty, "Канал с unreadCount=0 не должен быть в списке непрочитанных")
    }

    /// Тест: повторное добавление канала (обновление данных).
    ///
    /// **Ожидается:**
    /// - Данные канала обновлены (title, unreadCount, lastReadInboxMessageId)
    /// - chatId остаётся прежним (ключ)
    @Test("Повторное добавление канала обновляет данные")
    func addDuplicateChannelUpdatesExisting() async throws {
        let cache = ChannelCache()
        let channel1 = makeChannelInfo(chatId: 1, title: "Old Title", unreadCount: 5)
        let channel2 = makeChannelInfo(chatId: 1, title: "New Title", unreadCount: 10)

        await cache.add(channel1)
        await cache.add(channel2)

        let unreadChannels = await cache.getUnreadChannels()
        #expect(unreadChannels.count == 1, "Должен быть только один канал с chatId=1")
        #expect(unreadChannels.first?.title == "New Title")
        #expect(unreadChannels.first?.unreadCount == 10)
    }

    // MARK: - Tests: updateUnreadCount(chatId:count:)

    /// Тест: обновление unreadCount для существующего канала.
    ///
    /// **Ожидается:**
    /// - unreadCount обновлён
    /// - Остальные поля (title, lastReadInboxMessageId) не изменены
    @Test("Обновление unreadCount для существующего канала")
    func updateUnreadCountForExistingChannel() async throws {
        let cache = ChannelCache()
        let channel = makeChannelInfo(chatId: 1, title: "Test", unreadCount: 5, lastReadInboxMessageId: 100)

        await cache.add(channel)
        await cache.updateUnreadCount(chatId: 1, count: 15)

        let unreadChannels = await cache.getUnreadChannels()
        #expect(unreadChannels.first?.unreadCount == 15)
        #expect(unreadChannels.first?.title == "Test", "Title не должен измениться")
        #expect(unreadChannels.first?.lastReadInboxMessageId == 100, "lastReadInboxMessageId не должен измениться")
    }

    /// Тест: обновление unreadCount до 0 (канал исчезает из getUnreadChannels).
    ///
    /// **Ожидается:**
    /// - Канал остаётся в кэше (не удаляется)
    /// - getUnreadChannels() не возвращает этот канал
    @Test("Обновление unreadCount до 0 убирает канал из списка непрочитанных")
    func updateUnreadCountToZeroRemovesFromList() async throws {
        let cache = ChannelCache()
        let channel = makeChannelInfo(chatId: 1, unreadCount: 5)

        await cache.add(channel)
        await cache.updateUnreadCount(chatId: 1, count: 0)

        let unreadChannels = await cache.getUnreadChannels()
        #expect(unreadChannels.isEmpty, "Канал с unreadCount=0 не должен быть в списке")
    }

    /// Тест: обновление unreadCount для несуществующего канала (no-op).
    ///
    /// **Ожидается:**
    /// - Операция игнорируется (не выбрасывает ошибку)
    /// - Кэш остаётся пустым
    @Test("Обновление unreadCount для несуществующего канала - no-op")
    func updateUnreadCountForNonExistentChannel() async throws {
        let cache = ChannelCache()

        await cache.updateUnreadCount(chatId: 999, count: 10)

        let unreadChannels = await cache.getUnreadChannels()
        #expect(unreadChannels.isEmpty, "Обновление несуществующего канала не должно создавать запись")
    }

    // MARK: - Tests: getUnreadChannels()

    /// Тест: получение списка непрочитанных каналов (пустой кэш).
    ///
    /// **Ожидается:**
    /// - Возвращается пустой массив
    @Test("Получение списка из пустого кэша возвращает пустой массив")
    func getUnreadChannelsFromEmptyCache() async throws {
        let cache = ChannelCache()

        let unreadChannels = await cache.getUnreadChannels()

        #expect(unreadChannels.isEmpty)
    }

    /// Тест: фильтрация каналов (только unreadCount > 0).
    ///
    /// **Ожидается:**
    /// - Возвращаются только каналы с unreadCount > 0
    /// - Каналы с unreadCount = 0 игнорируются
    @Test("Фильтрация: возвращаются только каналы с unreadCount > 0")
    func getUnreadChannelsFiltersZeroUnread() async throws {
        let cache = ChannelCache()
        await cache.add(makeChannelInfo(chatId: 1, title: "Channel 1", unreadCount: 5))
        await cache.add(makeChannelInfo(chatId: 2, title: "Channel 2", unreadCount: 0))
        await cache.add(makeChannelInfo(chatId: 3, title: "Channel 3", unreadCount: 10))

        let unreadChannels = await cache.getUnreadChannels()

        #expect(unreadChannels.count == 2)
        #expect(unreadChannels.contains(where: { $0.chatId == 1 }))
        #expect(unreadChannels.contains(where: { $0.chatId == 3 }))
        #expect(!unreadChannels.contains(where: { $0.chatId == 2 }), "Канал с unreadCount=0 не должен быть в списке")
    }

    /// Тест: сортировка каналов (по убыванию unreadCount).
    ///
    /// **Ожидается:**
    /// - Каналы отсортированы: сначала с большим unreadCount
    @Test("Сортировка: каналы отсортированы по убыванию unreadCount")
    func getUnreadChannelsSortedByUnreadCountDesc() async throws {
        let cache = ChannelCache()
        await cache.add(makeChannelInfo(chatId: 1, unreadCount: 3))
        await cache.add(makeChannelInfo(chatId: 2, unreadCount: 15))
        await cache.add(makeChannelInfo(chatId: 3, unreadCount: 7))

        let unreadChannels = await cache.getUnreadChannels()

        #expect(unreadChannels.count == 3)
        #expect(unreadChannels[0].chatId == 2, "Первый канал должен иметь самый большой unreadCount")
        #expect(unreadChannels[1].chatId == 3)
        #expect(unreadChannels[2].chatId == 1)
    }

    // MARK: - Tests: remove(chatId:)

    /// Тест: удаление существующего канала.
    ///
    /// **Ожидается:**
    /// - Канал удалён из кэша
    /// - getUnreadChannels() не возвращает этот канал
    @Test("Удаление существующего канала")
    func removeExistingChannel() async throws {
        let cache = ChannelCache()
        await cache.add(makeChannelInfo(chatId: 1, unreadCount: 5))
        await cache.add(makeChannelInfo(chatId: 2, unreadCount: 10))

        await cache.remove(chatId: 1)

        let unreadChannels = await cache.getUnreadChannels()
        #expect(unreadChannels.count == 1)
        #expect(unreadChannels.first?.chatId == 2)
    }

    /// Тест: удаление несуществующего канала (no-op).
    ///
    /// **Ожидается:**
    /// - Операция игнорируется (не выбрасывает ошибку)
    @Test("Удаление несуществующего канала - no-op")
    func removeNonExistentChannel() async throws {
        let cache = ChannelCache()
        await cache.add(makeChannelInfo(chatId: 1, unreadCount: 5))

        await cache.remove(chatId: 999)

        let unreadChannels = await cache.getUnreadChannels()
        #expect(unreadChannels.count == 1, "Удаление несуществующего канала не должно влиять на кэш")
    }

    // MARK: - Tests: Edge Cases

    /// Тест: корректность работы с Int64.max и Int32.max.
    ///
    /// **Ожидается:**
    /// - Нет переполнения или крэшей
    @Test("Edge case: Int64.max и Int32.max")
    func handlesMaxValues() async throws {
        let cache = ChannelCache()
        let channel = makeChannelInfo(
            chatId: Int64.max,
            unreadCount: Int32.max,
            lastReadInboxMessageId: Int64.max
        )

        await cache.add(channel)

        let unreadChannels = await cache.getUnreadChannels()
        #expect(unreadChannels.first?.chatId == Int64.max)
        #expect(unreadChannels.first?.unreadCount == Int32.max)
    }

    /// Тест: работа с nil username (приватные каналы).
    ///
    /// **Ожидается:**
    /// - Канал корректно сохраняется с username = nil
    @Test("Edge case: nil username для приватных каналов")
    func handlesNilUsername() async throws {
        let cache = ChannelCache()
        let channel = makeChannelInfo(chatId: 1, username: nil)

        await cache.add(channel)

        let unreadChannels = await cache.getUnreadChannels()
        #expect(unreadChannels.first?.username == nil)
    }
}
