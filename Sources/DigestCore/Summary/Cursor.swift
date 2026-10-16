import TgClientModels
import Foundation

/// Курсор прочитанного (<doc:GetSummary>, шаг `read`): разбор из JSON и применение через `MarkAsReadService`.
public enum Cursor {
    /// Разбор курсора из JSON (файл по умолчанию или `--cursor`).
    public static func parse(_ data: Data) throws -> [CursorEntry] {
        try JSONDecoder().decode([CursorEntry].self, from: data)
    }

    /// Пометить прочитанным до `upToMessageId` на каждую запись (чат или тему форума).
    /// Частичный отказ — per-entry в результате; порядок — по чату, затем по теме.
    public static func apply(_ cursor: [CursorEntry], using service: MarkAsReadService) async -> [(entry: CursorEntry, result: Result<Void, Error>)] {
        guard !cursor.isEmpty else { return [] }
        let plain = cursor.filter { $0.forumTopicId == nil }
        let byChat = Dictionary(plain.map { ($0.chatId, [$0.upToMessageId]) }, uniquingKeysWith: { a, _ in a })
        let plainResults = await service.markAsRead(byChat)
        let topicResults = await service.markForumTopicsAsRead(cursor.filter { $0.forumTopicId != nil })
        let all = plain.compactMap { entry in plainResults[entry.chatId].map { (entry: entry, result: $0) } } + topicResults
        return all.sorted { ($0.entry.chatId, $0.entry.forumTopicId ?? 0) < ($1.entry.chatId, $1.entry.forumTopicId ?? 0) }
    }
}
