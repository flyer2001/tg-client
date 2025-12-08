import Testing
import Foundation
@testable import FoundationExtensions

@Suite("KeyedDecodingContainer+Bool")
struct KeyedDecodingContainerBoolTests {

    struct TestBool: Codable {
        let value: Bool

        enum CodingKeys: String, CodingKey {
            case value
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            value = try container.decodeBool(forKey: .value)
        }
    }

    // MARK: - Bool Tests

    @Test("Bool: Декодирует true из JSON Boolean")
    func boolFromBooleanTrue() throws {
        let json = """
        {"value": true}
        """

        let decoded = try JSONDecoder().decode(TestBool.self, from: Data(json.utf8))
        #expect(decoded.value == true)
    }

    @Test("Bool: Декодирует false из JSON Boolean")
    func boolFromBooleanFalse() throws {
        let json = """
        {"value": false}
        """

        let decoded = try JSONDecoder().decode(TestBool.self, from: Data(json.utf8))
        #expect(decoded.value == false)
    }

    // MARK: - Int Fallback Tests (TDLib)

    @Test("Bool: Декодирует true из Int (1)")
    func boolFromIntOne() throws {
        let json = """
        {"value": 1}
        """

        let decoded = try JSONDecoder().decode(TestBool.self, from: Data(json.utf8))
        #expect(decoded.value == true)
    }

    @Test("Bool: Декодирует false из Int (0)")
    func boolFromIntZero() throws {
        let json = """
        {"value": 0}
        """

        let decoded = try JSONDecoder().decode(TestBool.self, from: Data(json.utf8))
        #expect(decoded.value == false)
    }

    @Test("Bool: Декодирует true из любого Int != 0")
    func boolFromIntNonZero() throws {
        let json = """
        {"value": 42}
        """

        let decoded = try JSONDecoder().decode(TestBool.self, from: Data(json.utf8))
        #expect(decoded.value == true)
    }

    @Test("Bool: Декодирует true из отрицательного Int")
    func boolFromIntNegative() throws {
        let json = """
        {"value": -1}
        """

        let decoded = try JSONDecoder().decode(TestBool.self, from: Data(json.utf8))
        #expect(decoded.value == true)
    }

    // MARK: - Error Tests

    @Test("Bool: Бросает keyNotFound при отсутствующем ключе")
    func boolThrowsKeyNotFound() throws {
        let json = """
        {"other_field": true}
        """

        #expect(throws: DecodingError.self) {
            try JSONDecoder().decode(TestBool.self, from: Data(json.utf8))
        }
    }

    @Test("Bool: Бросает dataCorrupted при невалидном типе (String)")
    func boolThrowsOnInvalidType() throws {
        let json = """
        {"value": "not_a_bool"}
        """

        #expect(throws: DecodingError.self) {
            try JSONDecoder().decode(TestBool.self, from: Data(json.utf8))
        }
    }

    @Test("Bool: Бросает dataCorrupted при null")
    func boolThrowsOnNull() throws {
        let json = """
        {"value": null}
        """

        #expect(throws: DecodingError.self) {
            try JSONDecoder().decode(TestBool.self, from: Data(json.utf8))
        }
    }
}
