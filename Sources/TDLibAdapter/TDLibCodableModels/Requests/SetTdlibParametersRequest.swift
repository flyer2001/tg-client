import Foundation

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
        case useTestDc
        case databaseDirectory
        case filesDirectory
        case databaseEncryptionKey
        case useFileDatabase
        case useChatInfoDatabase
        case useMessageDatabase
        case useSecretChats
        case apiId
        case apiHash
        case systemLanguageCode
        case deviceModel
        case systemVersion
        case applicationVersion
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
