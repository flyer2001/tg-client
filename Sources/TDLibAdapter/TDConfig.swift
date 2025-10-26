import Foundation

/// Конфигурация для подключения к Telegram API через TDLib.
///
/// Содержит все необходимые параметры для инициализации TDLib клиента.
///
/// ## Использование
///
/// ```swift
/// let config = TDConfig(
///     apiId: 12345,
///     apiHash: "your_api_hash",
///     stateDir: "\(FileManager.default.homeDirectoryForCurrentUser.path)/.tdlib",
///     logPath: "\(FileManager.default.homeDirectoryForCurrentUser.path)/.tdlib/tdlib.log"
/// )
/// ```
///
/// ## Получение API Credentials
///
/// См. `Sources/TDLibAdapter/README.md` для инструкций по получению `apiId` и `apiHash`.
public struct TDConfig: Sendable {
    /// API ID приложения от Telegram.
    ///
    /// Получить можно на https://my.telegram.org/apps
    public let apiId: Int32

    /// API Hash приложения от Telegram.
    ///
    /// Получить можно на https://my.telegram.org/apps
    public let apiHash: String

    /// Директория для хранения состояния TDLib (база данных, файлы).
    ///
    /// TDLib создаст внутри две поддиректории:
    /// - `db/` - база данных с чатами, сообщениями, пользователями
    /// - `files/` - кэш медиа-файлов
    ///
    /// **Важно:** НЕ коммитьте эту директорию в git! Там хранится ваша сессия.
    ///
    /// **Рекомендуемое значение:** `~/.tdlib`
    public let stateDir: String

    /// Путь к файлу логов TDLib.
    ///
    /// TDLib будет записывать свои внутренние логи в этот файл.
    ///
    /// **Рекомендуемое значение:** `~/.tdlib/tdlib.log`
    public let logPath: String

    /// Уровень детализации логов TDLib.
    ///
    /// Определяет количество информации, которую TDLib будет записывать в лог-файл.
    ///
    /// **Рекомендуется:**
    /// - `.fatal` для продакшена (минимальные логи)
    /// - `.warning` или `.info` для отладки
    ///
    /// **По умолчанию:** `.fatal`
    public let logVerbosity: TDLibLogVerbosity

    /// Создаёт новую конфигурацию TDLib.
    ///
    /// - Parameters:
    ///   - apiId: API ID от https://my.telegram.org/apps
    ///   - apiHash: API Hash от https://my.telegram.org/apps
    ///   - stateDir: Директория для базы данных и файлов (рекомендуется `~/.tdlib`)
    ///   - logPath: Путь к файлу логов (рекомендуется `~/.tdlib/tdlib.log`)
    ///   - logVerbosity: Уровень детализации логов TDLib (по умолчанию `.fatal`)
    public init(apiId: Int32, apiHash: String, stateDir: String, logPath: String, logVerbosity: TDLibLogVerbosity = .fatal) {
        self.apiId = apiId
        self.apiHash = apiHash
        self.stateDir = stateDir
        self.logPath = logPath
        self.logVerbosity = logVerbosity
    }
}
