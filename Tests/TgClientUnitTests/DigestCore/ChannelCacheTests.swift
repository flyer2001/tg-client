import XCTest
@testable import DigestCore

/// Unit-тесты для ChannelCache.
///
/// **Тестируемая функциональность:**
/// - Добавление каналов (игнорирование non-channels)
/// - Обновление unreadCount
/// - Получение списка непрочитанных каналов
/// - Удаление каналов (архивация)
/// - Thread-safety (actor isolation)
///
/// **RED фаза (TDD):**
/// Тесты написаны ДО реализации ChannelCache.
/// Ожидаемое поведение задокументировано в комментариях.
final class ChannelCacheTests: XCTestCase {

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
    func testAddChannel_EmptyCache_AddsSuccessfully() async throws {
        let cache = ChannelCache()
        let channel = makeChannelInfo(chatId: 1, title: "Test", unreadCount: 3)

        await cache.add(channel)

        let unreadChannels = await cache.getUnreadChannels()
        XCTAssertEqual(unreadChannels.count, 1)
        XCTAssertEqual(unreadChannels.first?.chatId, 1)
        XCTAssertEqual(unreadChannels.first?.title, "Test")
        XCTAssertEqual(unreadChannels.first?.unreadCount, 3)
    }

    /// Тест: добавление канала с unreadCount = 0 (не должен появиться в getUnreadChannels).
    ///
    /// **Ожидается:**
    /// - Канал сохранён в кэше
    /// - getUnreadChannels() не возвращает этот канал
    func testAddChannel_ZeroUnreadCount_NotInUnreadList() async throws {
        let cache = ChannelCache()
        let channel = makeChannelInfo(chatId: 1, unreadCount: 0)

        await cache.add(channel)

        let unreadChannels = await cache.getUnreadChannels()
        XCTAssertEqual(unreadChannels.count, 0, "Канал с unreadCount=0 не должен быть в списке непрочитанных")
    }

    /// Тест: повторное добавление канала (обновление данных).
    ///
    /// **Ожидается:**
    /// - Данные канала обновлены (title, unreadCount, lastReadInboxMessageId)
    /// - chatId остаётся прежним (ключ)
    func testAddChannel_DuplicateChatId_UpdatesExisting() async throws {
        let cache = ChannelCache()
        let channel1 = makeChannelInfo(chatId: 1, title: "Old Title", unreadCount: 5)
        let channel2 = makeChannelInfo(chatId: 1, title: "New Title", unreadCount: 10)

        await cache.add(channel1)
        await cache.add(channel2)

        let unreadChannels = await cache.getUnreadChannels()
        XCTAssertEqual(unreadChannels.count, 1, "Должен быть только один канал с chatId=1")
        XCTAssertEqual(unreadChannels.first?.title, "New Title")
        XCTAssertEqual(unreadChannels.first?.unreadCount, 10)
    }

    // MARK: - Tests: updateUnreadCount(chatId:count:)

    /// Тест: обновление unreadCount для существующего канала.
    ///
    /// **Ожидается:**
    /// - unreadCount обновлён
    /// - Остальные поля (title, lastReadInboxMessageId) не изменены
    func testUpdateUnreadCount_ExistingChannel_UpdatesSuccessfully() async throws {
        let cache = ChannelCache()
        let channel = makeChannelInfo(chatId: 1, title: "Test", unreadCount: 5, lastReadInboxMessageId: 100)

        await cache.add(channel)
        await cache.updateUnreadCount(chatId: 1, count: 15)

        let unreadChannels = await cache.getUnreadChannels()
        XCTAssertEqual(unreadChannels.first?.unreadCount, 15)
        XCTAssertEqual(unreadChannels.first?.title, "Test", "Title не должен измениться")
        XCTAssertEqual(unreadChannels.first?.lastReadInboxMessageId, 100, "lastReadInboxMessageId не должен измениться")
    }

    /// Тест: обновление unreadCount до 0 (канал исчезает из getUnreadChannels).
    ///
    /// **Ожидается:**
    /// - Канал остаётся в кэше (не удаляется)
    /// - getUnreadChannels() не возвращает этот канал
    func testUpdateUnreadCount_ToZero_RemovesFromUnreadList() async throws {
        let cache = ChannelCache()
        let channel = makeChannelInfo(chatId: 1, unreadCount: 5)

        await cache.add(channel)
        await cache.updateUnreadCount(chatId: 1, count: 0)

        let unreadChannels = await cache.getUnreadChannels()
        XCTAssertEqual(unreadChannels.count, 0, "Канал с unreadCount=0 не должен быть в списке")
    }

    /// Тест: обновление unreadCount для несуществующего канала (no-op).
    ///
    /// **Ожидается:**
    /// - Операция игнорируется (не выбрасывает ошибку)
    /// - Кэш остаётся пустым
    func testUpdateUnreadCount_NonExistentChannel_NoOp() async throws {
        let cache = ChannelCache()

        await cache.updateUnreadCount(chatId: 999, count: 10)

        let unreadChannels = await cache.getUnreadChannels()
        XCTAssertEqual(unreadChannels.count, 0, "Обновление несуществующего канала не должно создавать запись")
    }

    // MARK: - Tests: getUnreadChannels()

    /// Тест: получение списка непрочитанных каналов (пустой кэш).
    ///
    /// **Ожидается:**
    /// - Возвращается пустой массив
    func testGetUnreadChannels_EmptyCache_ReturnsEmpty() async throws {
        let cache = ChannelCache()

        let unreadChannels = await cache.getUnreadChannels()

        XCTAssertEqual(unreadChannels.count, 0)
    }

    /// Тест: фильтрация каналов (только unreadCount > 0).
    ///
    /// **Ожидается:**
    /// - Возвращаются только каналы с unreadCount > 0
    /// - Каналы с unreadCount = 0 игнорируются
    func testGetUnreadChannels_MixedChannels_ReturnsOnlyUnread() async throws {
        let cache = ChannelCache()
        await cache.add(makeChannelInfo(chatId: 1, title: "Channel 1", unreadCount: 5))
        await cache.add(makeChannelInfo(chatId: 2, title: "Channel 2", unreadCount: 0))
        await cache.add(makeChannelInfo(chatId: 3, title: "Channel 3", unreadCount: 10))

        let unreadChannels = await cache.getUnreadChannels()

        XCTAssertEqual(unreadChannels.count, 2)
        XCTAssertTrue(unreadChannels.contains(where: { $0.chatId == 1 }))
        XCTAssertTrue(unreadChannels.contains(where: { $0.chatId == 3 }))
        XCTAssertFalse(unreadChannels.contains(where: { $0.chatId == 2 }), "Канал с unreadCount=0 не должен быть в списке")
    }

    /// Тест: сортировка каналов (по убыванию unreadCount).
    ///
    /// **Ожидается:**
    /// - Каналы отсортированы: сначала с большим unreadCount
    func testGetUnreadChannels_MultiplChannels_SortedByUnreadCount() async throws {
        let cache = ChannelCache()
        await cache.add(makeChannelInfo(chatId: 1, unreadCount: 3))
        await cache.add(makeChannelInfo(chatId: 2, unreadCount: 15))
        await cache.add(makeChannelInfo(chatId: 3, unreadCount: 7))

        let unreadChannels = await cache.getUnreadChannels()

        XCTAssertEqual(unreadChannels.count, 3)
        XCTAssertEqual(unreadChannels[0].chatId, 2, "Первый канал должен иметь самый большой unreadCount")
        XCTAssertEqual(unreadChannels[1].chatId, 3)
        XCTAssertEqual(unreadChannels[2].chatId, 1)
    }

    // MARK: - Tests: remove(chatId:)

    /// Тест: удаление существующего канала.
    ///
    /// **Ожидается:**
    /// - Канал удалён из кэша
    /// - getUnreadChannels() не возвращает этот канал
    func testRemoveChannel_ExistingChannel_RemovesSuccessfully() async throws {
        let cache = ChannelCache()
        await cache.add(makeChannelInfo(chatId: 1, unreadCount: 5))
        await cache.add(makeChannelInfo(chatId: 2, unreadCount: 10))

        await cache.remove(chatId: 1)

        let unreadChannels = await cache.getUnreadChannels()
        XCTAssertEqual(unreadChannels.count, 1)
        XCTAssertEqual(unreadChannels.first?.chatId, 2)
    }

    /// Тест: удаление несуществующего канала (no-op).
    ///
    /// **Ожидается:**
    /// - Операция игнорируется (не выбрасывает ошибку)
    func testRemoveChannel_NonExistentChannel_NoOp() async throws {
        let cache = ChannelCache()
        await cache.add(makeChannelInfo(chatId: 1, unreadCount: 5))

        await cache.remove(chatId: 999)

        let unreadChannels = await cache.getUnreadChannels()
        XCTAssertEqual(unreadChannels.count, 1, "Удаление несуществующего канала не должно влиять на кэш")
    }

    // MARK: - Tests: Edge Cases

    /// Тест: корректность работы с Int64.max и Int32.max.
    ///
    /// **Ожидается:**
    /// - Нет переполнения или крэшей
    func testEdgeCases_MaxValues_HandlesCorrectly() async throws {
        let cache = ChannelCache()
        let channel = makeChannelInfo(
            chatId: Int64.max,
            unreadCount: Int32.max,
            lastReadInboxMessageId: Int64.max
        )

        await cache.add(channel)

        let unreadChannels = await cache.getUnreadChannels()
        XCTAssertEqual(unreadChannels.first?.chatId, Int64.max)
        XCTAssertEqual(unreadChannels.first?.unreadCount, Int32.max)
    }

    /// Тест: работа с nil username (приватные каналы).
    ///
    /// **Ожидается:**
    /// - Канал корректно сохраняется с username = nil
    func testEdgeCases_NilUsername_HandlesCorrectly() async throws {
        let cache = ChannelCache()
        let channel = makeChannelInfo(chatId: 1, username: nil)

        await cache.add(channel)

        let unreadChannels = await cache.getUnreadChannels()
        XCTAssertNil(unreadChannels.first?.username)
    }
}
