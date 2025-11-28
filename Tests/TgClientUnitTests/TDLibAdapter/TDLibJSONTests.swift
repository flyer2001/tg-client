import TgClientModels
import TGClientInterfaces
import Foundation
import Testing
@testable import TDLibAdapter

/// Unit-тесты для TDLibJSON - Sendable-safe обёртки над [String: Any]
@Suite("TDLibJSON - Sendable-safe wrapper")
struct TDLibJSONTests {

    // MARK: - 1. Simple Types

    @Test("Простые типы: String, Int, Bool, Double")
    func testSimpleTypes() throws {
        let input: [String: Any] = [
            "string": "hello",
            "int": 42,
            "bool": true,
            "double": 3.14
        ]

        let json = try TDLibJSON(parsing: input)

        #expect(json["string"] as? String == "hello")
        #expect(json["int"] as? Int == 42)
        #expect(json["bool"] as? Bool == true)
        #expect(json["double"] as? Double == 3.14)
    }

    // MARK: - 2. Int Variants

    @Test("Поддержка Int32, Int64")
    func testIntVariants() throws {
        let input: [String: Any] = [
            "int32": Int32(100),
            "int64": Int64.max,
            "regularInt": 42
        ]

        let json = try TDLibJSON(parsing: input)

        #expect(json["int32"] as? Int32 == 100)
        #expect(json["int64"] as? Int64 == Int64.max)
        #expect(json["regularInt"] as? Int == 42)
    }

    // MARK: - 3. Nested Dictionaries

    @Test("Вложенные словари (рекурсивная валидация)")
    func testNestedDictionaries() throws {
        let input: [String: Any] = [
            "outer": [
                "inner": [
                    "deep": "value",
                    "count": 123
                ] as [String: Any]
            ] as [String: Any]
        ]

        let json = try TDLibJSON(parsing: input)

        // Доступ через nested subscripts
        let outer = json["outer"] as? [String: Any]
        #expect(outer != nil)

        let inner = outer?["inner"] as? [String: Any]
        #expect(inner != nil)
        #expect(inner?["deep"] as? String == "value")
        #expect(inner?["count"] as? Int == 123)
    }

    // MARK: - 4. Arrays

    @Test("Однородные массивы примитивов")
    func testArrays() throws {
        let input: [String: Any] = [
            "strings": ["a", "b", "c"],
            "ints": [1, 2, 3],
            "mixed": [1, "text", true]  // JSON поддерживает mixed arrays
        ]

        let json = try TDLibJSON(parsing: input)

        let strings = json["strings"] as? [String]
        #expect(strings == ["a", "b", "c"])

        let ints = json["ints"] as? [Int]
        #expect(ints == [1, 2, 3])

        // Mixed array требует Any cast
        let mixed = json["mixed"] as? [Any]
        #expect(mixed != nil)
        #expect(mixed?.count == 3)
    }

    // MARK: - 5. Array of Dictionaries

    @Test("Массив объектов - как TDLib messages response")
    func testArrayOfDictionaries() throws {
        let input: [String: Any] = [
            "messages": [
                ["id": 1, "text": "foo"] as [String: Any],
                ["id": 2, "text": "bar"] as [String: Any]
            ]
        ]

        let json = try TDLibJSON(parsing: input)

        let messages = json["messages"] as? [[String: Any]]
        #expect(messages != nil)
        #expect(messages?.count == 2)
        #expect(messages?[0]["id"] as? Int == 1)
        #expect(messages?[1]["text"] as? String == "bar")
    }

    // MARK: - 6. NSNull Handling

    @Test("NSNull для JSON null значений")
    func testNSNull() throws {
        let input: [String: Any] = [
            "nullable": NSNull(),
            "present": "value"
        ]

        let json = try TDLibJSON(parsing: input)

        #expect(json["nullable"] is NSNull)
        #expect(json["present"] as? String == "value")
    }

    // MARK: - 7. ⚠️ КРИТИЧНО: Rejection Non-Sendable

    @Test("Отклоняет non-Sendable типы (КРИТИЧНАЯ проверка безопасности)")
    func testRejectsNonSendable() {
        // Custom class НЕ Sendable
        class NonSendable {}

        let input: [String: Any] = [
            "bad": NonSendable()
        ]

        #expect(throws: TDLibClientError.self) {
            try TDLibJSON(parsing: input)
        }
    }

    @Test("Отклоняет closures (non-Sendable)")
    func testRejectsClosure() {
        let input: [String: Any] = [
            "closure": { print("hello") }
        ]

        #expect(throws: TDLibClientError.self) {
            try TDLibJSON(parsing: input)
        }
    }

    // MARK: - 8. Real TDLib Responses

    @Test("Реальный OkResponse - простейший TDLib ответ")
    func testRealOkResponse() throws {
        let ok = OkResponse()

        // Round-trip: Model → Data → [String: Any] → TDLibJSON
        let data = try JSONEncoder.tdlib().encode(ok)

        guard let dict = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            Issue.record("Failed to parse OkResponse as [String: Any]")
            return
        }

        let json = try TDLibJSON(parsing: dict)

        // OkResponse содержит только @type = "ok"
        #expect(json["@type"] as? String == "ok")

        // Проверяем что можем декодировать обратно
        let roundTripData = try JSONSerialization.data(withJSONObject: json.data)
        _ = try JSONDecoder.tdlib().decode(OkResponse.self, from: roundTripData)
    }

    @Test("MessagesResponse с вложенным массивом Message")
    func testMessagesResponse() throws {
        let message1 = Message(
            id: 1,
            chatId: 100,
            date: 1234567890,
            content: .text(FormattedText(text: "Hello", entities: nil))
        )
        let message2 = Message(
            id: 2,
            chatId: 100,
            date: 1234567891,
            content: .unsupported
        )

        let messages = MessagesResponse(
            totalCount: 2,
            messages: [message1, message2]
        )

        // Round-trip через TDLibJSON
        let data = try JSONEncoder.tdlib().encode(messages)

        guard let dict = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            Issue.record("Failed to parse MessagesResponse as [String: Any]")
            return
        }

        let json = try TDLibJSON(parsing: dict)

        #expect(json["total_count"] as? Int == 2)

        let messagesArray = json["messages"] as? [[String: Any]]
        #expect(messagesArray?.count == 2)

        // Декодируем обратно
        let roundTripData = try JSONSerialization.data(withJSONObject: json.data)
        let decoded = try JSONDecoder.tdlib().decode(MessagesResponse.self, from: roundTripData)

        #expect(decoded.totalCount == 2)
        #expect(decoded.messages.count == 2)
    }

    // MARK: - 9. Empty Collections

    @Test("Пустые массивы и словари")
    func testEmptyCollections() throws {
        let input: [String: Any] = [
            "emptyArray": [] as [Any],
            "emptyDict": [:] as [String: Any]
        ]

        let json = try TDLibJSON(parsing: input)

        let emptyArray = json["emptyArray"] as? [Any]
        #expect(emptyArray?.isEmpty == true)

        let emptyDict = json["emptyDict"] as? [String: Any]
        #expect(emptyDict?.isEmpty == true)
    }

    // MARK: - 10. Edge Cases

    @Test("Граничные случаи: максимальные значения, длинные строки")
    func testEdgeCases() throws {
        let longString = String(repeating: "a", count: 10000)

        let input: [String: Any] = [
            "maxInt64": Int64.max,
            "minInt64": Int64.min,
            "maxInt32": Int32.max,
            "longString": longString
        ]

        let json = try TDLibJSON(parsing: input)

        #expect(json["maxInt64"] as? Int64 == Int64.max)
        #expect(json["minInt64"] as? Int64 == Int64.min)
        #expect(json["maxInt32"] as? Int32 == Int32.max)
        #expect((json["longString"] as? String)?.count == 10000)
    }

    // MARK: - 11. Underlying Access

    @Test("Свойство data предоставляет доступ к валидированному словарю")
    func testDataAccess() throws {
        let input: [String: Any] = [
            "key": "value",
            "count": 42
        ]

        let json = try TDLibJSON(parsing: input)

        // data должен быть [String: any Sendable]
        #expect(json.data["key"] as? String == "value")
        #expect(json.data["count"] as? Int == 42)

        // Должны мочь передать в JSONSerialization
        let serialized = try JSONSerialization.data(withJSONObject: json.data)
        #expect(serialized.count > 0)
    }
}
