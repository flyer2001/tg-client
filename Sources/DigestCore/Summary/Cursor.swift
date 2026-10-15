import TgClientModels
import Foundation

/// Курсор прочитанного (<doc:GetSummary>, шаг `read`): разбор из JSON и применение через `MarkAsReadService`.
public enum Cursor {
    /// Разбор курсора из JSON (файл по умолчанию или `--cursor`).
    public static func parse(_ data: Data) throws -> [CursorEntry] {
        try JSONDecoder().decode([CursorEntry].self, from: data)
    }

    /// Пометить прочитанным до `upToMessageId` на каждый чат. Частичный отказ — per-chat в результате.
    public static func apply(_ cursor: [CursorEntry], using service: MarkAsReadService) async -> [Int64: Result<Void, Error>] {
        guard !cursor.isEmpty else { return [:] }
        let byChat = Dictionary(cursor.map { ($0.chatId, [$0.upToMessageId]) }, uniquingKeysWith: { a, _ in a })
        return await service.markAsRead(byChat)
    }
}
