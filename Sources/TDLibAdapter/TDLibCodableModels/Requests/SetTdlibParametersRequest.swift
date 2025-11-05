import Foundation

/// Запрос для установки параметров TDLib.
///
/// Документация: https://core.telegram.org/tdlib/.claude/classtd_1_1td__api_1_1set_tdlib_parameters.html
///
/// Используемая версия TDLib HEAD-36b05e9:
/// https://github.com/tdlib/td/blob/36b05e9e0310c9a32ae6cb807fe22c96600f6061/td/generate/scheme/td_api.tl#L7958
public struct SetTdlibParametersRequest: TDLibRequest {
    public let type = "setTdlibParameters"

    public let useTestDc: Bool
    public let databaseDirectory: String
    public let filesDirectory: String
    public let databaseEncryptionKey: String
    public let useFileDatabase: Bool
    public let useChatInfoDatabase: Bool
    public let useMessageDatabase: Bool
    public let useSecretChats: Bool
    public let apiId: Int32
    public let apiHash: String
    public let systemLanguageCode: String
    public let deviceModel: String
    public let systemVersion: String
    public let applicationVersion: String

    enum CodingKeys: String, CodingKey {
        case type = "@type"
        case useTestDc = "use_test_dc"
        case databaseDirectory = "database_directory"
        case filesDirectory = "files_directory"
        case databaseEncryptionKey = "database_encryption_key"
        case useFileDatabase = "use_file_database"
        case useChatInfoDatabase = "use_chat_info_database"
        case useMessageDatabase = "use_message_database"
        case useSecretChats = "use_secret_chats"
        case apiId = "api_id"
        case apiHash = "api_hash"
        case systemLanguageCode = "system_language_code"
        case deviceModel = "device_model"
        case systemVersion = "system_version"
        case applicationVersion = "application_version"
    }

    public init(
        useTestDc: Bool,
        databaseDirectory: String,
        filesDirectory: String,
        databaseEncryptionKey: String,
        useFileDatabase: Bool,
        useChatInfoDatabase: Bool,
        useMessageDatabase: Bool,
        useSecretChats: Bool,
        apiId: Int32,
        apiHash: String,
        systemLanguageCode: String,
        deviceModel: String,
        systemVersion: String,
        applicationVersion: String
    ) {
        self.useTestDc = useTestDc
        self.databaseDirectory = databaseDirectory
        self.filesDirectory = filesDirectory
        self.databaseEncryptionKey = databaseEncryptionKey
        self.useFileDatabase = useFileDatabase
        self.useChatInfoDatabase = useChatInfoDatabase
        self.useMessageDatabase = useMessageDatabase
        self.useSecretChats = useSecretChats
        self.apiId = apiId
        self.apiHash = apiHash
        self.systemLanguageCode = systemLanguageCode
        self.deviceModel = deviceModel
        self.systemVersion = systemVersion
        self.applicationVersion = applicationVersion
    }
}
