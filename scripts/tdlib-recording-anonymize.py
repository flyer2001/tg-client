#!/usr/bin/env python3
"""Анонимизация записи трафика TDLib (RecordingTDLibFFI, TG_TDLIB_RECORD) для контрактных тестов.

  scripts/tdlib-recording-anonymize.py raw.jsonl > Tests/Fixtures/tdlib/<name>.jsonl

Что делает:
- оставляет только запросы из белого списка (чтение чатов/истории/форумов, пометка) и ответы на них —
  стартовые запросы службы (setTdlibParameters с api_hash и ключом БД, addProxy с паролем, авторизация, getMe)
  выкидываются целиком (проверка 2026-10-16 нашла их в сырой записи);
- оставляет updates, которые разбирает клиент
  (updateNewChat / updateChatPosition / updateChatReadInbox); остальные updates (пользователи, опции…) — выкидывает;
- строки с личными данными (тексты, имена, названия, юзернеймы, телефоны, ссылки, файлы) → заглушки `<поле>#N`,
  одно и то же значение → одна и та же заглушка;
- id перенумеровывает согласованно: чаты (знак сохраняется), пользователи, супергруппы; id сообщений — монотонно
  (порядок важен логике: max, `> last_read`), кратно 2^20, как у TDLib, но с 2^40 — отдельный от реальных
  диапазон, чтобы проверка утечек (совпадение с сырым id) не давала ложных срабатываний.

После анонимизации — **просмотреть файл глазами** перед коммитом (репозиторий публичный).
"""
import json
import sys

KEEP_UPDATES = {"updateNewChat", "updateChatPosition", "updateChatReadInbox"}
KEEP_REQUESTS = {"getChats", "loadChats", "getChat", "getChatHistory", "getSupergroup", "getForumTopics",
                 "getForumTopicHistory", "viewMessages"}
# Строковые id (файлы, реакции, опросы) логике не нужны — заглушка
REDACT_STRING_IDS = {"id", "unique_id", "poll_option_id", "profile_background_custom_emoji_id"}
REDACT = {"text", "title", "name", "first_name", "last_name", "username", "usernames", "active_usernames",
          "editable_username", "phone_number", "description", "url", "question", "sender_tag",
          "author_signature", "custom_emoji_id", "path", "remote", "local", "minithumbnail", "thumbnail",
          "reply_markup", "photo", "video", "audio", "document", "sticker", "animation", "voice_note",
          "video_note", "web_page", "link_preview", "emoji_status", "background_custom_emoji_id",
          "accent_color_id", "profile_accent_color_id", "client_data", "theme_name", "draft_message",
          "sender_name", "forward_info", "import_info", "via_bot_user_id_never"}
MESSAGE_ID_KEYS = {"message_id", "reply_markup_message_id", "next_offset_message_id", "from_message_id", "last_read_inbox_message_id", "last_read_outbox_message_id",
                   "last_message_id", "reply_in_chat_id_never", "up_to_message_id", "message_thread_id"}
CHAT_ID_KEYS = {"chat_id", "sender_chat_id", "linked_chat_id", "story_poster_chat_id"}
USER_ID_KEYS = {"user_id", "via_bot_user_id", "sender_business_bot_user_id", "creator_user_id",
                "saved_messages_topic_id"}   # = id пользователя-владельца — найдено проверкой 2026-10-16

placeholders: dict = {}
maps = {"chat": {}, "user": {}, "supergroup": {}, "basic_group": {}}


def placeholder(key, value):
    k = (key, json.dumps(value, sort_keys=True, ensure_ascii=False))
    if k not in placeholders:
        placeholders[k] = f"{key}#{len(placeholders) + 1}"
    return placeholders[k]


def remap(kind, value):
    m = maps[kind]
    if value not in m:
        n = len(m) + 1
        if kind == "chat":
            m[value] = -1000000000000 - n if value <= -1000000000000 else (-n if value < 0 else 100000 + n)
        else:
            m[value] = 100000 + n
    return m[value]


def collect_message_ids(o, parent_type, out):
    if isinstance(o, dict):
        t = o.get("@type", parent_type)
        for k, v in o.items():
            if k == "id" and t == "message" and isinstance(v, int):
                out.add(v)
            elif k in MESSAGE_ID_KEYS and isinstance(v, int) and v > 0:
                out.add(v)
            elif k == "message_ids" and isinstance(v, list):
                out.update(x for x in v if isinstance(x, int))
            else:
                collect_message_ids(v, t, out)
    elif isinstance(o, list):
        for v in o:
            collect_message_ids(v, parent_type, out)


def rewrite(o, parent_type, msg_map):
    if isinstance(o, dict):
        t = o.get("@type", parent_type)
        out = {}
        for k, v in o.items():
            if k in REDACT and v not in (None, "", [], {}):
                out[k] = placeholder(k, v) if not isinstance(v, (dict, list)) or k == "text" else {"@type": "redacted"}
                if k == "text" and isinstance(v, dict):   # formattedText — структуру оставляем
                    out[k] = {"@type": "formattedText", "text": placeholder("text", v.get("text")), "entities": []}
            elif k in REDACT_STRING_IDS and isinstance(v, str) and v not in ("", "0"):
                out[k] = placeholder(k, v)
            elif k == "id" and isinstance(v, int):
                out[k] = (msg_map.get(v, v) if t == "message" else
                          remap("chat", v) if t == "chat" else
                          remap("user", v) if t == "user" else
                          remap("supergroup", v) if t == "supergroup" else
                          remap("basic_group", v) if t == "basicGroup" else v)
            elif k in MESSAGE_ID_KEYS and isinstance(v, int):
                out[k] = msg_map.get(v, v)
            elif k == "message_ids" and isinstance(v, list):
                out[k] = [msg_map.get(x, x) for x in v]
            elif k == "chat_ids" and isinstance(v, list):   # getChats — без этого в записи оставались реальные id
                out[k] = [remap("chat", x) if isinstance(x, int) else x for x in v]
            elif k == "user_ids" and isinstance(v, list):
                out[k] = [remap("user", x) if isinstance(x, int) else x for x in v]
            elif k in CHAT_ID_KEYS and isinstance(v, int):
                out[k] = remap("chat", v)
            elif k in USER_ID_KEYS and isinstance(v, int) and v != 0:
                out[k] = remap("user", v)
            elif k == "supergroup_id" and isinstance(v, int):
                out[k] = remap("supergroup", v)
            elif k == "basic_group_id" and isinstance(v, int):
                out[k] = remap("basic_group", v)
            else:
                out[k] = rewrite(v, t, msg_map)
        return out
    if isinstance(o, list):
        return [rewrite(v, parent_type, msg_map) for v in o]
    return o


def main(path):
    lines = []
    kept_extras = set()
    for raw in open(path, encoding="utf-8"):
        rec = json.loads(raw)
        j = rec["json"]
        if rec["dir"] == "send":
            if j.get("@type") not in KEEP_REQUESTS or "@extra" not in j:
                continue
            kept_extras.add(str(j["@extra"]))
        elif "@extra" in j:
            if str(j["@extra"]) not in kept_extras:
                continue
        elif j.get("@type") not in KEEP_UPDATES:
            continue
        lines.append(rec)
    ids = set()
    for rec in lines:
        collect_message_ids(rec["json"], None, ids)
    msg_map = {v: (1 << 40) + ((i + 1) << 20) for i, v in enumerate(sorted(ids))}
    for rec in lines:
        rec["json"] = rewrite(rec["json"], None, msg_map)
        rec["json"].pop("@client_id", None)
        print(json.dumps(rec, ensure_ascii=False, sort_keys=True))


if __name__ == "__main__":
    main(sys.argv[1])
