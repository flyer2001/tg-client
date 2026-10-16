#!/usr/bin/env python3
"""Спайк: темы форума и пометка темы прочитанной. Запускать при ОСТАНОВЛЕННОЙ службе tg-client.

  forum_spike.py <chat_id>                 — только чтение: чат + темы (unread / last_read / last_message)
  forum_spike.py <chat_id> --mark <topic>  — пометить тему прочитанной до её last_message, перечитать
  forum_spike.py <chat_id> --mark auto     — то же для темы с наименьшим ненулевым unread
  forum_spike.py <chat_id> --probe         — только чтение: что отдают getChatHistory и getForumTopicHistory
  forum_spike.py <chat_id> --dump-json     — сырой JSON getSupergroup / getForumTopics / getForumTopicHistory
                                             (тексты, имена, ссылки — заглушки) для unit-тестов моделей
"""
import ctypes, json, os, sys, time
from urllib.parse import urlparse

env = {}
for line in open(os.path.expanduser("~/tg-client/.env")):
    line = line.strip()
    if line and not line.startswith("#") and "=" in line:
        k, v = line.split("=", 1)
        env[k] = v.strip().strip('"').strip("'")
state = os.path.expanduser(os.path.expandvars(env.get("TDLIB_STATE_DIR", "~/.tdlib")))   # в .env — `$HOME/.tdlib`
if not os.path.exists(state + "/db/td.binlog"):
    sys.exit(f"нет сессии в {state}/db — не создаю новую базу")

td = ctypes.CDLL("/usr/local/lib/libtdjson.so")
td.td_create_client_id.restype = ctypes.c_int
td.td_send.argtypes = [ctypes.c_int, ctypes.c_char_p]
td.td_receive.restype = ctypes.c_char_p
td.td_receive.argtypes = [ctypes.c_double]
td.td_execute.restype = ctypes.c_char_p
td.td_execute.argtypes = [ctypes.c_char_p]
td.td_execute(json.dumps({"@type": "setLogVerbosityLevel", "new_verbosity_level": 1}).encode())
cid = td.td_create_client_id()
seq = 0

def send(q):
    td.td_send(cid, json.dumps(q).encode())

def call(q, timeout=30):
    global seq
    seq += 1
    q = dict(q, **{"@extra": seq})
    send(q)
    end = time.time() + timeout
    while time.time() < end:
        r = td.td_receive(1.0)
        if r:
            o = json.loads(r)
            if o.get("@extra") == seq:
                return o
    raise TimeoutError(q["@type"])

# авторизация (сессия уже есть)
send({"@type": "getOption", "name": "version"})
ready = False
end = time.time() + 60
while not ready and time.time() < end:
    r = td.td_receive(1.0)
    if not r:
        continue
    o = json.loads(r)
    if o.get("@type") != "updateAuthorizationState":
        continue
    st = o["authorization_state"]["@type"]
    if st == "authorizationStateWaitTdlibParameters":
        send({"@type": "setTdlibParameters", "use_test_dc": False,
              "database_directory": state + "/db", "files_directory": state + "/files",
              "database_encryption_key": env.get("TDLIB_DATABASE_ENCRYPTION_KEY", ""),
              "use_file_database": True, "use_chat_info_database": True, "use_message_database": True,
              "use_secret_chats": False, "api_id": int(env["TELEGRAM_API_ID"]), "api_hash": env["TELEGRAM_API_HASH"],
              "system_language_code": "en", "device_model": "tg-client spike", "system_version": "",
              "application_version": "0.1.0"})
        if env.get("TDLIB_PROXY"):
            u = urlparse(env["TDLIB_PROXY"])
            ptype = {"@type": "proxyTypeHttp", "username": u.username or "", "password": u.password or "", "http_only": False} \
                if u.scheme == "http" else {"@type": "proxyTypeSocks5", "username": u.username or "", "password": u.password or ""}
            send({"@type": "addProxy", "proxy": {"@type": "proxy", "server": u.hostname, "port": u.port, "type": ptype},
                  "enable": True, "comment": "tg-client"})
    elif st == "authorizationStateReady":
        ready = True
    elif st != "authorizationStateWaitEncryptionKey":
        sys.exit(f"неожиданное состояние авторизации: {st} (нужен интерактивный вход — не в спайке)")
if not ready:
    sys.exit("авторизация не дошла до Ready за 60 с")

chat_id = int(sys.argv[1])

def show():
    chat = call({"@type": "getChat", "chat_id": chat_id})
    t = chat["type"]
    sg = call({"@type": "getSupergroup", "supergroup_id": t["supergroup_id"]}) if t["@type"] == "chatTypeSupergroup" else {}
    print(f"chat: {chat['title'][:40]!r} unread_count={chat['unread_count']} last_read={chat['last_read_inbox_message_id']} "
          f"last_message={(chat.get('last_message') or {}).get('id')} is_marked_as_unread={chat.get('is_marked_as_unread')} "
          f"is_forum={sg.get('is_forum')} view_as_topics={chat.get('view_as_topics')}")
    topics = call({"@type": "getForumTopics", "chat_id": chat_id, "query": "", "offset_date": 0,
                   "offset_message_id": 0, "offset_forum_topic_id": 0, "limit": 100})
    if topics.get("@type") == "error":
        print("getForumTopics:", topics)
        return []
    out = []
    for tp in topics["topics"]:
        info = tp["info"]
        last = (tp.get("last_message") or {}).get("id")
        out.append((info["forum_topic_id"], last, tp["unread_count"]))
        print(f"  topic {info['forum_topic_id']:>6} unread={tp['unread_count']:>4} last_read={tp['last_read_inbox_message_id']} "
              f"last_message={last} {info['name'][:35]!r}")
    print(f"  тем: {len(out)} (total_count={topics.get('total_count')})")
    return out

def topic_of(m):
    t = m.get("topic_id") or {}
    return f"{t.get('@type')}:{t.get('forum_topic_id')}" if t else None

topics = show()
if "--probe" in sys.argv:
    print("\n== getChatHistory(from=0, limit=15): id, topic_id, тип контента")
    h = call({"@type": "getChatHistory", "chat_id": chat_id, "from_message_id": 0, "offset": 0, "limit": 15, "only_local": False})
    for m in h.get("messages", []):
        print(f"  {m['id']} topic={topic_of(m)} {m['content']['@type']}")
    print(f"  всего: {len(h.get('messages', []))} total_count={h.get('total_count')}")
    for tid, last, unread in [t for t in topics if t[2] > 0][:2]:
        print(f"\n== getForumTopicHistory(topic={tid}, from=0, limit=5) — unread={unread}")
        r = call({"@type": "getForumTopicHistory", "chat_id": chat_id, "forum_topic_id": tid,
                  "from_message_id": 0, "offset": 0, "limit": 5})
        if r.get("@type") == "error":
            print("  ", r)
            continue
        for m in r.get("messages", []):
            print(f"  {m['id']} topic={topic_of(m)} {m['content']['@type']}")
REDACT = {"text", "name", "title", "first_name", "last_name", "username", "phone_number", "url", "description",
          "question", "custom_emoji_id", "editable_username", "remote", "local", "minithumbnail", "thumbnail"}

def redact(o):
    if isinstance(o, dict):
        return {k: ("<redacted>" if k in REDACT and isinstance(v, (str, dict, list)) else redact(v)) for k, v in o.items()}
    if isinstance(o, list):
        return [redact(v) for v in o]
    return o

if "--dump-json" in sys.argv:
    chat = call({"@type": "getChat", "chat_id": chat_id})
    sg = call({"@type": "getSupergroup", "supergroup_id": chat["type"]["supergroup_id"]})
    print("== getSupergroup\n" + json.dumps(redact(sg), ensure_ascii=False))
    tps = call({"@type": "getForumTopics", "chat_id": chat_id, "query": "", "offset_date": 0,
                "offset_message_id": 0, "offset_forum_topic_id": 0, "limit": 2})
    tps["topics"] = tps["topics"][:1]
    print("== getForumTopics (1 тема)\n" + json.dumps(redact(tps), ensure_ascii=False))
    tid = tps["topics"][0]["info"]["forum_topic_id"]
    h = call({"@type": "getForumTopicHistory", "chat_id": chat_id, "forum_topic_id": tid,
              "from_message_id": 0, "offset": 0, "limit": 1})
    print("== getForumTopicHistory (1 сообщение)\n" + json.dumps(redact(h), ensure_ascii=False))
if "--mark" in sys.argv:
    arg = sys.argv[sys.argv.index("--mark") + 1]
    unread = [t for t in topics if t[2] > 0]
    if arg == "auto" and not unread:
        sys.exit("нет тем с непрочитанным — помечать нечего")
    topic_id = min(unread, key=lambda t: t[2])[0] if arg == "auto" else int(arg)
    last = {t[0]: t[1] for t in topics}[topic_id]
    print(f"\n== viewMessages chat={chat_id} topic={topic_id} message_ids=[{last}] source=messageSourceForumTopicHistory force_read=true")
    print(call({"@type": "viewMessages", "chat_id": chat_id, "message_ids": [last],
                "source": {"@type": "messageSourceForumTopicHistory"}, "force_read": True}))
    time.sleep(5)
    print("\n== после пометки")
    show()

send({"@type": "close"})
end = time.time() + 15
while time.time() < end:
    r = td.td_receive(1.0)
    if r and '"authorizationStateClosed"' in r.decode():
        break
