import Foundation
@testable import TDLibAdapter

/// Ошибки создания TDConfig для тестов.
enum TDConfigError: Error, CustomStringConvertible {
    case missingEnvironmentVariable(String)

    var description: String {
        switch self {
        case .missingEnvironmentVariable(let name):
            return "Missing required environment variable: \(name)"
        }
    }
}

extension TDConfig {
    /// Создаёт TDConfig из переменных окружения для E2E тестов.
    ///
    /// **Автоматически загружает .env файл** (если существует в корне проекта).
    ///
    /// **Требуемые переменные окружения:**
    /// - `TELEGRAM_API_ID` - API ID приложения
    /// - `TELEGRAM_API_HASH` - API Hash приложения
    ///
    /// **Опциональные переменные:**
    /// - `TDLIB_STATE_DIR` - директория для БД (по умолчанию `~/.tdlib`)
    /// - `TDLIB_DATABASE_ENCRYPTION_KEY` - ключ шифрования БД (по умолчанию пустая строка)
    ///
    /// **Использование:**
    /// ```swift
    /// let config = try TDConfig.forTesting()
    /// let tdlib = TDLibClient(appLogger: logger)
    /// try await tdlib.start(config: config, promptFor: { _ in "" })
    /// ```
    ///
    /// - Throws: `TDConfigError.missingEnvironmentVariable` если не заданы обязательные переменные
    static func forTesting() throws -> TDConfig {
        // Пытаемся загрузить .env файл (если существует)
        try? EnvFileLoader.loadDotEnv(from: ".env")
        guard let apiIdString = ProcessInfo.processInfo.environment["TELEGRAM_API_ID"],
              let apiId = Int32(apiIdString) else {
            throw TDConfigError.missingEnvironmentVariable("TELEGRAM_API_ID")
        }

        guard let apiHash = ProcessInfo.processInfo.environment["TELEGRAM_API_HASH"] else {
            throw TDConfigError.missingEnvironmentVariable("TELEGRAM_API_HASH")
        }

        let homeDir = FileManager.default.homeDirectoryForCurrentUser.path
        let stateDir = ProcessInfo.processInfo.environment["TDLIB_STATE_DIR"] ?? "\(homeDir)/.tdlib"
        let logPath = "\(stateDir)/tdlib.log"
        let databaseEncryptionKey = ProcessInfo.processInfo.environment["TDLIB_DATABASE_ENCRYPTION_KEY"] ?? ""

        return TDConfig(
            apiId: apiId,
            apiHash: apiHash,
            stateDir: stateDir,
            logPath: logPath,
            logVerbosity: .fatal,
            databaseEncryptionKey: databaseEncryptionKey
        )
    }
}
