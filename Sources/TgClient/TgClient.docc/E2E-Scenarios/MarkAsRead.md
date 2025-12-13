# Mark As Read

Отметка сообщений как прочитанных в Telegram после успешной отправки дайджеста пользователю.

## User Story

Как пользователь, я хочу чтобы сообщения автоматически отмечались как прочитанные **в Telegram клиенте** после получения дайджеста, чтобы:
- Не видеть эти сообщения повторно в следующем дайджесте
- **Видеть снятую галку непрочитанных в основном Telegram клиенте** (unreadCount = 0)

**Ожидаемое поведение:**
- Успешный сценарий: N чатов помечаются как прочитанные в Telegram (галка снимается)
- Partial failure: Если 1 чат failed → остальные продолжаем помечать (не блокируем работу)
- **Помечаем даже unsupported контент:** Если в чате были фото/видео (игнорируемые в v0.4.0) → всё равно помечаем весь чат как прочитанный

## Официальная документация

- [TDLib viewMessages](https://core.telegram.org/tdlib/docs/classtd_1_1td__api_1_1view_messages.html) — отметка сообщений как прочитанных

## Предусловия

- ✅ Дайджест **успешно отправлен** через бота пользователю
- ✅ Есть список чатов для отметки (chatId → [messageId])

> **Важно:** Помечаем ТОЛЬКО после успешной отправки дайджеста. Если отправка failed → НЕ помечаем (пользователь не получил информацию).

## Шаги

1. **Отметка N чатов параллельно**
   - **API:** TDLib `viewMessages(chatId, messageIds, forceRead: true)`
   - **Параллелизм:** Ограничен `maxParallelRequests = 20` (консервативный лимит для TDLib)
   - **Timeout:** 2 секунды для каждого `viewMessages` запроса
   - **Результат:** Dictionary [chatId: Result] с успехом/ошибкой для каждого чата

2. **Обработка partial failure**
   - **Логика:** Если 1 чат failed → логируем ошибку, продолжаем с остальными
   - **Не блокируем:** Даже если некоторые чаты не удалось пометить → не ошибка

3. **Синхронизация с Telegram**
   - **TDLib:** Автоматически синхронизирует состояние с Telegram сервером
   - **Результат:** В основном Telegram клиенте (мобильный/desktop) галка непрочитанных снимается

## Как проверить сценарий

**Запуск E2E теста:**

1. Убедитесь что есть непрочитанные сообщения в каналах
2. Откройте файл `Tests/TgClientE2ETests/MarkAsReadE2ETests.swift`
3. Найдите строку `@Test("E2E: Mark messages as read", .disabled())`
4. Уберите `.disabled()` → `@Test("E2E: Mark messages as read")`
5. Запустите тест:
   ```bash
   swift test --filter MarkAsReadE2ETests
   ```

**Ожидаемые логи:**
```
✅ fetchUnreadMessages() completed
   Channels with unread: N

✅ Marking messages as read...
✅ Chat marked as read (API test passed)
   Unread chats before: N
   Unread chats after: 0

⚠️  MANUAL UI VERIFICATION REQUIRED:
   Проверьте что unread badge исчез в Telegram клиенте
```

**Важно:** После теста верните `.disabled()` обратно.

## Связанные тесты

**E2E Сценарий:**
- <doc:MarkAsReadE2ETests> — полный сценарий (fetch → mark → verify UI)

**Component Tests:**
- <doc:MarkAsReadFlowTests> — 4 edge cases (happy path, partial failure, empty, large batch)

**Unit Tests:**
- <doc:ViewMessagesRequestTests> — Codable encoding/decoding

## Известные ограничения (v0.4.0)

- ✅ Partial failure handling: 1 чат failed → остальные продолжаем
- ⚠️ Нет retry strategy: ошибка viewMessages → логируем, продолжаем с остальными
- ⚠️ Консервативный лимит параллелизма (20): TDLib rate limits не исследованы
- ⚠️ Помечаем ВСЕ чаты из дайджеста: даже если были пропущенные фото/видео (unsupported content tracking → v0.6.0)

## Безопасность

**TDLib viewMessages:**
- Локальный API (не network request)
- Идемпотентен: повторный вызов для тех же сообщений безопасен
- `forceRead: true` → отметить даже если чат закрыт
- Синхронизация с Telegram: автоматически через TDLib

## Edge Cases

**Покрытые в Component тестах:**
- Empty input (0 чатов) → возвращаем пустой dictionary
- Single chat → помечаем 1 чат (без параллелизма)
- Large batch (100 чатов) → concurrency limit работает корректно
- Timeout для одного чата → не блокирует остальные
- Task cancellation → graceful shutdown
