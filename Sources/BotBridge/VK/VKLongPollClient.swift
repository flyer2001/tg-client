import Foundation
import Logging
import DigestCore
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// Цикл VK Bots Long Poll: держит один исходящий запрос к VK и отдаёт входящие сообщения обработчику.
///
/// Не нужен публичный домен/HTTPS/nginx (в отличие от Callback API webhook).
///
/// **VK docs:** https://dev.vk.com/ru/api/bots-long-poll/getting-started
/// **Spike:** `spikes/vk-longpoll/README.md` — реальные ответы VK, отмена URLSession на Linux.
public actor VKLongPollClient {
    private let groupId: Int
    private let token: String
    private let apiVersion: String
    private let wait: Int
    private let httpClient: any HTTPClientProtocol
    private let logger: Logger
    private let onMessage: @Sendable (VKMessage) async -> Void
    /// Пауза между повторами после сетевой ошибки. Внедряется, чтобы тесты не ждали реальное время.
    private let sleep: @Sendable (Duration) async throws -> Void
    /// Текущая сессия; переживает сетевые ошибки (повторяем только `a_check`, не `getLongPollServer`).
    private var session: VKLongPollSession?

    public init(
        groupId: Int,
        token: String,
        apiVersion: String = "5.199",
        wait: Int = 25,
        httpClient: any HTTPClientProtocol,
        logger: Logger,
        sleep: @escaping @Sendable (Duration) async throws -> Void = { try await Task.sleep(for: $0) },
        onMessage: @escaping @Sendable (VKMessage) async -> Void
    ) {
        self.groupId = groupId
        self.token = token
        self.apiVersion = apiVersion
        self.wait = wait
        self.httpClient = httpClient
        self.logger = logger
        self.onMessage = onMessage
        self.sleep = sleep
    }

    /// Бесконечный цикл до отмены задачи.
    ///
    /// Сетевые ошибки — повтор с растущей паузой (1, 2, 4 … 60 c), сбрасывается после успешного ответа.
    /// Ошибка VK API на `getLongPollServer` (ключ, права, Long Poll выключен) — постоянная, `run()` бросает её.
    public func run() async throws {
        var retryDelay = Duration.seconds(1)
        while !Task.isCancelled {
            do {
                try await step()
                retryDelay = .seconds(1)
            } catch let error as URLError where error.code != .cancelled {
                logger.warning("VK LongPoll: сеть недоступна, повтор через \(retryDelay)", metadata: ["error": .string("\(error.code)")])
                try await sleep(retryDelay)
                retryDelay = min(retryDelay * 2, .seconds(60))
            }
        }
    }

    /// Один шаг цикла: при необходимости получить сессию, один `a_check`, раздать события.
    private func step() async throws {
        if session == nil { session = try await fetchSession() }
        guard var current = session else { return }

        let response = try await poll(current)
        switch response.failed {
        case 2:  // истёк key — новый key, ts прежний
            var fresh = try await fetchSession()
            fresh.ts = current.ts
            session = fresh
            return
        case 3:  // информация потеряна — новая сессия целиком
            session = try await fetchSession()
            return
        default:  // nil или 1 (устаревшая история — VK прислал новый ts)
            break
        }
        if let ts = response.ts { current.ts = ts }
        session = current
        for update in response.updates ?? [] {
            if let message = update.object?.message {
                await onMessage(message)
            }
        }
    }

    // MARK: - VK requests

    private func fetchSession() async throws -> VKLongPollSession {
        var components = URLComponents(string: "https://api.vk.com/method/groups.getLongPollServer")!
        components.queryItems = [
            .init(name: "group_id", value: String(groupId)),
            .init(name: "access_token", value: token),
            .init(name: "v", value: apiVersion),
        ]
        logger.info("VK LongPoll: groups.getLongPollServer", metadata: ["group_id": .stringConvertible(groupId)])
        let data = try await httpClient.send(request: URLRequest(url: components.url!))
        let response = try JSONDecoder().decode(VKAPIResponse<VKLongPollSession>.self, from: data)
        guard let session = response.response else {
            throw VKLongPollError.serverRequestFailed(response.error?.description ?? "empty response")
        }
        return session
    }

    private func poll(_ session: VKLongPollSession) async throws -> VKLongPollResponse {
        var components = URLComponents(string: session.server)!
        components.queryItems = [
            .init(name: "act", value: "a_check"),
            .init(name: "key", value: session.key),
            .init(name: "ts", value: session.ts),
            .init(name: "wait", value: String(wait)),
        ]
        var request = URLRequest(url: components.url!)
        request.timeoutInterval = TimeInterval(wait + 10)  // spike: VK отвечает на wait=25 через ~22 c
        let data = try await httpClient.send(request: request)
        return try JSONDecoder().decode(VKLongPollResponse.self, from: data)
    }
}

public enum VKLongPollError: Error, Equatable {
    /// `groups.getLongPollServer` вернул ошибку VK API (неверный ключ, нет права `manage`, Long Poll выключен).
    case serverRequestFailed(String)
}

/// Сессия Long Poll из `groups.getLongPollServer`. `ts` — строка (spike).
struct VKLongPollSession: Decodable, Sendable {
    let server: String
    let key: String
    var ts: String
}

/// Ответ `a_check`: либо `ts` + `updates`, либо `failed` (1/2/3).
struct VKLongPollResponse: Decodable, Sendable {
    let ts: String?
    let updates: [VKLongPollUpdate]?
    let failed: Int?
}

struct VKLongPollUpdate: Decodable, Sendable {
    let type: String
    let object: VKObject?
}
