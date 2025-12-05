import Foundation

// MARK: - Request Models

/// Запрос к OpenAI Chat API.
struct ChatCompletionRequest: Encodable {
    let model: String
    let messages: [ChatMessage]
    let maxTokens: Int

    enum CodingKeys: String, CodingKey {
        case model
        case messages
        case maxTokens = "max_tokens"
    }
}

/// Сообщение в чате OpenAI.
struct ChatMessage: Encodable {
    let role: String
    let content: String
}

// MARK: - Response Models

/// Ответ от OpenAI Chat API.
struct ChatCompletionResponse: Codable {
    let choices: [Choice]

    struct Choice: Codable {
        let message: Message

        struct Message: Codable {
            let content: String
        }
    }
}
