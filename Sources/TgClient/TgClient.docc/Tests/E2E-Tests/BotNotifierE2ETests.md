# E2E: Отправка дайджеста через Telegram бота

## Описание

E2E тест для сценария отправки дайджеста через Telegram бота.

**Сценарий:** <doc:BotNotifier>

**Предусловия:**
- Bot token получен через @BotFather (`/newbot`)
- Переменная окружения настроена:
- `TELEGRAM_BOT_TOKEN` — bot token из @BotFather (⚠️ секрет, только из env!)
- Chat ID: `566335622` (захардкожен в тесте, проверен через getUpdates)

**Как получить chat_id (если нужен другой):**
```bash
# 1. Отправь боту /start в Telegram
# 2. Получи updates:
curl https://api.telegram.org/bot<BOT_TOKEN>/getUpdates?offset=-1
# 3. Найди: "chat":{"id": 566335622}
```

**Тип теста:** E2E

**Исходный код:** [`Tests/TgClientE2ETests/BotNotifierE2ETests.swift`](https://github.com/flyer2001/tg-client/blob/main/Tests/TgClientE2ETests/BotNotifierE2ETests.swift)

## Тестовые сценарии

### Отправка дайджеста через реальный Telegram Bot API", .disabled("E2E: требует TELEGRAM_BOT_TOKEN, запускать вручную

E2E тест: полный pipeline с отправкой дайджеста в Telegram.

**Что тестируем:**
- Полный цикл: fetch → digest → **BotNotifier** → markAsRead
- Реальная отправка через Bot API (требует env vars)
- Корректность plain text форматирования

**ПРИМЕЧАНИЕ:** E2E тест disabled по умолчанию. Запускайте вручную для проверки с реальным ботом.

**Как запустить:**
1. Добавить в `.env`: `TELEGRAM_BOT_TOKEN=your_bot_token`
2. ⚠️ **ВАЖНО:** `.env` НЕ подтягивается автоматически! Нужен source:
```bash
source .env && swift test --filter sendDigestToTelegramBot
```
3. Проверить в Telegram: бот отправил сообщение

⚠️ Bot Token — секрет, ТОЛЬКО из env!

Chat ID (публичный, можно захардкодить для тестов)

Создаём TelegramBotNotifier с реальным HTTP клиентом

Отправляем тестовое сообщение

Act: отправляем через реальный Bot API

Assert: если не выбросило ошибку — успех

Пользователь должен увидеть сообщение в Telegram

---


## Topics

### Связанная документация

- <doc:TgClient>
