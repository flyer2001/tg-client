# E2E: Отметка сообщений как прочитанных

## Описание

E2E тест для сценария отметки сообщений как прочитанных.

**User Story:** <doc:MarkAsRead>

**Цель spike:** Проверить реальное поведение TDLib `viewMessages` API:
- Request/Response JSON формат
- Идемпотентность (повторный вызов)
- Синхронизация unreadCount с Telegram
- Edge cases (несуществующий chatId/messageId, пустой массив)

**Предусловия:**
- **КРИТИЧНО:** Пользователь уже авторизован в TDLib (сохранённая сессия в ~/.tdlib/)
- Переменные окружения настроены (`TELEGRAM_API_ID`, `TELEGRAM_API_HASH`)
- Есть хотя бы один канал с непрочитанными сообщениями

**Тип теста:** E2E

**Исходный код:** [`Tests/TgClientE2ETests/MarkAsReadE2ETests.swift`](https://github.com/flyer2001/tg-client/blob/main/Tests/TgClientE2ETests/MarkAsReadE2ETests.swift)

## Тестовые сценарии

### mark Messages As Read_e2e

E2E тест: отметка сообщений как прочитанных через openChat → viewMessages → closeChat.

**Spike Test для v0.4.0:** Проверка требования TDLib — openChat перед viewMessages.
Источник: [TDLib Issue #1513](https://github.com/tdlib/td/issues/1513)

**Сценарий:**
1. Получить непрочитанные сообщения (fetchUnreadMessages)
2. Открыть чат (openChat)
3. Пометить сообщения прочитанными (viewMessages)
4. Закрыть чат (closeChat)
5. Проверить что чат исчез из непрочитанных (fetchUnreadMessages повторно)
6. **⚠️ КРИТИЧНО:** Manual UI verification в Telegram клиенте (badge должен исчезнуть!)

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
