import Testing

/// Placeholder для E2E-тестов.
///
/// E2E тесты используют реальный TDLib и требуют credentials.
/// **НЕ запускаются в CI** — только manual или cron на сервере.
///
/// **Будущие тесты:**
/// - Полный цикл авторизации с реальным Telegram сервером
/// - Получение списка каналов и сообщений
/// - Отправка через реальный Telegram Bot API
///
/// **Запуск:** `swift test --filter TgClientE2ETests` (требует env: TELEGRAM_API_ID, TELEGRAM_API_HASH, etc.)
@Suite("E2E Tests Placeholder", .disabled("Требует реальные credentials"))
struct E2ETestsPlaceholder {
    @Test("Placeholder - E2E тесты будут добавлены после MVP")
    func placeholder() {
        // TODO: Добавить E2E тесты после завершения MVP
        #expect(Bool(true))
    }
}
