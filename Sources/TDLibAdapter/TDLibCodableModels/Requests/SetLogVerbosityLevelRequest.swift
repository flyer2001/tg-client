import Foundation

/// Запрос для установки уровня детализации логирования TDLib.
///
/// Устанавливает максимальный уровень логирования TDLib.
/// Сообщения с уровнем выше указанного будут игнорироваться.
///
/// См. https://core.telegram.org/tdlib/.claude/classtd_1_1td__api_1_1set_log_verbosity_level.html
public struct SetLogVerbosityLevelRequest: TDLibRequest {
    public let type = "setLogVerbosityLevel"

    /// Новый уровень детализации логов.
    public let newVerbosityLevel: Verbosity

    enum CodingKeys: String, CodingKey {
        case type = "@type"
        case newVerbosityLevel
    }

    /// Создаёт запрос для установки уровня логирования.
    ///
    /// - Parameter newVerbosityLevel: Уровень детализации логов
    public init(newVerbosityLevel: Verbosity) {
        self.newVerbosityLevel = newVerbosityLevel
    }

    /// Уровень детализации логов TDLib.
    ///
    /// Определяет количество информации, записываемой в лог-файл TDLib.
    ///
    /// См. документацию: https://core.telegram.org/tdlib/.claude/classtd_1_1_log.html
    public enum Verbosity: Int32, Codable, Sendable {
        /// Только критические ошибки (FATAL)
        case fatal = 0
        /// Ошибки (ERROR)
        case error = 1
        /// Предупреждения (WARNING)
        case warning = 2
        /// Информационные сообщения (INFO)
        case info = 3
        /// Отладочная информация (DEBUG)
        case debug = 4
        /// Максимальная детализация (VERBOSE)
        case verbose = 5
    }
}
