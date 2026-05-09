import Foundation
#if os(Linux)
import FoundationNetworking
#endif
import Logging
import DigestCore

/// Клиент исходящих вызовов к api.vk.com.
///
/// Минимальный набор методов нужных для бота: `messages.send`.
/// Используем стандартный `HTTPClientProtocol` из `DigestCore` — единый стек HTTP в проекте.
public struct VKAPIClient: Sendable {
    private let token: String
    private let apiVersion: String
    private let httpClient: any HTTPClientProtocol
    private let logger: Logger
    private let baseURL: URL

    public init(
        token: String,
        apiVersion: String = "5.199",
        httpClient: any HTTPClientProtocol,
        logger: Logger,
        baseURL: URL = URL(string: "https://api.vk.com")!
    ) {
        self.token = token
        self.apiVersion = apiVersion
        self.httpClient = httpClient
        self.logger = logger
        self.baseURL = baseURL
    }

    /// Отправляет текстовое сообщение пользователю / в чат.
    ///
    /// VK ограничение — 4096 символов на сообщение. Разбивка на чанки делается выше по стеку
    /// (см. `RawDigestFormatter`), здесь просто шлём то что дали.
    ///
    /// - Parameters:
    ///   - peerId: ID получателя (для личного сообщения = user id, для чата = `2_000_000_000 + chat_id`)
    ///   - text: Текст сообщения (≤ 4096 символов)
    /// - Returns: VK message id отправленного сообщения
    /// - Throws: `HTTPError` (сетевые/HTTP) или `VKAPIError` (ошибка VK API)
    @discardableResult
    public func sendMessage(peerId: Int64, text: String) async throws -> VKMessageSendResult {
        let randomId = Int64.random(in: 1...Int64.max)
        let params: [String: String] = [
            "peer_id": String(peerId),
            "message": text,
            "random_id": String(randomId)
        ]

        logger.info("VK messages.send", metadata: [
            "peer_id": .stringConvertible(peerId),
            "text_len": .stringConvertible(text.count),
            "random_id": .stringConvertible(randomId)
        ])

        let response: VKAPIResponse<VKMessageSendResult> = try await call(
            method: "messages.send",
            params: params
        )

        if let error = response.error {
            logger.error("VK messages.send failed", metadata: [
                "error_code": .stringConvertible(error.errorCode),
                "error_msg": .string(error.errorMsg)
            ])
            throw error
        }

        guard let messageId = response.response else {
            logger.error("VK messages.send: empty response")
            throw VKAPIError(errorCode: -1, errorMsg: "empty response")
        }

        logger.info("VK messages.send sent", metadata: ["message_id": .stringConvertible(messageId)])
        return messageId
    }

    // MARK: - Private

    /// Низкоуровневый вызов method'а VK API через POST application/x-www-form-urlencoded.
    private func call<T: Decodable & Sendable>(
        method: String,
        params: [String: String]
    ) async throws -> VKAPIResponse<T> {
        var url = baseURL
        url.appendPathComponent("method")
        url.appendPathComponent(method)

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")

        var allParams = params
        allParams["access_token"] = token
        allParams["v"] = apiVersion

        request.httpBody = encodeFormBody(allParams)

        let data = try await httpClient.send(request: request)
        return try JSONDecoder().decode(VKAPIResponse<T>.self, from: data)
    }

    private func encodeFormBody(_ params: [String: String]) -> Data {
        var allowed = CharacterSet.urlQueryAllowed
        allowed.remove(charactersIn: "+&=")  // эти символы должны быть процентно-кодированы внутри значений

        let body = params
            .map { key, value in
                let encodedKey = key.addingPercentEncoding(withAllowedCharacters: allowed) ?? key
                let encodedValue = value.addingPercentEncoding(withAllowedCharacters: allowed) ?? value
                return "\(encodedKey)=\(encodedValue)"
            }
            .joined(separator: "&")

        return Data(body.utf8)
    }
}

extension VKAPIError: Error {}
