import Foundation

/// Подмена `sleep` для кода с инжектируемыми паузами (`withRetry(sleep:)`, `VKLongPollClient(sleep:)`,
/// `TelegramBotNotifier(sleep:)`): пауза мгновенная, длительность записывается. Тест проверяет
/// **какие паузы попросил код** (бэкофф 1s → 2s), а не ждёт их по реальным часам.
public actor SleepRecorder {
    public private(set) var durations: [Duration] = []

    public init() {}

    public nonisolated var sleep: @Sendable (Duration) async throws -> Void {
        { [self] duration in await self.record(duration) }
    }

    private func record(_ duration: Duration) {
        durations.append(duration)
    }
}
