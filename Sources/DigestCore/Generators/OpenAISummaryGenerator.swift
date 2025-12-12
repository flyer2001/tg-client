import Foundation
#if os(Linux)
import FoundationNetworking
#endif
import TgClientModels
import Logging
import FoundationExtensions

/// Генератор AI-саммари через OpenAI Chat API.
///
/// Использует GPT-3.5-turbo для создания дайджестов из сообщений каналов.
public actor OpenAISummaryGenerator: SummaryGeneratorProtocol {
    private let apiKey: String
    private let httpClient: HTTPClientProtocol
    private let logger: Logger
    private let endpoint = URL(string: "https://api.openai.com/v1/chat/completions")!

    public init(apiKey: String, httpClient: HTTPClientProtocol, logger: Logger) {
        self.apiKey = apiKey
        self.httpClient = httpClient
        self.logger = logger
    }

    public func generate(messages: [SourceMessage]) async throws -> String {
        // 1. Пустой список → пустой дайджест
        guard !messages.isEmpty else {
            return ""
        }

        // 2. Формируем промпт
        let prompt = buildPrompt(messages: messages)

        // 3. Создаем запрос к OpenAI
        let requestBody = ChatCompletionRequest(
            model: "gpt-3.5-turbo",
            messages: [
                ChatMessage(role: "system", content: systemPrompt),
                ChatMessage(role: "user", content: prompt)
            ],
            maxTokens: 1000
        )

        // 4. Выполняем HTTP запрос
        var urlRequest = URLRequest(url: endpoint)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        urlRequest.timeoutInterval = 60
        urlRequest.httpBody = try JSONEncoder.openAI().encode(requestBody)

        let data: Data
        do {
            data = try await httpClient.send(request: urlRequest)
        } catch let HTTPError.clientError(statusCode, errorData) {
            // TODO: Создать OpenAIErrorResponse модель для парсинга errorData
            // OpenAI возвращает {"error": {"message": "...", "type": "..."}}
            // Это даст более точные сообщения об ошибках для логирования

            // Логируем raw тело ошибки
            logger.error("OpenAI HTTP \(statusCode)", metadata: [
                "body": .string(String(data: errorData, encoding: .utf8) ?? "")
            ])

            // Конвертируем в OpenAI-специфичные ошибки
            if statusCode == 401 {
                throw OpenAIError.unauthorized
            } else if statusCode == 429 {
                throw OpenAIError.rateLimited
            } else {
                throw OpenAIError.httpError(statusCode: statusCode)
            }
        } catch let HTTPError.serverError(statusCode, _) {
            throw OpenAIError.httpError(statusCode: statusCode)
        }

        // 5. Декодируем ответ
        let chatResponse = try JSONDecoder.openAI().decode(ChatCompletionResponse.self, from: data)

        guard let firstChoice = chatResponse.choices.first else {
            throw OpenAIError.emptyResponse
        }

        return firstChoice.message.content
    }
}

// MARK: - Private Helpers

extension OpenAISummaryGenerator {
    private func buildPrompt(messages: [SourceMessage]) -> String {
        // Группируем по каналам
        let groupedByChannel = Dictionary(grouping: messages) { $0.channelTitle }

        var promptLines: [String] = []

        for (channelTitle, channelMessages) in groupedByChannel.sorted(by: { $0.key < $1.key }) {
            promptLines.append("\n**\(channelTitle):**")

            for message in channelMessages {
                if let link = message.link {
                    promptLines.append("- [\(message.content)](\(link))")
                } else {
                    promptLines.append("- \(message.content)")
                }
            }
        }

        return promptLines.joined(separator: "\n")
    }

    private var systemPrompt: String {
        """
        Ты — ассистент для создания дайджестов сообщений из Telegram-каналов.

        Правила:
        1. Группируй сообщения по каналам
        2. Для каждого канала: краткий обзор (1-2 предложения) + ключевые темы
        3. Сохраняй ссылки на сообщения в формате Telegram Markdown
        4. Максимальная длина ответа: 3800 символов (резерв для Telegram лимита 4096)
        5. Используй Telegram MarkdownV2: *жирный*, _курсив_, `код`
        6. Пиши кратко и по делу, без воды

        Если сообщений нет, верни пустую строку.
        """
    }
}

// MARK: - Errors

public enum OpenAIError: Error, LocalizedError, Equatable {
    case unauthorized
    case rateLimited
    case httpError(statusCode: Int)
    case emptyResponse
    case invalidResponse

    public var errorDescription: String? {
        switch self {
        case .unauthorized:
            return "OpenAI API unauthorized (401). Check API key."
        case .rateLimited:
            return "OpenAI API rate limit exceeded (429). Retry later."
        case .httpError(let statusCode):
            return "OpenAI API returned HTTP \(statusCode)"
        case .emptyResponse:
            return "OpenAI API returned empty response"
        case .invalidResponse:
            return "Invalid response from OpenAI API"
        }
    }

    /// Проверка на server error (5xx) для retry логики
    public var is5xx: Bool {
        if case .httpError(let statusCode) = self {
            return statusCode >= 500 && statusCode < 600
        }
        return false
    }
}
