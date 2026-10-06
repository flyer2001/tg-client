# VK Bot Bridge RFC

> **Статус:** Draft
> **Дата:** 2026-05-05
> **Автор:** Sergey + Claude
> **Целевая версия:** TBD (параллельно к v0.4.0 mark-as-read)

---

## 🎯 Цель

Предоставить альтернативный канал доступа к дайджесту, когда **мобильный интернет блокирует Telegram**. Запрос команды и доставка результата идут через **VK сообщество (бот)**, а сам сбор сообщений — через уже работающий `ChannelMessageSource` (TDLib).

**Scope (в этом RFC):**
- Принимать webhook от VK Callback API
- Команда `/digest` (или просто любое сообщение от owner) → собрать непрочитанные → ответить **сырым** списком сообщений в VK
- Защитить от чужих вызовов
- Жить рядом с уже работающим `cashflow.service` на `cashflow-game.ru`

**Out of scope (этого RFC):**
- AI саммаризация поверх raw (используем уже готовый `OpenAISummaryGenerator` опционально позже)
- `markAsRead` после доставки (это v0.4.0, отдельная задача)
- Полноценный TDD цикл (юзер явно отложил, делаем без формального outside-in workflow)
- Long Poll fallback (если webhook ляжет)

---

## 📋 Архитектурные решения

| Аспект | Решение | Обоснование |
|---|---|---|
| **Транспорт VK** | Callback API (webhook) | На сервере уже есть nginx + HTTPS + cert. Long Poll проигрывает по latency и трафику. |
| **HTTP сервер в Swift** | Hummingbird 2.x | Лёгкий (~5 deps vs Vapor ~15), нам нужен 1 endpoint. Swift 6 ready, Linux ready. |
| **Where lives the code** | Новый таргет `BotBridge` в Package.swift | Чистая граница: `BotBridge` зависит от `DigestCore` + `Hummingbird`, но `DigestCore` не знает про VK/HTTP. |
| **Long-running vs spawn-per-command** | Long-running service | Cold start TDLib = 30-60 сек, не вписывается в SLA webhook (~10 сек до retry от VK). |
| **Авторизация** | Whitelist по `VK_BOT_OWNER_IDS` (env, через запятую) | VK даёт `from_id` в `message_new`. Подделать без угона аккаунта нельзя. Чужие — молча игнорируем. |
| **VK secret** | Проверяем поле `secret` в каждом callback POST | Защита от случайных POST'ов на наш endpoint извне. |
| **Concurrent requests** | In-memory mutex (actor) на handler | Параллельные `fetchUnreadMessages` ломают TDLib. Очередь — FIFO. |
| **Формат ответа** | Plain text, без AI, чанки ≤ 4096 символов | Юзер явно попросил "в сыром виде". 4096 — лимит VK на одно сообщение. |
| **Конфирмация Callback API** | Endpoint должен возвращать строку из настроек VK при `type: "confirmation"` | Это разовый шаг при подключении, но без него не активируется webhook. |
| **TDD** | Не делаем сейчас | Юзер явно отложил. Минимально — smoke test после деплоя. К полноценному TDD вернёмся позже отдельной задачей. |

---

## 🏗️ Архитектура

### Поток webhook

```
VK servers
    │ POST https://cashflow-game.ru/vkWebHook
    │ Content-Type: application/json
    │ {type, object, secret, group_id}
    ▼
nginx :443 (existing)
    │ proxy_pass http://127.0.0.1:8082;
    ▼
tg-client.service (long-running)
    │ Hummingbird router
    │ POST /vkWebHook → VKWebhookHandler
    ▼
VKWebhookHandler
    │ 1. validate secret
    │ 2. switch on event.type:
    │    - "confirmation" → return CONFIRMATION_CODE
    │    - "message_new" → process command
    │    - else → "ok" (200)
    ▼
CommandProcessor (actor)
    │ 1. check from_id in whitelist
    │ 2. acquire mutex (1 fetch at a time)
    │ 3. call ChannelMessageSource.fetchUnreadMessages()
    │ 4. format raw chunks
    │ 5. for each chunk: VKAPIClient.messagesSend(peer_id, chunk)
    │ 6. release mutex
    │
    │ ⚠️ Возвращаем "ok" в webhook СРАЗУ после валидации,
    │     обработка идёт в Task — VK не любит длинные ответы.
    ▼
VKAPIClient
    │ POST https://api.vk.com/method/messages.send
    │ ?peer_id&message&random_id&access_token&v=5.199
    ▼
VK сервер → юзер видит сообщения в чате с сообществом
```

### Таргеты Package.swift

```
App (executable)
  ├── DigestCore (existing)
  ├── TDLibAdapter (existing)
  └── BotBridge (NEW)
        ├── DigestCore (для ChannelMessageSource, HTTPClientProtocol)
        ├── TDLibAdapter (для TDLibClient passthrough)
        └── Hummingbird (NEW dep)
```

**Принцип:** `BotBridge` — это адаптер между внешним миром (VK) и нашим доменом (`DigestCore`). Никакой бизнес-логики в нём нет, только I/O и роутинг.

---

## 📦 Новая зависимость: Hummingbird

```swift
.package(url: "https://github.com/hummingbird-project/hummingbird", from: "2.0.0")
```

**Чеклист валидации (по ARCHITECTURE.md):**
- [x] Сборка инкрементальная < 30 сек на macOS — да, Hummingbird лёгкий
- [x] Платформы: macOS + Linux — да, тестируется в CI
- [x] Swift 6: полная совместимость — да, 2.x ветка Swift 6 ready
- [x] Structured Concurrency: async/await, actors — да, нативно
- [x] Поддержка: commits за последние 6 месяцев — да, активный проект
- [x] Лицензия: Apache 2.0 — совместима

**Каскадные зависимости:** swift-nio, swift-log (уже есть), swift-metrics, swift-service-lifecycle (~5-6 пакетов суммарно).

**Билд impact на Linux:** ожидается +20-40 сек к чистой сборке. У нас и так используется `./scripts/build-clean.sh`, не критично.

⚠️ **Risk:** SwiftPM hang issue (#9441) на Linux может стать хуже с +5 пакетов. **Mitigation:** билдим через `./scripts/build-clean.sh`, как и сейчас.

---

## 🧱 Структура кода

### Новые файлы

```
Sources/BotBridge/
├── HTTP/
│   └── BotBridgeServer.swift          # Hummingbird app + router
├── VK/
│   ├── VKAPIClient.swift              # обёртка над api.vk.com (messages.send)
│   ├── VKModels.swift                 # Codable: VKUpdate, VKMessage, VKConfirmation
│   └── VKWebhookHandler.swift         # парсинг входящего POST, диспатч
├── Commands/
│   ├── CommandProcessor.swift         # actor с очередью + whitelist
│   └── RawDigestFormatter.swift       # [SourceMessage] → [String chunks]
└── Config/
    └── BotBridgeConfig.swift          # env vars: token, group_id, owners, secret, port
```

### Изменения в существующих файлах

```
Package.swift
  + .package Hummingbird
  + .target("BotBridge", deps: [DigestCore, TDLibAdapter, Hummingbird])
  + App.dependencies += "BotBridge"

Sources/App/main.swift
  + новый mode: `tg-client service`
  + service mode: после auth → запускаем BotBridgeServer + ждём навсегда
  + oneshot mode: текущее поведение остаётся (для отладки/cron)
```

### Что НЕ меняем

- `ChannelMessageSource` — переиспользуем как есть
- `TDLibClient` — переиспользуем как есть
- `URLSessionHTTPClient` — переиспользуем для VK API вызовов (но возможно понадобится небольшая правка timeout — VK API не отвечает дольше 10 сек обычно)
- `OpenAISummaryGenerator` — пока не трогаем (raw mode без AI)

---

## 🔌 Контракт VK Callback API

### Входящий запрос (от VK к нам)

`POST https://cashflow-game.ru/vkWebHook` с JSON body:

```json
{
  "type": "message_new",
  "object": {
    "message": {
      "from_id": 12345678,
      "peer_id": 12345678,
      "text": "/digest",
      "id": 42,
      "date": 1730000000
    }
  },
  "group_id": 999999,
  "secret": "<наш_секрет_из_VK_settings>"
}
```

### Типы событий, которые обрабатываем

| `type` | Что делаем | Ответ |
|---|---|---|
| `confirmation` | Возвращаем подтверждающую строку | строка из VK settings |
| `message_new` | Парсим, валидируем, кладём в очередь, отвечаем сразу | `"ok"` |
| `message_edit` | Игнорируем (защита от трюка с редактированием) | `"ok"` |
| `message_reply` | Игнорируем | `"ok"` |
| остальные | Игнорируем | `"ok"` |

### Правила ответа

- VK ждёт ответ ≤ 10 сек, иначе ретраит. Поэтому **`message_new` обрабатываем асинхронно** в Task: моментально возвращаем `"ok"`, fetch + send идут в фоне.
- Тело ответа должно быть **plain text** (не JSON), для confirmation — строка кода, для остальных — `"ok"`.
- Если упали при обработке — **не возвращаем 5xx**, иначе VK ретраит. Логируем и шлём alert.

### Исходящий запрос (от нас к VK)

`GET https://api.vk.com/method/messages.send`

```
?access_token=<VK_BOT_TOKEN>
&v=5.199
&peer_id=<from_id юзера>
&message=<URL-encoded текст ≤ 4096 chars>
&random_id=<уникальный int64, дедупликация>
```

Лимиты:
- 4096 символов на одно сообщение
- ~20 сообщений/сек на сообщество (для нас не проблема — личное использование)
- `random_id` обязателен, иначе VK задедуплицирует одинаковые сообщения

---

## 🔒 Безопасность

### Слой 1: VK secret
- В настройках VK Callback API задаём `secret` (любая случайная строка)
- VK кладёт его в каждый POST
- Мы валидируем — если не совпадает с `VK_CALLBACK_SECRET` env → возвращаем 200 `"ok"` (не 403, чтобы не палиться) и логируем как warn

### Слой 2: Whitelist `from_id`
- `VK_BOT_OWNER_IDS` env, comma-separated VK user IDs
- В `message_new` проверяем `object.message.from_id ∈ whitelist`
- Если не в whitelist → молча игнорируем, отвечаем `"ok"`, логируем info с `from_id`

### Слой 3: Audit log
- Каждый входящий webhook логируется (level info): `from_id, type, command, decision (allow/deny)`
- Каждая отправка ответа логируется: `peer_id, chunks_count, total_chars`
- Каждая ошибка логируется (level error) с context

### Слой 4: Concurrent execution mutex
- `CommandProcessor` — actor, держит флаг `isProcessing`
- Если пришла команда пока обрабатывается предыдущая → отвечаем юзеру "Уже обрабатываю предыдущую команду, подожди"
- Защищает от двойного `fetchUnreadMessages` → race condition в TDLib

### Слой 5: Сообщество приватное
- Рекомендация юзеру: сделать VK сообщество **приватным/закрытым**, единственный участник — он сам
- Тогда даже если whitelist прокололся — никто чужой не сможет писать

### Что НЕ закрываем (и почему)
- DDoS на endpoint — за nginx, можно добавить rate limit там, но для personal use overkill
- Угон VK аккаунта владельца — out of scope, решается на уровне VK (2FA)
- MITM между VK и нами — закрывается HTTPS

---

## 🚪 Изменения в main.swift

### Сейчас (oneshot)

```swift
@main
struct TGClient {
    static func main() async {
        // env, logger, TDLib auth, fetchUnreadMessages, OpenAI digest, exit
    }
}
```

### Станет

```swift
@main
struct TGClient {
    static func main() async {
        // 1. env + logger
        // 2. TDLib auth (одинаково для обоих режимов)
        // 3. mode = CommandLine.arguments.dropFirst().first ?? "oneshot"
        switch mode {
        case "oneshot":
            // текущая логика (для cron/отладки)
        case "service":
            // запускаем BotBridgeServer.run()
            // ждём навсегда (TDLib подписка + Hummingbird)
        }
    }
}
```

**Обратная совместимость:** `swift run tg-client` без аргументов = `oneshot` (как сейчас). `swift run tg-client service` = новый режим.

---

## 🚀 Deployment

### nginx

Добавляем location в существующий `/etc/nginx/sites-enabled/cashflow-game.ru`:

```nginx
server {
    server_name cashflow-game.ru;
    listen 443 ssl;
    # ... существующие ssl_certificate, etc.

    location /telegramWebHook {
        # существующее, не трогаем
        proxy_pass http://127.0.0.1:8080;
    }

    # НОВОЕ:
    location /vkWebHook {
        proxy_pass http://127.0.0.1:8082;
        proxy_pass_header Server;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_connect_timeout 3s;
        proxy_read_timeout 15s;  # чуть больше, fetch может занять время
    }
}
```

После добавления: `nginx -t && systemctl reload nginx`.

### systemd

Новый файл `/etc/systemd/system/tg-client.service`:

```ini
[Unit]
Description=TG Client (VK bridge)
Requires=network.target
After=network.target

[Service]
Type=simple
User=root
Group=root
Restart=always
RestartSec=3
WorkingDirectory=/opt/tg-client
EnvironmentFile=/etc/tg-client.env
ExecStart=/opt/tg-client/tg-client service
StandardOutput=syslog
StandardError=syslog
SyslogIdentifier=tg-client

[Install]
WantedBy=multi-user.target
```

⚠️ **Отличие от cashflow.service**: секреты **только в EnvironmentFile** (mode 600), `Environment=` не используем. Учли урок из `cashflow.service` где токены в открытом systemd unit.

### Сборка → деплой

```bash
# на сервере (там где собираем)
git pull origin feature/vk-bot-bridge
./scripts/build-clean.sh
sudo mkdir -p /opt/tg-client
sudo cp .build/release/tg-client /opt/tg-client/
sudo cp -r ~/.tdlib /opt/tg-client/.tdlib  # переиспользуем существующую TDLib auth
# .env с секретами:
sudo tee /etc/tg-client.env > /dev/null <<EOF
TELEGRAM_API_ID=...
TELEGRAM_API_HASH=...
TDLIB_STATE_DIR=/opt/tg-client/.tdlib
VK_BOT_TOKEN=...
VK_BOT_GROUP_ID=...
VK_BOT_OWNER_IDS=12345678
VK_CALLBACK_SECRET=...
VK_API_VERSION=5.199
BOT_BRIDGE_PORT=8082
EOF
sudo chmod 600 /etc/tg-client.env
sudo systemctl daemon-reload
sudo systemctl enable --now tg-client
sudo systemctl status tg-client
```

⚠️ **Важно:** TDLib auth должен пройти **руками первый раз** (вводить телефон/код). После этого `~/.tdlib` содержит зашифрованную сессию, сервис стартует без интерактива. Возможно стоит сначала запустить `oneshot` режим для авторизации, потом переключить на service.

---

## 🌐 ENV переменные

| Var | Required | Default | Описание |
|---|---|---|---|
| `TELEGRAM_API_ID` | ✅ | — | TDLib (уже было) |
| `TELEGRAM_API_HASH` | ✅ | — | TDLib (уже было) |
| `TDLIB_STATE_DIR` | — | `~/.tdlib` | TDLib state (уже было) |
| `VK_BOT_TOKEN` | ✅ | — | Community access token со scope `messages` |
| `VK_BOT_GROUP_ID` | ✅ | — | Числовой ID сообщества |
| `VK_BOT_OWNER_IDS` | ✅ | — | Comma-separated VK user IDs кто может вызывать |
| `VK_CALLBACK_SECRET` | ✅ | — | Random string, такой же в настройках Callback API |
| `VK_CONFIRMATION_TOKEN` | ✅ | — | Строка для confirmation handshake (выдаёт VK при настройке) |
| `VK_API_VERSION` | — | `5.199` | API version для api.vk.com |
| `BOT_BRIDGE_PORT` | — | `8082` | Локальный порт для Hummingbird (8080 занят cashflow) |
| `OPENAI_API_KEY` | — | — | Не используется в этом RFC, оставляем для будущего AI |

---

## 🤔 Открытые вопросы

### 1. Как авторизовать TDLib в первый раз на сервисе?

**Проблема:** Service mode не интерактивный, а TDLib требует ввод телефона/кода при первом запуске.

**Варианты:**
- (a) Перед первым `systemctl start` запустить руками `tg-client oneshot` под root, ввести код, потом переключиться на service
- (b) Сделать отдельный CLI subcommand `tg-client auth` для интерактивной авторизации
- (c) Скопировать `~/.tdlib` с уже авторизованной машины (десктопа)

**Рекомендация:** (a) — проще всего, разовая операция.

### 2. Какие команды поддерживаем в первой итерации?

**Варианты:**
- (a) Любое сообщение от owner = `/digest` (минимум кода)
- (b) Только `/digest` (явная команда)
- (c) `/digest`, `/help`, `/ping`, `/status` (расширенный набор)

**Рекомендация:** (b) для явности. `/help` и `/ping` дёшево добавить заодно.

### 3. Что делать если запрос пришёл во время обработки предыдущего?

**Варианты:**
- (a) Очередь (выполнить после)
- (b) Отказать ("Уже обрабатываю, подожди")
- (c) Игнорировать (отвечать `"ok"`, не делать ничего)

**Рекомендация:** (b) с явным ответом юзеру. Для personal use очередь не нужна.

### 4. Нужен ли OneShot режим вообще после релиза service?

**Текущая логика:** `oneshot` = main.swift делает всё за один проход и выходит.

**Опции:**
- Оставить для cron (если когда-то понадобится scheduled)
- Удалить, оставить только service

**Рекомендация:** Оставить, помечен как "debug only". Удалить позже если не используется.

### 5. Health check endpoint?

VK не требует, но для мониторинга/алертов было бы полезно `GET /health` → `200 OK + "tdlib: connected, last_fetch: ..."`. Реализовать сразу или отложить?

**Рекомендация:** Сразу — это 10 строк кода, и сильно облегчает дебаг.

### 6. Версия Hummingbird

Hummingbird 2.x — стабильный, актуальный. Привязываемся к `from: "2.0.0"` или фиксируем минор `from: "2.6.0"`?

**Рекомендация:** `from: "2.0.0"`, как принято в Swift экосистеме.

---

## 🚧 Что откладываем

- **AI саммари в VK ответе** — после того как сырой режим заработает, можно будет добавить флаг `/digest --ai`
- **mark-as-read** — это v0.4.0, отдельная задача
- **Длинные TDD циклы** — сейчас просто аккуратный код + smoke test после деплоя. К полноценному outside-in вернёмся отдельной задачей
- **Long Poll fallback** — если webhook когда-нибудь начнёт лагать
- **Метрики/Prometheus** — позже, когда станет интересно
- **Multi-user (несколько хозяев VK)** — whitelist уже multi, но UX (per-user state) откладываем

---

## 📚 Ссылки

- [ARCHITECTURE.md](ARCHITECTURE.md) — принципы проектирования, чеклист зависимостей
- [MVP.md](MVP.md) — общий scope MVP
- [DEPLOY.md](DEPLOY.md) — текущая практика деплоя
- VK docs: https://dev.vk.com/ru/api/bots/getting-started
- VK Callback API: https://dev.vk.com/ru/api/callback/getting-started
- Hummingbird: https://github.com/hummingbird-project/hummingbird
- VK secret/confirmation: https://dev.vk.com/ru/api/community-events/json-schema
