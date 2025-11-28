import TGClientInterfaces
import Foundation

/// Настройки записи логов в файл.
///
/// См. https://core.telegram.org/tdlib/docs/classtd_1_1td__api_1_1log_stream_file.html
public struct LogStreamFile: Encodable, Sendable {
    public let type = "logStreamFile"

    /// Путь к файлу логов.
    public let path: String

    /// Максимальный размер файла в байтах (по умолчанию 10 МБ).
    ///
    /// Когда файл достигает этого размера, он переименовывается с добавлением `.old`
    /// и создаётся новый файл.
    public let maxFileSize: Int64

    /// Перенаправлять ли stderr в файл логов.
    ///
    /// По умолчанию `true` - весь stderr будет писаться в лог-файл.
    public let redirectStderr: Bool

    enum CodingKeys: String, CodingKey {
        case type = "@type"
        case path
        case maxFileSize
        case redirectStderr
    }

    /// Создаёт настройки записи логов в файл.
    ///
    /// - Parameters:
    ///   - path: Путь к файлу логов
    ///   - maxFileSize: Максимальный размер файла в байтах (по умолчанию 10 МБ)
    ///   - redirectStderr: Перенаправлять ли stderr в файл (по умолчанию `true`)
    public init(path: String, maxFileSize: Int64 = 10 * 1024 * 1024, redirectStderr: Bool = true) {
        self.path = path
        self.maxFileSize = maxFileSize
        self.redirectStderr = redirectStderr
    }
}

/// Поток вывода логов TDLib.
public enum LogStream: Encodable, Sendable {
    /// Запись логов в файл
    case file(LogStreamFile)
    /// Запись логов в консоль
    case console
    /// Отключить логирование
    case empty

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .file(let fileStream):
            try container.encode(fileStream)
        case .console:
            try container.encode(["@type": "logStreamConsole"])
        case .empty:
            try container.encode(["@type": "logStreamEmpty"])
        }
    }
}

/// Запрос для установки потока вывода логов TDLib.
///
/// Настраивает способ записи логов TDLib (файл, консоль, отключение).
///
/// См. https://core.telegram.org/tdlib/docs/classtd_1_1td__api_1_1set_log_stream.html
public struct SetLogStreamRequest: TDLibRequest {
    public let type = "setLogStream"

    /// Поток вывода логов.
    public let logStream: LogStream

    enum CodingKeys: String, CodingKey {
        case type = "@type"
        case logStream
    }

    /// Создаёт запрос для установки потока логов.
    ///
    /// - Parameter logStream: Поток вывода логов
    public init(logStream: LogStream) {
        self.logStream = logStream
    }
}
