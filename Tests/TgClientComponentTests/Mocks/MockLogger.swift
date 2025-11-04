import Foundation
import Logging

/// Mock реализация Logger для component-тестов.
///
/// Захватывает все логи в память для последующей проверки в тестах.
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

    /// Все захваченные логи (публичный для прямой проверки в тестах)
    public var messages: [LogMessage] = []

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
        messages.append(LogMessage(level: level, message: message))
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
