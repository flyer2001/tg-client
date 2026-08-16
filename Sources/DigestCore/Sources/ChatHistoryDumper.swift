import Foundation
import Logging
import TGClientInterfaces
import TgClientModels

/// Статистика выгрузки истории чата (без содержимого сообщений).
public struct ChatHistoryDumpStats: Sendable, Equatable {
    /// Всего выгружено сообщений.
    public var messageCount = 0
    /// Из них текстовых (включая подписи к медиа).
    public var textCount = 0
    /// Из них без текста (стикеры, голосовые без подписи и т.д.).
    public var otherCount = 0
    /// Дата самого старого сообщения (Unix timestamp).
    public var oldestDate: Int32?
    /// Дата самого нового сообщения (Unix timestamp).
    public var newestDate: Int32?
    /// Сколько запросов getChatHistory сделано.
    public var pages = 0
}

/// Одна строка JSONL-выгрузки.
private struct DumpLine: Encodable {
    let id: Int64
    let date: Int32
    let senderId: Int64?
    let isOutgoing: Bool
    let type: String
    let text: String?

    enum CodingKeys: String, CodingKey {
        case id, date, type, text
        case senderId = "sender_id"
        case isOutgoing = "is_outgoing"
    }
}

/// Выгружает историю чата целиком — от последнего сообщения до самого первого — в JSONL-файл.
///
/// **Отличие от `ChannelMessageSource.fetchLastMessages`:** там жёсткие лимиты
/// (5 попыток, cap на количество) и нетекстовые сообщения выбрасываются.
/// Здесь цикл идёт пока TDLib отдаёт новые сообщения, а нетекстовые пишутся
/// плейсхолдером `type=other`, чтобы в архиве не было дыр.
///
/// **TDLib quirk:** `getChatHistory(from: 0)` берёт только локальный кэш;
/// последующие запросы с `from = id самого старого из прошлого ответа`
/// заставляют TDLib дотянуть более старые с сервера.
///
/// **Порядок в файле:** newest → oldest (как отдаёт TDLib). Развернуть — `tac file.jsonl`.
/// Пишем потоково: обрыв на середине оставляет валидный частичный файл.
///
/// - Parameters:
///   - chatId: ID чата
///   - url: путь итогового .jsonl (перезаписывается)
///   - pageSize: размер страницы getChatHistory
///   - maxPages: страховка от бесконечного цикла
///   - fetchPage: `(fromMessageId, limit) -> сообщения newest-first`
/// - Returns: счётчики выгрузки (без содержимого сообщений)
public func dumpChatHistory(
    chatId: Int64,
    to url: URL,
    pageSize: Int32 = 100,
    maxPages: Int = 10_000,
    logger: Logger,
    fetchPage: (Int64, Int32) async throws -> [Message]
) async throws -> ChatHistoryDumpStats {
    guard FileManager.default.createFile(atPath: url.path, contents: nil) else {
        throw CocoaError(.fileWriteNoPermission)
    }
    let handle = try FileHandle(forWritingTo: url)
    defer { try? handle.close() }

    let encoder = JSONEncoder()
    var stats = ChatHistoryDumpStats()
    var seenIds = Set<Int64>()
    var fromMessageId: Int64 = 0

    for _ in 1...maxPages {
        let page = try await fetchPage(fromMessageId, pageSize)
        stats.pages += 1
        if page.isEmpty {
            logger.info("dumpChatHistory: пустая страница, история кончилась")
            break
        }

        var newCount = 0
        for message in page where !seenIds.contains(message.id) {
            seenIds.insert(message.id)
            newCount += 1

            let text: String? = if case .text(let formatted) = message.content { formatted.text } else { nil }
            let line = DumpLine(
                id: message.id,
                date: message.date,
                senderId: message.senderId,
                isOutgoing: message.isOutgoing,
                type: text == nil ? "other" : "text",
                text: text
            )
            var data = try encoder.encode(line)
            data.append(0x0A)
            handle.write(data)

            stats.messageCount += 1
            if text == nil { stats.otherCount += 1 } else { stats.textCount += 1 }
            stats.oldestDate = min(stats.oldestDate ?? message.date, message.date)
            stats.newestDate = max(stats.newestDate ?? message.date, message.date)
        }

        logger.info("dumpChatHistory: страница \(stats.pages) — \(page.count) получено, \(newCount) новых, всего \(stats.messageCount)")
        if newCount == 0 { break }

        // newest-first → самый старый = последний в массиве
        fromMessageId = page.last?.id ?? 0
    }

    if stats.pages >= maxPages {
        logger.warning("dumpChatHistory: достигнут maxPages=\(maxPages), выгрузка может быть неполной")
    }
    try handle.synchronize()
    return stats
}
