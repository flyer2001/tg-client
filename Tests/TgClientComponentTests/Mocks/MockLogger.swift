import TgClientModels
import TGClientInterfaces
import Foundation
import Logging

/// Mock реализация Logger для component-тестов.
///
/// Захватывает все логи в память для последующей проверки в тестах.
///
/// **Thread Safety:**
/// NSLock защищает `messages` array от concurrent access.
///
/// **Использование:**
/// ```swift
/// let mockLogger = MockLogger()
/// let logger = mockLogger.makeLogger(label: "test")
///
/// // Используем в тестируемом коде
/// logger.error("TDLib error [404]: Not found")
///
/// // Проверяем что было залогировано
/// #expect(mockLogger.messages.count == 1)
/// #expect(mockLogger.messages[0].level == .error)
/// #expect(mockLogger.messages[0].message.contains("TDLib error"))
/// ```
public final class MockLogger: @unchecked Sendable {

    /// Структура для хранения залогированного сообщения
    public struct LogMessage: Sendable {
        public let level: Logger.Level
        public let message: String
    }

    /// Lock для защиты shared mutable state (messages array)
    private let lock = NSLock()

    /// Все захваченные логи (thread-safe доступ через lock)
    private var _messages: [LogMessage] = []

    /// Thread-safe accessor для messages
    public var messages: [LogMessage] {
        lock.lock()
        defer { lock.unlock() }
        return _messages
    }

    public init() {}

    /// Создаёт настоящий Logging.Logger, который пишет в MockLogger.
    ///
    /// - Parameter label: Метка логгера
    /// - Returns: Настоящий Logger, который захватывает логи
    public func makeLogger(label: String) -> Logger {
        return Logger(label: label) { _ in
            MockLogHandler(mockLogger: self)
        }
    }

    /// Записывает лог-сообщение (используется внутренне LogHandler)
    func log(level: Logger.Level, message: String) {
        lock.lock()
        defer { lock.unlock() }
        _messages.append(LogMessage(level: level, message: message))
    }
}

// MARK: - MockLogHandler

/// LogHandler который перенаправляет все логи в MockLogger.
private struct MockLogHandler: LogHandler {
    let mockLogger: MockLogger

    var logLevel: Logger.Level = .trace
    var metadata: Logger.Metadata = [:]

    subscript(metadataKey key: String) -> Logger.Metadata.Value? {
        get { metadata[key] }
        set { metadata[key] = newValue }
    }

    func log(level: Logger.Level,
             message: Logger.Message,
             metadata: Logger.Metadata?,
             source: String,
             file: String,
             function: String,
             line: UInt) {
        mockLogger.log(level: level, message: message.description)
    }
}
