import Foundation

/// Запрос для проверки ключа шифрования базы данных.
///
/// См. https://core.telegram.org/tdlib/.claude/classtd_1_1td__api_1_1check_database_encryption_key.html
public struct CheckDatabaseEncryptionKeyRequest: TDLibRequest {
    public let type = "checkDatabaseEncryptionKey"

    /// Ключ шифрования (передайте "" для отключения шифрования)
    public let encryptionKey: String

    enum CodingKeys: String, CodingKey {
        case type = "@type"
        case encryptionKey
    }

    public init(encryptionKey: String) {
        self.encryptionKey = encryptionKey
    }
}
