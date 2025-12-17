# Bot Notifier

Отправка дайджеста непрочитанных сообщений через Telegram бота.

## User Story

Как пользователь Telegram, я хочу получать краткие дайджесты непрочитанных сообщений из каналов прямо в личный чат с ботом, чтобы быстро узнавать о важных обновлениях без необходимости читать все сообщения вручную.

**Ожидаемое поведение:**
- Успешный сценарий: Бот отправляет plain text дайджест в чат пользователя, сообщения помечаются как прочитанные
- Дайджест >4096 chars: Fail-fast с ошибкой (пользователь скорректирует AI prompt для более короткого дайджеста)
- Ошибки сети (429, 5xx): Retry 3 раза с exponential backoff (1s, 2s, 4s)
- Ошибки конфигурации (400, 401, 404): Fail-fast с явным сообщением (баг в коде или неверные env vars)

## Официальная документация

- [Telegram Bot API: sendMessage](https://core.telegram.org/bots/api#sendmessage) — отправка сообщений через бота
- [Telegram Bot API: Getting Updates](https://core.telegram.org/bots/api#getupdates) — получение chat_id пользователя
- [@BotFather](https://t.me/botfather) — создание бота и получение токена

## Предусловия

- **Bot token:** Получен через @BotFather (`/newbot`)
- **Chat ID:** Получен через `/start` + `curl https://api.telegram.org/bot<TOKEN>/getUpdates | jq '.result[0].message.chat.id'`
- **Environment variables:**
  - `TELEGRAM_BOT_TOKEN` — bot token из @BotFather
  - `TELEGRAM_BOT_CHAT_ID` — chat_id пользователя (Int64)
  - `TELEGRAM_API_ID`, `TELEGRAM_API_HASH` — для TDLib (fetch сообщений)
  - `OPENAI_API_KEY` — для SummaryGenerator (дайджест)
- У пользователя есть подписки на Telegram каналы с непрочитанными сообщениями

## Шаги

1. **Fetch непрочитанных сообщений**
   - **Результат:** Список сообщений из каналов (через TDLib)
   - **Ошибки:** Ошибка TDLib → прерываем выполнение

2. **Генерация дайджеста**
   - **Результат:** Plain text дайджест (AI summary)
   - **Ошибки:** Ошибка OpenAI API → retry 3 раза, затем прерываем

3. **Отправка дайджеста через бота**
   - **Результат:** Дайджест отправлен в Telegram, message_id получен
   - **Ошибки:**
     - 429 rate limit → retry 3 раза (exponential backoff)
     - 5xx server error → retry 3 раза
     - 400 invalid request → fail-fast (баг в коде)
     - 401 invalid token → fail-fast (проверить `TELEGRAM_BOT_TOKEN`)
     - 404 chat not found → fail-fast (проверить `TELEGRAM_BOT_CHAT_ID`)
     - Дайджест >4096 chars → fail-fast (пользователь скорректирует prompt)

4. **Mark as read**
   - **Результат:** Сообщения помечены как прочитанные (ТОЛЬКО после успешной отправки дайджеста)
   - **Ошибки:** Ошибка TDLib → логируем, НЕ прерываем (дайджест уже отправлен)

## E2E тест

<doc:BotNotifierE2ETests>

## Компонентный тест

<doc:TelegramBotNotifierComponentTests>

## Ссылки

- **Spike research:** `.claude/archived/spike-telegram-bot-api-2025-12-15.md` — live эксперименты, реальные JSON
- **Architecture Design:** `.claude/archived/architecture-v0.5.0-botnotifier-2025-12-16.md` — 7 блоков, критичные решения
