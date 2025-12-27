import Foundation
#if os(Linux)
import FoundationNetworking
#endif
import Logging
import FoundationExtensions

/// Отправка уведомлений через Telegram Bot API.
///
/// ## Ссылки
///
/// - Telegram Bot API: https://core.telegram.org/bots/api#sendmessage
/// - ``SendMessageRequest`` — request model
/// - ``SendMessageResponse`` — response model
/// - ``BotAPIError`` — error model
public actor TelegramBotNotifier: BotNotifierProtocol {
    private struct Specs {
        static let baseURL = "https://api.telegram.org"
    }

    private let botToken: String
    private let chatId: Int64
    private let httpClient: HTTPClientProtocol
    private let logger: Logger

    public init(
        botToken: String,
        chatId: Int64,
        httpClient: HTTPClientProtocol,
        logger: Logger
    ) {
        self.botToken = botToken
        self.chatId = chatId
        self.httpClient = httpClient
        self.logger = logger
    }

    public func send(_ message: String) async throws {
        logger.info("Sending message to Telegram bot", metadata: [
            "chat_id": "\(chatId)",
            "message_length": "\(message.count)"
        ])

        guard message.count <= 4096 else {
            throw BotAPIError.messageTooLong(length: message.count, limit: 4096)
        }

        try await withRetry(
            maxAttempts: 3,
            baseDelay: .seconds(1),
            timeout: .seconds(30),
            operation: {
                let request = SendMessageRequest(
                    chatId: self.chatId,
                    text: message
                )

                guard let url = URL(string: "\(Specs.baseURL)/bot\(self.botToken)/sendMessage") else {
                    throw BotAPIError.invalidConfiguration(message: "Failed to construct API URL")
                }
                var urlRequest = URLRequest(url: url)
                urlRequest.httpMethod = "POST"
                urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
                urlRequest.httpBody = try JSONEncoder.telegramBot().encode(request)

                let responseData = try await self.httpClient.send(request: urlRequest)
                let response = try JSONDecoder.telegramBot().decode(SendMessageResponse.self, from: responseData)

                guard response.ok else {
                    throw BotAPIError.apiError(
                        code: response.errorCode ?? 0,
                        description: response.description ?? "Unknown error"
                    )
                }

                self.logger.info("Message sent successfully", metadata: [
                    "message_id": "\(response.result?.messageId ?? 0)"
                ])
            },
            shouldRetry: { error, _ in
                if let botError = error as? BotAPIError {
                    return botError.isRetryable
                }
                return false
            },
            logger: logger
        )
    }
}
