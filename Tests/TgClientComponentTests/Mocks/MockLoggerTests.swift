import Testing
import Logging
@testable import TDLibAdapter

/// Тесты для MockLogger.
///
/// Проверяет что MockLogger корректно захватывает логи от настоящего Logger.
@Suite("MockLogger: Log Capturing")
struct MockLoggerTests {

    /// Тест захвата логов разных уровней.
    @Test("Captures logs at different levels")
    func capturesLogsAtDifferentLevels() {
        // Given: Mock logger
        let mockLogger = MockLogger()
        let logger = mockLogger.makeLogger(label: "test")

        // When: Логируем сообщения разных уровней
        logger.trace("Trace message")
        logger.debug("Debug message")
        logger.info("Info message")
        logger.warning("Warning message")
        logger.error("Error message")
        logger.critical("Critical message")

        // Then: Все сообщения захвачены
        #expect(mockLogger.messages.count == 6)

        // Проверяем уровни
        #expect(mockLogger.messages[0].level == .trace)
        #expect(mockLogger.messages[1].level == .debug)
        #expect(mockLogger.messages[2].level == .info)
        #expect(mockLogger.messages[3].level == .warning)
        #expect(mockLogger.messages[4].level == .error)
        #expect(mockLogger.messages[5].level == .critical)

        // Проверяем содержимое
        #expect(mockLogger.messages[2].message == "Info message")
        #expect(mockLogger.messages[4].message == "Error message")
    }

    /// Тест захвата ошибок TDLib.
    @Test("Captures TDLib error logs")
    func capturesTDLibErrorLogs() {
        // Given: Mock logger
        let mockLogger = MockLogger()
        let logger = mockLogger.makeLogger(label: "tg-client")

        // When: Логируем ошибку в формате TDLib
        logger.error("TDLib error [404]: Chat not found")

        // Then: Ошибка захвачена
        #expect(mockLogger.messages.count == 1)
        #expect(mockLogger.messages[0].level == .error)
        #expect(mockLogger.messages[0].message.contains("TDLib error"))
        #expect(mockLogger.messages[0].message.contains("[404]"))
    }

    /// Тест фильтрации логов по уровню.
    @Test("Filter logs by level manually")
    func filterLogsByLevel() {
        // Given: Mock logger с несколькими логами
        let mockLogger = MockLogger()
        let logger = mockLogger.makeLogger(label: "test")

        logger.info("Info 1")
        logger.error("Error 1")
        logger.info("Info 2")
        logger.error("Error 2")

        // When: Фильтруем вручную
        let errors = mockLogger.messages.filter { $0.level == .error }
        let infos = mockLogger.messages.filter { $0.level == .info }

        // Then: Правильная фильтрация
        #expect(errors.count == 2)
        #expect(infos.count == 2)
        #expect(errors[0].message == "Error 1")
        #expect(errors[1].message == "Error 2")
    }
}
