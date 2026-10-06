# E2E: Управление через VK-сообщество (Long Poll)

## Описание

E2E тест для сценария управления Telegram-клиентом через VK-сообщество.

**User Story:** <doc:VKBridge>

**Что проверяется:**
- VK Bots Long Poll доставляет сообщение владельца в сервис (без webhook, домена и nginx)
- Команда `/test` проходит путь Long Poll → `CommandProcessor` → `messages.send`
- Остановка: отмена задачи цикла завершает `run()` (spike: отмена URLSession на Linux работает)

**Предусловия:**
- VK-сообщество: сообщения + «Возможности ботов» + Long Poll API (5.199, «Входящее сообщение»)
- Ключ сообщества с правами `manage` + `messages`
- Окружение: `VK_BOT_TOKEN`, `VK_BOT_GROUP_ID`, `VK_BOT_OWNER_IDS` (`set -a; source .env; set +a`)
- TDLib для `/test` не нужен (команда не обращается к Telegram)

**Тип теста:** E2E

**Исходный код:** [`Tests/TgClientE2ETests/VKBridgeE2ETests.swift`](https://github.com/flyer2001/tg-client/blob/main/Tests/TgClientE2ETests/VKBridgeE2ETests.swift)

## Тестовые сценарии

### E2E: /test через VK Long Poll → ответ владельцу", .disabled("E2E: реальное VK-сообщество, запускать вручную

E2E тест: владелец пишет `/test` в сообщество → получает ответ о статусе.

**Результат spike v0.5.0** (`spikes/vk-longpoll/README.md`): `wait=25` → ответ VK ~22 c,
`ts` строкой, `failed:2` на битом ключе, `Task.cancel()` прерывает запрос за 2 c.

**Сценарий:**
1. Запустить Long Poll на реальном сообществе
2. В течение 2 минут владелец пишет `/test` в сообщество
3. Сервис отвечает в тот же диалог
4. Проверить через `messages.getHistory`: последнее исходящее сообщение сообщества — отчёт `alive`
5. Отменить цикл → `run()` завершается

**Как запустить:** убрать `.disabled(...)`, затем
`set -a; source .env; set +a; swift test --filter VKBridgeE2ETests`



---


## Topics

### Связанная документация

- <doc:TgClient>
