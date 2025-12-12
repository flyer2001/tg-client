import Testing
import Foundation
import FoundationExtensions
@testable import DigestCore

/// Unit тесты для OpenAI Chat API моделей.
///
/// **Документация OpenAI:**
/// - Chat Completions: https://platform.openai.com/docs/api-reference/chat/create
/// - Response Object: https://platform.openai.com/docs/api-reference/chat/object
///
/// **Scope:** Тестируем encoding/decoding моделей через roundtrip.
/// Encoder/decoder стратегии (snake_case) протестированы в JSONCodingTests.
@Suite("OpenAI Models Encoding/Decoding")
struct OpenAIModelsTests {

    @Test("ChatCompletionRequest: encoding с snake_case")
    func encodeRequest() throws {
        let request = ChatCompletionRequest(
            model: "gpt-3.5-turbo",
            messages: [
                ChatMessage(role: "system", content: "You are a helpful assistant."),
                ChatMessage(role: "user", content: "Hello!")
            ],
            maxTokens: 100
        )

        let encoder = JSONEncoder.openAI()
        let data = try encoder.encode(request)
        let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]

        // Проверяем что encoding работает (max_tokens в snake_case)
        #expect(json["max_tokens"] as? Int == 100)
        #expect(json["model"] as? String == "gpt-3.5-turbo")

        let messages = json["messages"] as! [[String: String]]
        #expect(messages.count == 2)
        #expect(messages[0]["role"] == "system")
    }

    @Test("ChatCompletionResponse: roundtrip encode → decode")
    func roundTripResponse() throws {
        let original = ChatCompletionResponse(
            choices: [
                ChatCompletionResponse.Choice(
                    message: ChatCompletionResponse.Choice.Message(
                        content: "**Tech News:** Обзор новых фич Swift 6"
                    )
                )
            ]
        )

        let encoder = JSONEncoder.openAI()
        let decoder = JSONDecoder.openAI()

        let data = try encoder.encode(original)
        let decoded = try decoder.decode(ChatCompletionResponse.self, from: data)

        #expect(decoded.choices.count == original.choices.count)
        #expect(decoded.choices[0].message.content == original.choices[0].message.content)
    }

    @Test("ChatCompletionResponse: пустой массив choices")
    func roundTripEmptyChoices() throws {
        let original = ChatCompletionResponse(choices: [])

        let encoder = JSONEncoder.openAI()
        let decoder = JSONDecoder.openAI()

        let data = try encoder.encode(original)
        let decoded = try decoder.decode(ChatCompletionResponse.self, from: data)

        #expect(decoded.choices.isEmpty)
    }

    // MARK: - OpenAIError.is5xx Tests

    @Test("OpenAIError.is5xx: 500 Internal Server Error")
    func is5xxServerError500() {
        let error = OpenAIError.httpError(statusCode: 500)
        #expect(error.is5xx == true)
    }

    @Test("OpenAIError.is5xx: 502 Bad Gateway")
    func is5xxBadGateway() {
        let error = OpenAIError.httpError(statusCode: 502)
        #expect(error.is5xx == true)
    }

    @Test("OpenAIError.is5xx: 503 Service Unavailable")
    func is5xxServiceUnavailable() {
        let error = OpenAIError.httpError(statusCode: 503)
        #expect(error.is5xx == true)
    }

    @Test("OpenAIError.is5xx: 429 Rate Limited (НЕ 5xx)")
    func is5xxRateLimited() {
        let error = OpenAIError.httpError(statusCode: 429)
        #expect(error.is5xx == false)
    }

    @Test("OpenAIError.is5xx: 401 Unauthorized (НЕ 5xx)")
    func is5xxUnauthorized() {
        let error = OpenAIError.httpError(statusCode: 401)
        #expect(error.is5xx == false)
    }

    @Test("OpenAIError.is5xx: rateLimited enum case (НЕ httpError)")
    func is5xxRateLimitedCase() {
        let error = OpenAIError.rateLimited
        #expect(error.is5xx == false)
    }

    @Test("OpenAIError.is5xx: emptyResponse (НЕ httpError)")
    func is5xxEmptyResponse() {
        let error = OpenAIError.emptyResponse
        #expect(error.is5xx == false)
    }
}
