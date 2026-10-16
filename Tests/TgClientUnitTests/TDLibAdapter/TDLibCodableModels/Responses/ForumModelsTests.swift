import TgClientModels
import TGClientInterfaces
import Foundation
import Testing
import FoundationExtensions
@testable import TDLibAdapter

/// Unit-тесты моделей форума (чат с темами) — на **реальном JSON** TDLib 1.8.67.
///
/// Источник JSON: `scripts/spikes/forum_spike.py --dump-json` по реальному форуму 2026-10-16; тексты, имена и ссылки
/// заменены заглушками, лишние поля оставлены — декодер обязан их пропускать.
///
/// **TDLib API:**
/// - https://core.telegram.org/tdlib/docs/classtd_1_1td__api_1_1supergroup.html (`is_forum`)
/// - https://core.telegram.org/tdlib/docs/classtd_1_1td__api_1_1forum_topic.html
/// - https://core.telegram.org/tdlib/docs/classtd_1_1td__api_1_1get_forum_topic_history.html
/// - https://core.telegram.org/tdlib/docs/classtd_1_1td__api_1_1message_source_forum_topic_history.html
///
/// **Поведение (спайк):** у каждой темы свои `unread_count` и `last_read_inbox_message_id`; чатовый `unread_count`
/// = сумма тем. Пометить тему: `viewMessages(last_message темы, source=messageSourceForumTopicHistory, force_read)`.
@Suite("Unit: модели форума (реальный JSON)")
struct ForumModelsTests {

    @Test("supergroup: is_forum и is_channel из реального ответа")
    func decodeSupergroup() throws {
        let json = #"{"@type":"supergroup","id":4220812466,"date":1791450442,"status":{"@type":"chatMemberStatusMember","member_until_date":0},"member_count":369,"boost_level":0,"has_linked_chat":false,"sign_messages":true,"join_to_send_messages":true,"is_slow_mode_enabled":false,"is_channel":false,"is_broadcast_group":false,"is_forum":true,"is_direct_messages_group":false,"has_forum_tabs":false,"paid_message_star_count":0,"@extra":5,"@client_id":1}"#

        let sg = try JSONDecoder.tdlib().decode(SupergroupResponse.self, from: Data(json.utf8))

        #expect(sg == SupergroupResponse(id: 4220812466, isChannel: false, isForum: true))
    }

    /// Регрессия (component-тест форума, 2026-10-16): `TDLibClient` перегоняет ответ через JSONSerialization,
    /// на Linux true/false становятся 1/0 — синтезированный декодер Bool падал.
    @Test("Bool числом (после JSONSerialization на Linux): is_forum=1, is_general=0")
    func decodeBoolAsNumber() throws {
        let sg = try JSONDecoder.tdlib().decode(SupergroupResponse.self,
                                                from: Data(#"{"@type":"supergroup","id":5,"is_channel":0,"is_forum":1}"#.utf8))
        let info = try JSONDecoder.tdlib().decode(ForumTopicInfo.self,
                                                  from: Data(#"{"chat_id":-5,"forum_topic_id":7,"name":"T","is_general":0}"#.utf8))

        #expect(sg == SupergroupResponse(id: 5, isChannel: false, isForum: true))
        #expect(info == ForumTopicInfo(chatId: -5, forumTopicId: 7, name: "T", isGeneral: false))
    }

    @Test("forumTopics: id темы, имя, unread, last_read, id последнего сообщения")
    func decodeForumTopics() throws {
        let json = #"{"@type":"forumTopics","total_count":9,"topics":[{"@type":"forumTopic","info":{"@type":"forumTopicInfo","chat_id":-1004220812466,"forum_topic_id":1,"name":"General","icon":{"@type":"forumTopicIcon","color":7322096,"custom_emoji_id":"0"},"creation_date":1781049533,"creator_id":{"@type":"messageSenderChat","chat_id":-1004220812466},"is_general":true,"is_outgoing":false,"is_closed":true,"is_hidden":false,"is_name_implicit":false},"last_message":{"@type":"message","id":1256194048,"sender_id":{"@type":"messageSenderUser","user_id":5409669324},"chat_id":-1004220812466,"is_outgoing":false,"date":1792133700,"topic_id":{"@type":"messageTopicForum","forum_topic_id":1},"sender_tag":"tag","content":{"@type":"messageText","text":{"@type":"formattedText","text":"…","entities":[]}}},"order":"9223372036854775807","is_pinned":false,"unread_count":1,"last_read_inbox_message_id":1203765248,"last_read_outbox_message_id":0,"unread_mention_count":0,"unread_reaction_count":0,"notification_settings":{"@type":"chatNotificationSettings","use_default_mute_for":true}}],"@extra":6,"@client_id":1}"#

        let response = try JSONDecoder.tdlib().decode(ForumTopicsResponse.self, from: Data(json.utf8))

        let topic = try #require(response.topics.first)
        #expect(response.totalCount == 9)
        #expect(topic.info.forumTopicId == 1)
        #expect(topic.info.name == "General")
        #expect(topic.info.isGeneral)
        #expect(topic.unreadCount == 1)
        #expect(topic.lastReadInboxMessageId == 1203765248)
        #expect(topic.lastMessage?.id == 1256194048)
    }

    @Test("forumTopic без last_message (TDLib: may be null) → lastMessage nil")
    func decodeTopicWithoutLastMessage() throws {
        let json = #"{"@type":"forumTopics","total_count":1,"topics":[{"@type":"forumTopic","info":{"@type":"forumTopicInfo","chat_id":-1,"forum_topic_id":7,"name":"T","is_general":false},"unread_count":0,"last_read_inbox_message_id":0}]}"#

        let response = try JSONDecoder.tdlib().decode(ForumTopicsResponse.self, from: Data(json.utf8))

        #expect(response.topics.first?.lastMessage == nil)
    }

    @Test("getForumTopicHistory → messages: сообщение темы декодируется обычным Message")
    func decodeTopicHistory() throws {
        let json = #"{"@type":"messages","total_count":1,"messages":[{"@type":"message","id":1256194048,"sender_id":{"@type":"messageSenderUser","user_id":5409669324},"chat_id":-1004220812466,"is_outgoing":false,"is_pinned":false,"can_be_saved":true,"is_channel_post":false,"contains_unread_mention":false,"date":1792133700,"edit_date":0,"unread_reactions":[],"topic_id":{"@type":"messageTopicForum","forum_topic_id":1},"self_destruct_in":0.0,"auto_delete_in":0.0,"via_bot_user_id":0,"sender_tag":"tag","author_signature":"","media_album_id":"0","content":{"@type":"messageText","text":{"@type":"formattedText","text":"Привет","entities":[]}},"chat_instance":"0"}],"@extra":7,"@client_id":1}"#

        let response = try JSONDecoder.tdlib().decode(MessagesResponse.self, from: Data(json.utf8))

        #expect(response.messages.map(\.id) == [1256194048])
        #expect(response.messages.first?.content.textOrCaption == "Привет")
    }

    /// Запрос как строка JSON с отсортированными ключами — ожидание читается как есть.
    private func json<T: Encodable>(_ value: T) throws -> String {
        let encoder = JSONEncoder.tdlib()
        encoder.outputFormatting = [.sortedKeys]
        return String(decoding: try encoder.encode(value), as: UTF8.self)
    }

    @Test("getSupergroup / getForumTopics / getForumTopicHistory кодируются по TDLib API")
    func encodeRequests() throws {
        #expect(try json(GetSupergroupRequest(supergroupId: 4220812466)) == #"{"@type":"getSupergroup","supergroup_id":4220812466}"#)
        #expect(try json(GetForumTopicsRequest(chatId: -1004220812466, limit: 100))
                == #"{"@type":"getForumTopics","chat_id":-1004220812466,"limit":100,"offset_date":0,"offset_forum_topic_id":0,"offset_message_id":0,"query":""}"#)
        #expect(try json(GetForumTopicHistoryRequest(chatId: -1004220812466, forumTopicId: 7, fromMessageId: 0, offset: 0, limit: 5))
                == #"{"@type":"getForumTopicHistory","chat_id":-1004220812466,"forum_topic_id":7,"from_message_id":0,"limit":5,"offset":0}"#)
    }

    @Test("viewMessages с источником темы: source = messageSourceForumTopicHistory; без источника — поля нет")
    func encodeViewMessagesSource() throws {
        #expect(try json(ViewMessagesRequest(chatId: -1, messageIds: [5], forceRead: true, source: .forumTopicHistory))
                == #"{"@type":"viewMessages","chat_id":-1,"force_read":true,"message_ids":[5],"source":{"@type":"messageSourceForumTopicHistory"}}"#)
        #expect(try json(ViewMessagesRequest(chatId: -1, messageIds: [5], forceRead: true))
                == #"{"@type":"viewMessages","chat_id":-1,"force_read":true,"message_ids":[5]}"#)
    }
}
