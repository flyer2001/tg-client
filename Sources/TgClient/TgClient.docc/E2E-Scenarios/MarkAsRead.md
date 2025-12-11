# Mark As Read

Отметка сообщений как прочитанных в Telegram после успешной отправки дайджеста пользователю.

## User Story

Как пользователь, я хочу чтобы сообщения автоматически отмечались как прочитанные **в Telegram клиенте** после получения дайджеста, чтобы:
- Не видеть эти сообщения повторно в следующем дайджесте
- **Видеть снятую галку непрочитанных в основном Telegram клиенте** (unreadCount = 0)

**Ожидаемое поведение:**
- Успешный сценарий: N чатов помечаются как прочитанные в Telegram (галка снимается)
- Partial failure: Если 1 чат failed → остальные продолжаем помечать (не блокируем работу)
- CLI флаг: `--no-mark-as-read` → пропустить отметку (dry-run режим для тестирования)

## Официальная документация

- [TDLib viewMessages](https://core.telegram.org/tdlib/docs/classtd_1_1td__api_1_1view_messages.html) — отметка сообщений как прочитанных

## Предусловия

- ✅ Дайджест **успешно отправлен** через бота пользователю
- ✅ Есть список чатов для отметки (chatId → [messageId])

> **Важно:** Помечаем ТОЛЬКО после успешной отправки дайджеста. Если отправка failed → НЕ помечаем (пользователь не получил информацию).

## Шаги

1. **Проверка CLI флага**
   - Если `--no-mark-as-read` → пропустить отметку, вернуться
   - Иначе → продолжить

2. **Отметка N чатов параллельно**
   - **API:** TDLib `viewMessages(chatId, messageIds, forceRead: true)`
   - **Параллелизм:** Ограничен `maxParallelRequests = 20` (консервативный лимит для TDLib)
   - **Timeout:** 2 секунды для каждого `viewMessages` запроса
   - **Результат:** Dictionary [chatId: Result] с успехом/ошибкой для каждого чата

3. **Обработка partial failure**
   - **Логика:** Если 1 чат failed → логируем ошибку, продолжаем с остальными
   - **Не блокируем:** Даже если некоторые чаты не удалось пометить → не ошибка

4. **Синхронизация с Telegram**
   - **TDLib:** Автоматически синхронизирует состояние с Telegram сервером
   - **Результат:** В основном Telegram клиенте (мобильный/desktop) галка непрочитанных снимается

## Как проверить сценарий

**Ручной E2E тест:**

1. Подготовка:
   ```bash
   # Убедитесь что есть непрочитанные сообщения в каналах
   # Откройте основной Telegram клиент → видно N непрочитанных чатов
   ```

2. Запуск (с отметкой прочитанным):
   ```bash
   swift run tg-client                # markAsRead = true (default)
   ```

3. Проверка в Telegram:
   - Откройте основной Telegram клиент (мобильный/desktop)
   - **Ожидаемое:** Галка непрочитанных снята для чатов из дайджеста (unreadCount = 0)

4. Запуск (без отметки — dry-run):
   ```bash
   swift run tg-client --no-mark-as-read
   ```

5. Проверка в Telegram:
   - **Ожидаемое:** Галка непрочитанных НЕ снята (unreadCount > 0)

**Ожидаемые логи (с --mark-as-read):**
- `INFO: Marking 5 chats as read (maxParallelRequests: 20)`
- `DEBUG: Marking chat 12345 as read (10 messages)`
- `INFO: Mark-as-read completed: 5 success, 0 failed, 342 ms`

**Ожидаемые логи (с --no-mark-as-read):**
- `INFO: Skipping mark-as-read (disabled via CLI flag)`

**Component тест:**

<doc:MarkAsReadServiceTests>

**Unit тесты моделей:**

- ViewMessagesRequest — проверка Codable для TDLib Request

## Известные ограничения (v0.4.0)

- ✅ Partial failure handling: 1 чат failed → остальные продолжаем
- ✅ CLI флаг `--no-mark-as-read` для dry-run режима
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

## Тестирование concurrency

**TSan (Thread Sanitizer):**
```bash
swift test --sanitize=thread --filter MarkAsReadServiceTests
```

**Ожидаемый результат:** 0 data races
