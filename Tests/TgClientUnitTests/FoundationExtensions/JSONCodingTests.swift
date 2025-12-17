import TgClientModels
import TGClientInterfaces
import Foundation
import Testing
import FoundationExtensions

/// Unit-тесты для централизованных encoder/decoder (JSONCoding.swift).
///
/// **Цель:** Убедиться что `.tdlib()` factory методы используют правильные стратегии кодирования.
///
/// **Что тестируем:**
/// - `JSONEncoder.tdlib()` использует `.convertToSnakeCase`
/// - `JSONDecoder.tdlib()` использует `.convertFromSnakeCase`
/// - Краевые случаи: вложенные объекты, массивы, опциональные поля
/// - Явные CodingKeys имеют приоритет над автоматической конвертацией
@Suite("JSONEncoder.tdlib() и JSONDecoder.tdlib()")
struct JSONCodingTests {

    // MARK: - Test Models

    /// Модель для тестирования базовой конвертации snake_case.
    struct SimpleModel: Codable, Equatable {
        let chatId: Int64
        let firstName: String
        let isActive: Bool
    }

    /// Модель с вложенным объектом.
    struct NestedModel: Codable, Equatable {
        let userId: Int64
        let userInfo: UserInfo

        struct UserInfo: Codable, Equatable {
            let firstName: String
            let lastName: String
        }
    }

    /// Модель с массивом.
    struct ArrayModel: Codable, Equatable {
        let chatIds: [Int64]
        let userNames: [String]
    }

    /// Модель с опциональными полями.
    struct OptionalModel: Codable, Equatable {
        let userId: Int64
        let userName: String?
        let phoneNumber: String?
    }

    /// Модель с явными CodingKeys (приоритет над автоконвертацией).
    struct ExplicitKeysModel: Codable, Equatable {
        let type: String
        let chatId: Int64

        enum CodingKeys: String, CodingKey {
            case type = "@type"  // явный маппинг (@ не конвертируется)
            case chatId          // автоматическая конвертация (chat_id)
        }
    }

    /// Модель с аббревиатурами и числами.
    struct AbbreviationModel: Codable, Equatable {
        let apiId: Int32
        let apiHash: String
        let userId2: Int64
    }

    // MARK: - Encoding Tests

    @Test("Базовая конвертация camelCase → snake_case")
    func encodeBasicSnakeCase() throws {
        let model = SimpleModel(chatId: 123, firstName: "John", isActive: true)
        let encoder = JSONEncoder.tdlib()
        let data = try encoder.encode(model)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        let result = try #require(json, "JSON должен быть словарём")

        // Проверяем конвертацию camelCase → snake_case
        #expect(result["chat_id"] as? Int64 == 123, "chatId → chat_id")
        #expect(result["first_name"] as? String == "John", "firstName → first_name")
        #expect(result["is_active"] as? Bool == true, "isActive → is_active")

        // Убеждаемся что camelCase ключей НЕТ
        #expect(result["chatId"] == nil, "Не должно быть camelCase ключа")
        #expect(result["firstName"] == nil, "Не должно быть camelCase ключа")
    }

    @Test("Конвертация вложенных объектов")
    func encodeNestedObjects() throws {
        let model = NestedModel(
            userId: 456,
            userInfo: NestedModel.UserInfo(firstName: "Jane", lastName: "Doe")
        )
        let encoder = JSONEncoder.tdlib()
        let data = try encoder.encode(model)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        let result = try #require(json, "JSON должен быть словарём")

        #expect(result["user_id"] as? Int64 == 456, "userId → user_id")

        let userInfo = try #require(result["user_info"] as? [String: Any], "user_info должен быть словарём")
        #expect(userInfo["first_name"] as? String == "Jane", "Вложенный firstName → first_name")
        #expect(userInfo["last_name"] as? String == "Doe", "Вложенный lastName → last_name")
    }

    @Test("Конвертация массивов")
    func encodeArrays() throws {
        let model = ArrayModel(chatIds: [1, 2, 3], userNames: ["alice", "bob"])
        let encoder = JSONEncoder.tdlib()
        let data = try encoder.encode(model)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        let result = try #require(json, "JSON должен быть словарём")

        #expect(result["chat_ids"] as? [Int64] == [1, 2, 3], "chatIds → chat_ids")
        #expect(result["user_names"] as? [String] == ["alice", "bob"], "userNames → user_names")
    }

    @Test("Кодирование опциональных полей (nil пропускается)")
    func encodeOptionalFields() throws {
        let model = OptionalModel(userId: 789, userName: "test", phoneNumber: nil)
        let encoder = JSONEncoder.tdlib()
        let data = try encoder.encode(model)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        let result = try #require(json, "JSON должен быть словарём")

        #expect(result["user_id"] as? Int64 == 789)
        #expect(result["user_name"] as? String == "test", "userName присутствует")
        #expect(result["phone_number"] == nil, "phoneNumber=nil пропущен")
    }

    @Test("Явные CodingKeys имеют приоритет")
    func encodeExplicitCodingKeys() throws {
        let model = ExplicitKeysModel(type: "testType", chatId: 999)
        let encoder = JSONEncoder.tdlib()
        let data = try encoder.encode(model)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        let result = try #require(json, "JSON должен быть словарём")

        // Явный маппинг: type → "@type"
        #expect(result["@type"] as? String == "testType", "Явный CodingKey работает")
        #expect(result["type"] == nil, "Не должно быть 'type' ключа")

        // Автоматическая конвертация: chatId → "chat_id"
        #expect(result["chat_id"] as? Int64 == 999, "Автоконвертация работает параллельно")
    }

    @Test("Конвертация аббревиатур и чисел")
    func encodeAbbreviations() throws {
        let model = AbbreviationModel(apiId: 123, apiHash: "abc", userId2: 456)
        let encoder = JSONEncoder.tdlib()
        let data = try encoder.encode(model)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        let result = try #require(json, "JSON должен быть словарём")

        // Swift convertToSnakeCase: apiId → api_id, userId2 → user_id2
        #expect(result["api_id"] as? Int32 == 123, "apiId → api_id")
        #expect(result["api_hash"] as? String == "abc", "apiHash → api_hash")
        #expect(result["user_id2"] as? Int64 == 456, "userId2 → user_id2")
    }

    // MARK: - Decoding Tests

    @Test("Базовая конвертация snake_case → camelCase")
    func decodeBasicSnakeCase() throws {
        let json = """
        {
            "chat_id": 123,
            "first_name": "John",
            "is_active": true
        }
        """
        let data = Data(json.utf8)
        let decoder = JSONDecoder.tdlib()
        let result = try decoder.decode(SimpleModel.self, from: data)

        #expect(result.chatId == 123, "chat_id → chatId")
        #expect(result.firstName == "John", "first_name → firstName")
        #expect(result.isActive == true, "is_active → isActive")
    }

    @Test("Декодирование вложенных объектов")
    func decodeNestedObjects() throws {
        let json = """
        {
            "user_id": 456,
            "user_info": {
                "first_name": "Jane",
                "last_name": "Doe"
            }
        }
        """
        let data = Data(json.utf8)
        let decoder = JSONDecoder.tdlib()
        let result = try decoder.decode(NestedModel.self, from: data)

        #expect(result.userId == 456)
        #expect(result.userInfo.firstName == "Jane")
        #expect(result.userInfo.lastName == "Doe")
    }

    @Test("Декодирование массивов")
    func decodeArrays() throws {
        let json = """
        {
            "chat_ids": [1, 2, 3],
            "user_names": ["alice", "bob"]
        }
        """
        let data = Data(json.utf8)
        let decoder = JSONDecoder.tdlib()
        let result = try decoder.decode(ArrayModel.self, from: data)

        #expect(result.chatIds == [1, 2, 3])
        #expect(result.userNames == ["alice", "bob"])
    }

    @Test("Декодирование опциональных полей (отсутствующие = nil)")
    func decodeOptionalFields() throws {
        let json = """
        {
            "user_id": 789,
            "user_name": "test"
        }
        """
        let data = Data(json.utf8)
        let decoder = JSONDecoder.tdlib()
        let result = try decoder.decode(OptionalModel.self, from: data)

        #expect(result.userId == 789)
        #expect(result.userName == "test")
        #expect(result.phoneNumber == nil, "Отсутствующее поле → nil")
    }

    @Test("Явные CodingKeys имеют приоритет при декодировании")
    func decodeExplicitCodingKeys() throws {
        let json = """
        {
            "@type": "testType",
            "chat_id": 999
        }
        """
        let data = Data(json.utf8)
        let decoder = JSONDecoder.tdlib()
        let result = try decoder.decode(ExplicitKeysModel.self, from: data)

        #expect(result.type == "testType", "Явный маппинг @type → type")
        #expect(result.chatId == 999, "Автоконвертация chat_id → chatId")
    }

    @Test("Декодирование аббревиатур и чисел")
    func decodeAbbreviations() throws {
        let json = """
        {
            "api_id": 123,
            "api_hash": "abc",
            "user_id2": 456
        }
        """
        let data = Data(json.utf8)
        let decoder = JSONDecoder.tdlib()
        let result = try decoder.decode(AbbreviationModel.self, from: data)

        #expect(result.apiId == 123, "api_id → apiId")
        #expect(result.apiHash == "abc", "api_hash → apiHash")
        #expect(result.userId2 == 456, "user_id2 → userId2")
    }

    // MARK: - Round-trip Tests

    @Test("Round-trip: encode → decode должен вернуть исходные данные")
    func roundTripSimpleModel() throws {
        let original = SimpleModel(chatId: 123, firstName: "John", isActive: true)
        let encoder = JSONEncoder.tdlib()
        let decoder = JSONDecoder.tdlib()

        let data = try encoder.encode(original)
        let decoded = try decoder.decode(SimpleModel.self, from: data)

        #expect(decoded == original, "Round-trip должен вернуть исходные данные")
    }

    @Test("Round-trip: вложенные объекты")
    func roundTripNestedModel() throws {
        let original = NestedModel(
            userId: 456,
            userInfo: NestedModel.UserInfo(firstName: "Jane", lastName: "Doe")
        )
        let encoder = JSONEncoder.tdlib()
        let decoder = JSONDecoder.tdlib()

        let data = try encoder.encode(original)
        let decoded = try decoder.decode(NestedModel.self, from: data)

        #expect(decoded == original)
    }

    @Test("Round-trip: массивы")
    func roundTripArrayModel() throws {
        let original = ArrayModel(chatIds: [1, 2, 3], userNames: ["alice", "bob"])
        let encoder = JSONEncoder.tdlib()
        let decoder = JSONDecoder.tdlib()

        let data = try encoder.encode(original)
        let decoded = try decoder.decode(ArrayModel.self, from: data)

        #expect(decoded == original)
    }

    @Test("Round-trip: опциональные поля")
    func roundTripOptionalModel() throws {
        let original = OptionalModel(userId: 789, userName: "test", phoneNumber: nil)
        let encoder = JSONEncoder.tdlib()
        let decoder = JSONDecoder.tdlib()

        let data = try encoder.encode(original)
        let decoded = try decoder.decode(OptionalModel.self, from: data)

        #expect(decoded == original)
    }
}

// MARK: - OpenAI API Tests

/// Unit-тесты для OpenAI encoder/decoder (JSONCoding.swift).
///
/// **Цель:** Убедиться что `.openAI()` factory методы используют правильные стратегии кодирования.
///
/// **Что тестируем:**
/// - `JSONEncoder.openAI()` использует `.convertToSnakeCase`
/// - `JSONDecoder.openAI()` использует `.convertFromSnakeCase`
/// - Round-trip тесты для гарантии совместимости
@Suite("JSONEncoder.openAI() и JSONDecoder.openAI()")
struct OpenAIJSONCodingTests {

    // MARK: - Test Models

    /// Простая модель для тестирования snake_case конвертации.
    struct SimpleOpenAIModel: Codable, Equatable {
        let maxTokens: Int
        let modelName: String
    }

    // MARK: - Encoding Tests

    @Test("Базовая конвертация camelCase → snake_case")
    func encodeBasicSnakeCase() throws {
        let model = SimpleOpenAIModel(maxTokens: 100, modelName: "gpt-3.5-turbo")
        let encoder = JSONEncoder.openAI()
        let data = try encoder.encode(model)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        let result = try #require(json, "JSON должен быть словарём")

        // Проверяем конвертацию camelCase → snake_case
        #expect(result["max_tokens"] as? Int == 100, "maxTokens → max_tokens")
        #expect(result["model_name"] as? String == "gpt-3.5-turbo", "modelName → model_name")

        // Убеждаемся что camelCase ключей НЕТ
        #expect(result["maxTokens"] == nil, "Не должно быть camelCase ключа")
        #expect(result["modelName"] == nil, "Не должно быть camelCase ключа")
    }

    // MARK: - Decoding Tests

    @Test("Базовая конвертация snake_case → camelCase")
    func decodeBasicSnakeCase() throws {
        let json = """
        {
            "max_tokens": 100,
            "model_name": "gpt-3.5-turbo"
        }
        """
        let data = Data(json.utf8)
        let decoder = JSONDecoder.openAI()
        let result = try decoder.decode(SimpleOpenAIModel.self, from: data)

        #expect(result.maxTokens == 100, "max_tokens → maxTokens")
        #expect(result.modelName == "gpt-3.5-turbo", "model_name → modelName")
    }

    // MARK: - Round-trip Tests

    @Test("Round-trip: encode → decode должен вернуть исходные данные")
    func roundTripSimpleModel() throws {
        let original = SimpleOpenAIModel(maxTokens: 100, modelName: "gpt-3.5-turbo")
        let encoder = JSONEncoder.openAI()
        let decoder = JSONDecoder.openAI()

        let data = try encoder.encode(original)
        let decoded = try decoder.decode(SimpleOpenAIModel.self, from: data)

        #expect(decoded == original, "Round-trip должен вернуть исходные данные")
    }
}

// MARK: - Telegram Bot API Tests

/// Unit-тесты для Telegram Bot API encoder/decoder (JSONCoding.swift).
///
/// **Цель:** Убедиться что `.telegramBot()` factory методы используют правильные стратегии кодирования.
///
/// **Что тестируем:**
/// - `JSONEncoder.telegramBot()` использует `.convertToSnakeCase`
/// - `JSONDecoder.telegramBot()` использует `.convertFromSnakeCase`
/// - Telegram Bot API specific поля: `chat_id`, `error_code`, `message_id`, `parse_mode`
@Suite("JSONEncoder.telegramBot() и JSONDecoder.telegramBot()")
struct TelegramBotJSONCodingTests {

    // MARK: - Test Models

    /// Простая модель для тестирования snake_case конвертации (Telegram Bot API).
    struct SimpleBotModel: Codable, Equatable {
        let chatId: Int64
        let errorCode: Int?
        let messageId: Int?
    }

    /// Модель с полем parseMode (специфично для Telegram Bot API).
    struct BotMessageModel: Codable, Equatable {
        let chatId: Int64
        let text: String
        let parseMode: String?
    }

    // MARK: - Encoding Tests

    @Test("Базовая конвертация camelCase → snake_case")
    func encodeBasicSnakeCase() throws {
        let model = SimpleBotModel(chatId: 566335622, errorCode: 400, messageId: 123)
        let encoder = JSONEncoder.telegramBot()
        let data = try encoder.encode(model)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        let result = try #require(json, "JSON должен быть словарём")

        // Проверяем конвертацию camelCase → snake_case (специфичные поля Bot API)
        #expect(result["chat_id"] as? Int64 == 566335622, "chatId → chat_id")
        #expect(result["error_code"] as? Int == 400, "errorCode → error_code")
        #expect(result["message_id"] as? Int == 123, "messageId → message_id")

        // Убеждаемся что camelCase ключей НЕТ
        #expect(result["chatId"] == nil, "Не должно быть camelCase ключа")
        #expect(result["errorCode"] == nil, "Не должно быть camelCase ключа")
    }

    @Test("Конвертация parseMode поля")
    func encodeParseModeField() throws {
        let model = BotMessageModel(chatId: 123, text: "Hello", parseMode: "MarkdownV2")
        let encoder = JSONEncoder.telegramBot()
        let data = try encoder.encode(model)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        let result = try #require(json, "JSON должен быть словарём")

        // parseMode → parse_mode (Telegram Bot API specific)
        #expect(result["parse_mode"] as? String == "MarkdownV2", "parseMode → parse_mode")
        #expect(result["parseMode"] == nil, "Не должно быть camelCase ключа")
    }

    @Test("Опциональные поля (nil пропускается)")
    func encodeOptionalFields() throws {
        let model = SimpleBotModel(chatId: 123, errorCode: nil, messageId: nil)
        let encoder = JSONEncoder.telegramBot()
        let data = try encoder.encode(model)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        let result = try #require(json, "JSON должен быть словарём")

        #expect(result["chat_id"] as? Int64 == 123)
        #expect(result["error_code"] == nil, "errorCode=nil пропущен")
        #expect(result["message_id"] == nil, "messageId=nil пропущен")
    }

    // MARK: - Decoding Tests

    @Test("Базовая конвертация snake_case → camelCase")
    func decodeBasicSnakeCase() throws {
        let json = """
        {
            "chat_id": 566335622,
            "error_code": 400,
            "message_id": 123
        }
        """
        let data = Data(json.utf8)
        let decoder = JSONDecoder.telegramBot()
        let result = try decoder.decode(SimpleBotModel.self, from: data)

        #expect(result.chatId == 566335622, "chat_id → chatId")
        #expect(result.errorCode == 400, "error_code → errorCode")
        #expect(result.messageId == 123, "message_id → messageId")
    }

    @Test("Декодирование parseMode поля")
    func decodeParseModeField() throws {
        let json = """
        {
            "chat_id": 123,
            "text": "Hello",
            "parse_mode": "MarkdownV2"
        }
        """
        let data = Data(json.utf8)
        let decoder = JSONDecoder.telegramBot()
        let result = try decoder.decode(BotMessageModel.self, from: data)

        #expect(result.parseMode == "MarkdownV2", "parse_mode → parseMode")
    }

    @Test("Декодирование опциональных полей (отсутствующие = nil)")
    func decodeOptionalFields() throws {
        let json = """
        {
            "chat_id": 123
        }
        """
        let data = Data(json.utf8)
        let decoder = JSONDecoder.telegramBot()
        let result = try decoder.decode(SimpleBotModel.self, from: data)

        #expect(result.chatId == 123)
        #expect(result.errorCode == nil, "Отсутствующее поле → nil")
        #expect(result.messageId == nil, "Отсутствующее поле → nil")
    }

    // MARK: - Round-trip Tests

    @Test("Round-trip: encode → decode должен вернуть исходные данные")
    func roundTripSimpleModel() throws {
        let original = SimpleBotModel(chatId: 566335622, errorCode: 400, messageId: 123)
        let encoder = JSONEncoder.telegramBot()
        let decoder = JSONDecoder.telegramBot()

        let data = try encoder.encode(original)
        let decoded = try decoder.decode(SimpleBotModel.self, from: data)

        #expect(decoded == original, "Round-trip должен вернуть исходные данные")
    }

    @Test("Round-trip: модель с parseMode")
    func roundTripBotMessageModel() throws {
        let original = BotMessageModel(chatId: 123, text: "Hello", parseMode: "MarkdownV2")
        let encoder = JSONEncoder.telegramBot()
        let decoder = JSONDecoder.telegramBot()

        let data = try encoder.encode(original)
        let decoded = try decoder.decode(BotMessageModel.self, from: data)

        #expect(decoded == original)
    }
}
