import TgClientModels
import Foundation

/// Собирает непрочитанное в `SummarySnapshot`. Только чтение — не помечает прочитанным.
public struct SummaryCollector {
    private let source: ChannelMessageSource

    public init(source: ChannelMessageSource) { self.source = source }

    public func collect(now: Date = Date()) async throws -> SummarySnapshot {
        let chats = try await source.fetchUnreadChats()
        var out: [SummaryChat] = []
        for chat in chats {
            let (messages, newestId) = try await source.fetchMessagesWithNewestId(for: chat)   // oldest→newest
            let last = newestId ?? chat.lastReadInboxMessageId
            out.append(SummaryChat(
                chatId: chat.id, title: chat.title, kind: chat.kind, unreadCount: chat.unreadCount,
                messages: messages.map { SummaryMessage(messageId: $0.messageId, text: $0.content) },
                lastMessageId: last))
        }
        let cursor = out.map { CursorEntry(chatId: $0.chatId, upToMessageId: $0.lastMessageId) }
        return SummarySnapshot(collectedAt: now, chats: out, cursor: cursor)
    }
}
