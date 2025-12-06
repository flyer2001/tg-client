import Testing
import Foundation
@testable import FoundationExtensions

@Suite("KeyedDecodingContainer+Int64/Int32")
struct KeyedDecodingContainerIntTests {

    struct TestInt64: Codable {
        let value: Int64

        enum CodingKeys: String, CodingKey {
            case value
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            value = try container.decodeInt64(forKey: .value)
        }
    }

    struct TestInt32: Codable {
        let value: Int32

        enum CodingKeys: String, CodingKey {
            case value
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            value = try container.decodeInt32(forKey: .value)
        }
    }

    // MARK: - Int64 Tests

    @Test("Int64: Декодирует из String (большое число > 2^53)")
    func int64FromString() throws {
        let json = """
        {"value": "9223372036854775807"}
        """

        let decoded = try JSONDecoder().decode(TestInt64.self, from: Data(json.utf8))
        #expect(decoded.value == 9223372036854775807) // Int64.max
    }

    @Test("Int64: Декодирует из Int (маленькое число)")
    func int64FromInt() throws {
        let json = """
        {"value": 12345}
        """

        let decoded = try JSONDecoder().decode(TestInt64.self, from: Data(json.utf8))
        #expect(decoded.value == 12345)
    }

    @Test("Int64: Декодирует отрицательное из String")
    func int64NegativeFromString() throws {
        let json = """
        {"value": "-9223372036854775808"}
        """

        let decoded = try JSONDecoder().decode(TestInt64.self, from: Data(json.utf8))
        #expect(decoded.value == -9223372036854775808) // Int64.min
    }

    @Test("Int64: Бросает ошибку при невалидном значении")
    func int64ThrowsOnInvalid() throws {
        let json = """
        {"value": "not_a_number"}
        """

        #expect(throws: DecodingError.self) {
            try JSONDecoder().decode(TestInt64.self, from: Data(json.utf8))
        }
    }

    @Test("Int64: Бросает ошибку при переполнении")
    func int64ThrowsOnOverflow() throws {
        let json = """
        {"value": "99999999999999999999"}
        """

        #expect(throws: DecodingError.self) {
            try JSONDecoder().decode(TestInt64.self, from: Data(json.utf8))
        }
    }

    // MARK: - Int32 Tests

    @Test("Int32: Декодирует из String")
    func int32FromString() throws {
        let json = """
        {"value": "2147483647"}
        """

        let decoded = try JSONDecoder().decode(TestInt32.self, from: Data(json.utf8))
        #expect(decoded.value == 2147483647) // Int32.max
    }

    @Test("Int32: Декодирует из Int")
    func int32FromInt() throws {
        let json = """
        {"value": 12345}
        """

        let decoded = try JSONDecoder().decode(TestInt32.self, from: Data(json.utf8))
        #expect(decoded.value == 12345)
    }

    @Test("Int32: Декодирует отрицательное из String")
    func int32NegativeFromString() throws {
        let json = """
        {"value": "-2147483648"}
        """

        let decoded = try JSONDecoder().decode(TestInt32.self, from: Data(json.utf8))
        #expect(decoded.value == -2147483648) // Int32.min
    }

    @Test("Int32: Бросает ошибку при невалидном значении")
    func int32ThrowsOnInvalid() throws {
        let json = """
        {"value": "not_a_number"}
        """

        #expect(throws: DecodingError.self) {
            try JSONDecoder().decode(TestInt32.self, from: Data(json.utf8))
        }
    }

    @Test("Int32: Бросает ошибку при переполнении")
    func int32ThrowsOnOverflow() throws {
        // Число больше Int32.max
        let json = """
        {"value": "9999999999"}
        """

        #expect(throws: DecodingError.self) {
            try JSONDecoder().decode(TestInt32.self, from: Data(json.utf8))
        }
    }

    @Test("Int64: Бросает keyNotFound при отсутствующем ключе")
    func int64ThrowsKeyNotFound() throws {
        let json = """
        {"other_field": "123"}
        """

        #expect(throws: DecodingError.self) {
            try JSONDecoder().decode(TestInt64.self, from: Data(json.utf8))
        }
    }

    @Test("Int32: Бросает keyNotFound при отсутствующем ключе")
    func int32ThrowsKeyNotFound() throws {
        let json = """
        {"other_field": "123"}
        """

        #expect(throws: DecodingError.self) {
            try JSONDecoder().decode(TestInt32.self, from: Data(json.utf8))
        }
    }
}
