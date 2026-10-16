import TgClientModels
import Foundation
import Logging

/// Обработчик запросов CLI к службе (<doc:GetSummary>, вариант (b)): служба — единственный владелец сессии
/// TDLib, CLI шлёт одну JSON-строку `BrokerRequest` и получает `BrokerResponse`.
///
/// Разрешены только R0 (`get-summary`) и R1 (`read`); отправка и прочее сюда не попадают (send-gate).
public struct Broker: Sendable {
    private let source: ChannelMessageSource
    private let markAsRead: MarkAsReadService
    private let logger: Logger

    public init(source: ChannelMessageSource, markAsRead: MarkAsReadService, logger: Logger) {
        self.source = source
        self.markAsRead = markAsRead
        self.logger = logger
    }

    public func handle(_ request: Data) async -> Data {
        let req: BrokerRequest
        do {
            req = try JSONDecoder().decode(BrokerRequest.self, from: request)
        } catch {
            return failure(BrokerError(errorType: "parse_error", field: nil, message: "запрос не JSON {\"op\":…}: \(error)"))
        }
        logger.info("broker: op=\(req.op)")
        switch req.op {
        case "get-summary":
            do {
                let snapshot = try await SummaryCollector(source: source).collect()
                logger.info("broker: get-summary → \(snapshot.chats.count) чатов")
                return success(snapshot)
            } catch {
                logger.error("broker: get-summary упал: \(error)")
                return failure(BrokerError(errorType: "upstream_failure", field: nil, message: "get-summary: \(error)"))
            }
        case "read":
            guard let cursor = req.cursor else {
                return failure(BrokerError(errorType: "schema_validation", field: "cursor", message: "read: нужен cursor [{chat_id, up_to_message_id}]"))
            }
            let report = ReadReport(await Cursor.apply(cursor, using: markAsRead))
            logger.info("broker: read → помечено \(report.marked)/\(report.chats.count)")
            return success(report)
        default:
            logger.warning("broker: отказ op=\(req.op)")
            return failure(BrokerError(errorType: "permission_denied", field: "op", message: "op «\(req.op)» не разрешён: только get-summary (R0) и read (R1)"))
        }
    }

    private func success<T: Codable>(_ result: T) -> Data {
        encode(BrokerResponse(ok: true, result: result, error: nil))
    }

    private func failure(_ error: BrokerError) -> Data {
        encode(BrokerResponse<ReadReport>(ok: false, result: nil, error: error))
    }

    private func encode<T: Codable>(_ response: BrokerResponse<T>) -> Data {
        // Кодирование своих Codable-типов не падает; на крайний случай — валидный ответ-ошибка
        (try? SummarySnapshot.encoder().encode(response))
            ?? Data(#"{"ok":false,"error":{"error_type":"upstream_failure","message":"encode"}}"#.utf8)
    }
}

public struct BrokerRequest: Codable, Sendable {
    public let op: String
    public let cursor: [CursorEntry]?
    public init(op: String, cursor: [CursorEntry]? = nil) { self.op = op; self.cursor = cursor }
}

public struct BrokerResponse<T: Codable>: Codable {
    public let ok: Bool
    public let result: T?
    public let error: BrokerError?
}

/// Ошибка в формате Factor 4 (первая строка stderr CLI).
public struct BrokerError: Codable, Equatable, Sendable, Error {
    public let errorType: String
    public let field: String?
    public let message: String
    public let hint: String?
    public init(errorType: String, field: String?, message: String, hint: String? = nil) {
        self.errorType = errorType; self.field = field; self.message = message; self.hint = hint
    }
    enum CodingKeys: String, CodingKey { case errorType = "error_type", field, message, hint }
}

/// Итог `read`: сколько чатов помечено + per-chat результат (частичный отказ не валит остальные).
public struct ReadReport: Codable, Equatable, Sendable {
    public struct Chat: Codable, Equatable, Sendable {
        public let chatId: Int64
        /// Тема форума; `nil` — обычный чат.
        public let forumTopicId: Int32?
        public let ok: Bool
        public let error: String?
        public init(chatId: Int64, forumTopicId: Int32? = nil, ok: Bool, error: String?) {
            self.chatId = chatId; self.forumTopicId = forumTopicId; self.ok = ok; self.error = error
        }
        enum CodingKeys: String, CodingKey { case chatId = "chat_id", forumTopicId = "forum_topic_id", ok, error }
    }
    public let marked: Int
    public let chats: [Chat]

    public init(marked: Int, chats: [Chat]) { self.marked = marked; self.chats = chats }

    /// Из результата `Cursor.apply` (порядок сохраняется).
    public init(_ results: [(entry: CursorEntry, result: Result<Void, Error>)]) {
        let chats = results.map { entry, r -> Chat in
            if case .failure(let e) = r { return Chat(chatId: entry.chatId, forumTopicId: entry.forumTopicId, ok: false, error: "\(e)") }
            return Chat(chatId: entry.chatId, forumTopicId: entry.forumTopicId, ok: true, error: nil)
        }
        self.init(marked: chats.filter(\.ok).count, chats: chats)
    }
}

extension JSONDecoder {
    /// Декодер ответов службы: даты ISO-8601, как у `SummarySnapshot.encoder()`.
    public static func broker() -> JSONDecoder {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }
}
