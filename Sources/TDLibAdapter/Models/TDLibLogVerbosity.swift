import Foundation

/// Уровень детализации логов TDLib.
///
/// Определяет количество информации, записываемой в лог-файл TDLib.
///
/// См. документацию: https://core.telegram.org/tdlib/.claude/classtd_1_1_log.html
public enum TDLibLogVerbosity: Int32, Sendable {
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
