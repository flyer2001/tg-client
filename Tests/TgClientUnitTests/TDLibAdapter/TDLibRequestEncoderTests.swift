import Testing
import Foundation
@testable import TDLibAdapter

/// Unit-тесты для TDLibRequestEncoder.
///
/// Проверяют корректность сериализации запросов в JSON формат TDLib:
/// - Наличие поля `@type`
/// - Правильный snake_case маппинг (camelCase → snake_case)
/// - Корректные типы данных
@Suite("TDLibRequestEncoder")
struct TDLibRequestEncoderTests {

    let encoder = TDLibRequestEncoder()

    // MARK: - GetMeRequest (простой запрос без параметров)

    @Test("Encode GetMeRequest - простой запрос без параметров")
    func encodeGetMeRequest() throws {
        // Given
        let request = GetMeRequest()

        // When
        let data = try encoder.encode(request)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]

        // Then
        #expect(json != nil)
        #expect(json?["@type"] as? String == "getMe")
        #expect(json?.count == 1, "GetMeRequest должен содержать только поле @type")
    }

    // MARK: - SetTdlibParametersRequest (сложный запрос с snake_case маппингом)

    @Test("Encode SetTdlibParametersRequest - сложный запрос с snake_case маппингом")
    func encodeSetTdlibParametersRequest() throws {
        // Given
        let request = SetTdlibParametersRequest(
            useTestDc: false,
            databaseDirectory: "/tmp/tdlib",
            filesDirectory: "/tmp/tdlib/files",
            databaseEncryptionKey: "",
            useFileDatabase: true,
            useChatInfoDatabase: true,
            useMessageDatabase: true,
            useSecretChats: false,
            apiId: 12345,
            apiHash: "test_hash",
            systemLanguageCode: "ru",
            deviceModel: "MacBook",
            systemVersion: "macOS 14",
            applicationVersion: "1.0"
        )

        // When
        let data = try encoder.encode(request)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]

        // Then
        #expect(json != nil)

        // Проверка @type
        #expect(json?["@type"] as? String == "setTdlibParameters")

        // Проверка snake_case маппинга
        #expect(json?["use_test_dc"] as? Bool == false)
        #expect(json?["database_directory"] as? String == "/tmp/tdlib")
        #expect(json?["files_directory"] as? String == "/tmp/tdlib/files")
        #expect(json?["database_encryption_key"] as? String == "")
        #expect(json?["use_file_database"] as? Bool == true)
        #expect(json?["use_chat_info_database"] as? Bool == true)
        #expect(json?["use_message_database"] as? Bool == true)
        #expect(json?["use_secret_chats"] as? Bool == false)
        #expect(json?["api_id"] as? Int32 == 12345)
        #expect(json?["api_hash"] as? String == "test_hash")
        #expect(json?["system_language_code"] as? String == "ru")
        #expect(json?["device_model"] as? String == "MacBook")
        #expect(json?["system_version"] as? String == "macOS 14")
        #expect(json?["application_version"] as? String == "1.0")

        // Проверка отсутствия camelCase ключей
        #expect(json?["useTestDc"] == nil, "Не должно быть camelCase ключей")
        #expect(json?["databaseDirectory"] == nil, "Не должно быть camelCase ключей")
        #expect(json?["apiId"] == nil, "Не должно быть camelCase ключей")
    }

    // MARK: - SetAuthenticationPhoneNumberRequest

    @Test("Encode SetAuthenticationPhoneNumberRequest")
    func encodeSetAuthenticationPhoneNumberRequest() throws {
        // Given
        let request = SetAuthenticationPhoneNumberRequest(phoneNumber: "+79001234567")

        // When
        let data = try encoder.encode(request)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]

        // Then
        #expect(json != nil)
        #expect(json?["@type"] as? String == "setAuthenticationPhoneNumber")
        #expect(json?["phone_number"] as? String == "+79001234567")

        // Проверка отсутствия camelCase
        #expect(json?["phoneNumber"] == nil)
    }

    // MARK: - CheckAuthenticationCodeRequest

    @Test("Encode CheckAuthenticationCodeRequest")
    func encodeCheckAuthenticationCodeRequest() throws {
        // Given
        let request = CheckAuthenticationCodeRequest(code: "12345")

        // When
        let data = try encoder.encode(request)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]

        // Then
        #expect(json != nil)
        #expect(json?["@type"] as? String == "checkAuthenticationCode")
        #expect(json?["code"] as? String == "12345")
    }

    // MARK: - CheckAuthenticationPasswordRequest

    @Test("Encode CheckAuthenticationPasswordRequest")
    func encodeCheckAuthenticationPasswordRequest() throws {
        // Given
        let request = CheckAuthenticationPasswordRequest(password: "secret")

        // When
        let data = try encoder.encode(request)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]

        // Then
        #expect(json != nil)
        #expect(json?["@type"] as? String == "checkAuthenticationPassword")
        #expect(json?["password"] as? String == "secret")
    }

    // MARK: - JSON валидность

    @Test("Encoded JSON is valid format")
    func encodedJSONIsValidFormat() throws {
        // Given
        let request = GetMeRequest()

        // When
        let data = try encoder.encode(request)

        // Then - должно быть валидным JSON
        let json = try JSONSerialization.jsonObject(with: data)
        #expect(json is [String: Any])
    }

    @Test("Encoded data is not empty")
    func encodedDataIsNotEmpty() throws {
        // Given
        let request = GetMeRequest()

        // When
        let data = try encoder.encode(request)

        // Then
        #expect(!data.isEmpty, "Закодированные данные не должны быть пустыми")
    }
}
