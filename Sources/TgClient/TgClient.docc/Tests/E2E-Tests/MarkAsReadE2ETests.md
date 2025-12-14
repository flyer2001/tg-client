# E2E: Отметка сообщений как прочитанных

## Описание

E2E тест для сценария отметки сообщений как прочитанных.

**User Story:** <doc:MarkAsRead>

**Что проверяется:**
- viewMessages API работает с `forceRead: true` БЕЗ openChat/closeChat
- Идемпотентность (повторный вызов безопасен)
- Синхронизация unreadCount с Telegram клиентом
- Чат исчезает из списка непрочитанных после markAsRead

**Предусловия:**
- **КРИТИЧНО:** Пользователь уже авторизован в TDLib (сохранённая сессия в ~/.tdlib/)
- Переменные окружения настроены (`TELEGRAM_API_ID`, `TELEGRAM_API_HASH`)
- Есть хотя бы один канал с непрочитанными сообщениями

**Тип теста:** E2E

**Исходный код:** [`Tests/TgClientE2ETests/MarkAsReadE2ETests.swift`](https://github.com/flyer2001/tg-client/blob/main/Tests/TgClientE2ETests/MarkAsReadE2ETests.swift)

## Тестовые сценарии

### mark Messages As Read_e2e

E2E тест: отметка сообщений как прочитанных через `viewMessages(forceRead: true)`.

**Результат spike research v0.4.0:** viewMessages работает **БЕЗ** openChat/closeChat!
Root cause: параметр `forceRead: true` работает для closed chats (bot-like use case).

**Сценарий:**
1. Получить непрочитанные сообщения (fetchUnreadMessages)
2. Пометить сообщения прочитанными (viewMessages с forceRead: true)
3. Проверить что чат исчез из непрочитанных (fetchUnreadMessages повторно)
4. **⚠️ КРИТИЧНО:** Manual UI verification в Telegram клиенте (badge должен исчезнуть!)

**Предусловия:**
- Пользователь авторизован в TDLib
- Есть хотя бы один канал с непрочитанными сообщениями

**Если нет непрочитанных:**
Тест пропускается с инструкцией создать отложенное сообщение в канале.

1. Инициализация TDLib + ChannelMessageSource

2. Получить непрочитанные сообщения ДО

3. Берём первый чат из непрочитанных

4. Помечаем прочитанным через viewMessages (forceRead=true)

Небольшая задержка для синхронизации TDLib state

5. Получить непрочитанные сообщения ПОСЛЕ

6. Проверяем что этого чата больше нет в непрочитанных

⚠️ КРИТИЧНО: Manual UI Verification

---


## Topics

### Связанная документация

- <doc:TgClient>
