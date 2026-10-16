import TgClientModels
import Foundation

/// Собирает непрочитанное в `SummarySnapshot`. Только чтение — не помечает прочитанным.
public struct SummaryCollector {
    private let source: ChannelMessageSource

    public init(source: ChannelMessageSource) { self.source = source }

    public func collect(now: Date = Date()) async throws -> SummarySnapshot {
        let chats = try await source.fetchUnreadChats()
        var out: [SummaryChat] = []
        var cursor: [CursorEntry] = []
        for chat in chats {
            if let topics = try await source.forumTopicsWithUnread(for: chat) {
                // Форум: по темам, курсор — запись на тему (у каждой своя граница прочитанного)
                var messages: [SummaryMessage] = []
                var last = chat.lastReadInboxMessageId
                for topic in topics {
                    let (msgs, newestId) = try await source.fetchTopicMessages(chat: chat, topic: topic)
                    let summaryTopic = SummaryTopic(id: topic.info.forumTopicId, name: topic.info.name)
                    messages += msgs.map { SummaryMessage(messageId: $0.messageId, text: $0.content, topic: summaryTopic) }
                    guard let upTo = newestId ?? topic.lastMessage?.id else { continue }
                    cursor.append(CursorEntry(chatId: chat.id, upToMessageId: upTo, forumTopicId: topic.info.forumTopicId))
                    last = max(last, upTo)
                }
                out.append(SummaryChat(chatId: chat.id, title: chat.title, kind: chat.kind, unreadCount: chat.unreadCount,
                                       messages: messages, lastMessageId: last))
                continue
            }
            let (messages, newestId) = try await source.fetchMessagesWithNewestId(for: chat)   // oldest→newest
            let last = newestId ?? chat.lastReadInboxMessageId
            out.append(SummaryChat(
                chatId: chat.id, title: chat.title, kind: chat.kind, unreadCount: chat.unreadCount,
                messages: messages.map { SummaryMessage(messageId: $0.messageId, text: $0.content) },
                lastMessageId: last))
            cursor.append(CursorEntry(chatId: chat.id, upToMessageId: last))
        }
        return SummarySnapshot(collectedAt: now, chats: out, cursor: cursor)
    }
}
