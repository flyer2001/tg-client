import TgClientModels
import TGClientInterfaces
import Testing
import Foundation
import TDLibAdapter

/// Unit-тесты для кодирования SetTdlibParametersRequest.
///
/// ## Описание модели
///
/// `SetTdlibParametersRequest` - запрос для установки параметров TDLib.
/// Первый запрос после создания TDLib клиента (состояние `authorizationStateWaitTdlibParameters`).
///
/// **Структура:**
/// - `type` - всегда "setTdlibParameters" (константа)
/// - Множество параметров для настройки TDLib (см. поля ниже)
///
/// **Маппинг полей (camelCase → snake_case):**
/// - `useTestDc` → `use_test_dc`
/// - `databaseDirectory` → `database_directory`
/// - `filesDirectory` → `files_directory`
/// - `databaseEncryptionKey` → `database_encryption_key`
/// - `useFileDatabase` → `use_file_database`
/// - `useChatInfoDatabase` → `use_chat_info_database`
/// - `useMessageDatabase` → `use_message_database`
/// - `useSecretChats` → `use_secret_chats`
/// - `apiId` → `api_id`
/// - `apiHash` → `api_hash`
/// - `systemLanguageCode` → `system_language_code`
/// - `deviceModel` → `device_model`
/// - `systemVersion` → `system_version`
/// - `applicationVersion` → `application_version`
///
/// ## Связь с TDLib API
///
/// После установки параметров TDLib переходит в состояние `authorizationStateWaitPhoneNumber`.
///
/// **Документация TDLib:**
/// - https://core.telegram.org/tdlib/docs/classtd_1_1td__api_1_1set_tdlib_parameters.html
///
/// ## Основные параметры
///
/// - `useTestDc` - использовать тестовые датацентры Telegram
/// - `databaseDirectory` - путь к директории для БД TDLib
/// - `apiId` / `apiHash` - credentials из https://my.telegram.org
/// - `systemLanguageCode` - язык системы (например, "ru" или "en")
@Suite("Кодирование SetTdlibParametersRequest")
struct SetTdlibParametersRequestTests {

    let encoder = TDLibRequestEncoder()

    /// Кодирование сложного запроса с множеством параметров.
    ///
    /// Проверяем корректное преобразование всех полей из camelCase в snake_case.
    @Test("Encode SetTdlibParametersRequest - сложный запрос с snake_case маппингом")
    func encodeSetTdlibParametersRequest() throws {
        // Given: создаем запрос со всеми параметрами TDLib
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

        // When: кодируем запрос в JSON
        let data = try encoder.encode(request)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]

        // Then: все поля должны быть в snake_case формате
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
}
