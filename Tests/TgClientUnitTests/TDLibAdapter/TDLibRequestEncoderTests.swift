import TgClientModels
import TGClientInterfaces
import Foundation
import Testing
import FoundationExtensions
@testable import TDLibAdapter

/// Unit-тесты для TDLibRequestEncoder.
///
/// Проверяем что encoder:
/// - Использует централизованный `.tdlib()` encoder с правильными стратегиями
/// - Корректно кодирует Request модели с snake_case маппингом
/// - Сохраняет явные CodingKeys (например, `@type`)
///
/// **TDLib JSON API:**
/// - Использует snake_case для всех полей
/// - Специальный ключ `@type` для типа запроса
/// - Документация: https://core.telegram.org/tdlib/docs/td__json__client_8h.html
@Suite("TDLibRequestEncoder Unit Tests")
struct TDLibRequestEncoderTests {

    let encoder = TDLibRequestEncoder()

    /// Проверяем что TDLibRequestEncoder корректно кодирует простой запрос.
    ///
    /// LoadChatsRequest имеет поле chatList (camelCase) которое должно стать chat_list (snake_case).
    @Test("Encode LoadChatsRequest - проверка snake_case конвертации")
    func encodeLoadChatsRequest() throws {
        // Given
        let request = LoadChatsRequest(chatList: .main, limit: 100)

        // When
        let data = try encoder.encode(request)
        let jsonObject = try JSONSerialization.jsonObject(with: data)
        let json = try #require(jsonObject as? [String: Any], "JSON должен быть словарём")

        // Then: проверяем структуру JSON
        #expect(json["@type"] as? String == "loadChats")
        #expect(json["limit"] as? Int == 100)

        // Проверяем snake_case маппинг
        #expect(json["chat_list"] != nil, "chatList должен конвертироваться в chat_list")
        #expect(json["chatList"] == nil, "Не должно быть camelCase ключа")

        let chatListObject = json["chat_list"]
        let chatList = try #require(chatListObject as? [String: Any], "chat_list должен быть словарём")
        #expect(chatList["@type"] as? String == "chatListMain")
    }

    /// Проверяем что TDLibRequestEncoder корректно кодирует сложный запрос с множеством полей.
    ///
    /// SetTdlibParametersRequest содержит ~14 полей в camelCase которые должны конвертироваться в snake_case.
    @Test("Encode SetTdlibParametersRequest - проверка множественных полей")
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
        let jsonObject = try JSONSerialization.jsonObject(with: data)
        let json = try #require(jsonObject as? [String: Any], "JSON должен быть словарём")

        // Then: проверяем @type
        #expect(json["@type"] as? String == "setTdlibParameters")

        // Проверяем snake_case маппинг для всех полей
        #expect(json["use_test_dc"] as? Bool == false)
        #expect(json["database_directory"] as? String == "/tmp/tdlib")
        #expect(json["files_directory"] as? String == "/tmp/tdlib/files")
        #expect(json["api_id"] as? Int32 == 12345)
        #expect(json["api_hash"] as? String == "test_hash")
        #expect(json["system_language_code"] as? String == "ru")
        #expect(json["device_model"] as? String == "MacBook")
        #expect(json["system_version"] as? String == "macOS 14")
        #expect(json["application_version"] as? String == "1.0")

        // Проверяем отсутствие camelCase ключей
        #expect(json["useTestDc"] == nil, "Не должно быть camelCase ключа")
        #expect(json["databaseDirectory"] == nil, "Не должно быть camelCase ключа")
        #expect(json["apiId"] == nil, "Не должно быть camelCase ключа")
        #expect(json["systemLanguageCode"] == nil, "Не должно быть camelCase ключа")
    }

    /// Проверяем что @type всегда присутствует в закодированном JSON.
    ///
    /// TDLib требует наличие поля @type во всех запросах.
    @Test("Проверка наличия @type поля")
    func typeFieldAlwaysPresent() throws {
        // Given: несколько разных типов запросов
        let requests: [any TDLibRequest] = [
            LoadChatsRequest(chatList: .main, limit: 100),
            SetTdlibParametersRequest(
                useTestDc: true,
                databaseDirectory: "/tmp",
                filesDirectory: "/tmp",
                databaseEncryptionKey: "",
                useFileDatabase: false,
                useChatInfoDatabase: false,
                useMessageDatabase: false,
                useSecretChats: false,
                apiId: 1,
                apiHash: "test",
                systemLanguageCode: "en",
                deviceModel: "test",
                systemVersion: "test",
                applicationVersion: "1.0"
            )
        ]

        // When & Then: проверяем каждый запрос
        for request in requests {
            let data = try encoder.encode(request)
            let jsonObject = try JSONSerialization.jsonObject(with: data)
            let json = try #require(jsonObject as? [String: Any], "JSON должен быть словарём")

            #expect(json["@type"] != nil, "Поле @type должно присутствовать")
            #expect(json["@type"] is String, "Поле @type должно быть строкой")
        }
    }

    /// Проверяем round-trip кодирование: encode → parse → check keys.
    ///
    /// Убеждаемся что после кодирования все ключи в snake_case формате.
    @Test("Round-trip: кодирование и парсинг JSON ключей")
    func roundTripEncoding() throws {
        // Given
        let request = LoadChatsRequest(chatList: .archive, limit: 50)

        // When: кодируем
        let data = try encoder.encode(request)

        // Then: парсим JSON и проверяем ключи
        let jsonObject = try JSONSerialization.jsonObject(with: data)
        let json = try #require(jsonObject as? [String: Any], "JSON должен быть словарём")

        // Все ключи должны быть в snake_case или @type
        let keys = Set(json.keys)
        #expect(keys.contains("@type"), "Должен быть ключ @type")
        #expect(keys.contains("chat_list"), "Должен быть ключ chat_list")
        #expect(keys.contains("limit"), "Должен быть ключ limit")

        // Не должно быть camelCase ключей
        #expect(!keys.contains("chatList"), "Не должно быть ключа chatList")
    }

    /// Проверяем что метод encode(withExtra:) добавляет @extra поле в JSON.
    ///
    /// **TDLib протокол:** @extra используется для Request-Response matching.
    /// Клиент генерирует уникальный @extra, TDLib возвращает response с тем же @extra.
    @Test("Encode с @extra полем")
    func encodeWithExtra() throws {
        // Given
        let request = LoadChatsRequest(chatList: .main, limit: 100)
        let extra = "test_extra_123"

        // When
        let data = try encoder.encode(request, withExtra: extra)
        let jsonObject = try JSONSerialization.jsonObject(with: data)
        let json = try #require(jsonObject as? [String: Any], "JSON должен быть словарём")

        // Then: проверяем что @extra добавлен
        #expect(json["@extra"] as? String == extra, "@extra должен быть добавлен")

        // Then: проверяем что остальные поля сохранились
        #expect(json["@type"] as? String == "loadChats", "@type должен сохраниться")
        #expect(json["limit"] as? Int == 100, "limit должен сохраниться")
        #expect(json["chat_list"] != nil, "chat_list должен сохраниться")

        // Then: проверяем что snake_case маппинг работает
        let chatListObject = json["chat_list"]
        let chatList = try #require(chatListObject as? [String: Any], "chat_list должен быть словарём")
        #expect(chatList["@type"] as? String == "chatListMain")
    }
}
