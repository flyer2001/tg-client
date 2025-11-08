# Задачи проекта

## 🚀 Инструкции для новой сессии

**При запуске новой сессии:**
1. Прочитай топ-3 приоритета ниже
2. Предложи продолжить работу с фокусом на MVP
3. При необходимости (если задача неясна) — посмотри детали в [MVP.md](.claude/MVP.md)
4. **TDD обязателен**: пиши тесты ДО реализации (см. [TESTING.md](.claude/TESTING.md))

**Перед завершением сессии:**
- Обнови статус задач в этом файле
- **Актуализируй Swift-DocC документацию** (при добавлении новых модулей/компонентов)
- Запиши выполненные задачи в [CHANGELOG.md](.claude/CHANGELOG.md) (только prepend через bash)
- Если нужно — добавь идеи в [BACKLOG.md](.claude/BACKLOG.md)

---

> 🎯 **MVP (цели и scope):** [MVP.md](.claude/MVP.md) — читать по требованию (большой файл)
> 💡 **Будущие фичи:** [BACKLOG.md](.claude/BACKLOG.md) — бэклог для версий после MVP
> 📝 **История изменений:** [CHANGELOG.md](.claude/CHANGELOG.md) — логи завершенных сессий, читать только по требованию (большой файл)
> 📋 **Последнее обновление:** 2025-11-08

---

## 🎯 Следующая сессия (топ-3 приоритета)

**Контекст предыдущей сессии (2025-11-08):**
- ✅ **Scaffold завершён:** DigestCore target создан с базовой структурой
- ✅ **RED фаза выполнена:** E2E и Component тесты компилируются (с fatalError)
- ✅ **Декомпозиция по SRP:** MessageSourceProtocol, SourceMessage, ChannelMessageSource (stub), ChannelCache (stub)
- ✅ **Добавлена задача TD-4:** Автогенерация DoCC для внутренних моделей и компонентных тестов
- **Следующий шаг:** Unit-тесты для ChannelCache (задача 1.5) → RED фаза (создание тестов)

**Приоритеты:**

1. **[MVP-1.6] ChannelMessageSource (loadChats + updates)** 🔥 - GREEN фаза началась (~12-14 часов, 2-3 сессии)
   - Начать с задачи 1.5: Unit-тесты для ChannelCache (RED → GREEN)
   - Затем задачи 1.6-1.11 (см. детальный план ниже)
2. **[MVP-1.5] Типизация TDLib методов** - Расширение моделей (Chat, Message, loadChats, getChatHistory) по мере реализации MVP-1.6
3. **[MVP-2] SummaryGenerator** - AI-саммаризация через OpenAI (~3-4 часа)

> **См. детали:**
> - [MVP-1.6: ChannelMessageSource](#mvp-16-channelmessagesource-получение-непрочитанных-через-loadchats--updates-приоритет) — детальный план с декомпозицией
> - [TESTING.md](.claude/TESTING.md#декомпозиция-при-обнаружении-сложности) — процесс декомпозиции
> - [ARCHITECTURE.md](.claude/ARCHITECTURE.md#single-responsibility-principle-srp) — паттерн Coordinator + Workers

---

## 📊 High Priority (MVP Phase 1-2)

### MVP-1.5. Типизация TDLib методов (🔥 В РАБОТЕ)

**Цель:** Создать типобезопасные модели для работы с чатами и сообщениями.

**Зачем:** Блокирует MVP-1 (ChannelMessageSource) - нужны методы `getChats()`, `getChatHistory()`, `viewMessages()`.

**Статус:** Частично выполнено (getChats готов, остальные методы - в работе)

#### Задачи (по TDD: RED → GREEN → REFACTOR):

**1.1 Модель Chat** (~30 мин)
- [ ] **RED:** Тест декодирования `Chat` из JSON (с примером TDLib ответа + ссылка на docs)
- [ ] **GREEN:** Создать модель `Chat` (Sources/TDLibAdapter/TDLibCodableModels/Responses/)
- [ ] **REFACTOR:** Добавить Sendable, Equatable, документацию
- [ ] Поля: id, type (enum ChatType), title, lastReadInboxMessageId, unreadCount

**1.2 Enum ChatType** ✅ (~15 мин) **[ЗАВЕРШЕНО 2025-01-08]**
- [x] **RED:** Тест декодирования всех типов чатов
- [x] **GREEN:** Создать `ChatType` enum (private, supergroup, channel, secret, basic)
- [x] **REFACTOR:** Документация для каждого типа
- [x] **Файлы:** `Sources/TDLibAdapter/TDLibCodableModels/Responses/ChatType.swift`, `Tests/TgClientUnitTests/.../ChatTests.swift`
- [x] **Тесты:** 6 unit-тестов проходят ✔

**1.3 Модель Message** (~45 мин)
- [ ] **RED:** Тест декодирования `Message` из JSON
- [ ] **GREEN:** Создать модель `Message`
- [ ] **REFACTOR:** Добавить `MessageContent` (для MVP только text)
- [ ] Поля: id, chatId, date, content (MessageContent)

**1.4 Request: GetChatsRequest** ✅ (~20 мин) **[ЗАВЕРШЕНО 2025-11-07]**
- [x] **RED:** Тест кодирования `GetChatsRequest`
- [x] **GREEN:** Создать `GetChatsRequest` (Sources/TDLibAdapter/TDLibCodableModels/Requests/)
- [x] Параметры: chatList (enum: main/archive), limit
- [x] **RED:** Component Test для getChats() с MockTDLibClient
- [x] **GREEN:** Реализация TDLibClient.getChats() + MockTDLibClient.getChats()
- [x] **REFACTOR:** Error handling documentation, ARCHITECTURE.md (Error Handling Strategy)

**1.5 Request: GetChatHistoryRequest** (~20 мин)
- [ ] **RED:** Тест кодирования `GetChatHistoryRequest`
- [ ] **GREEN:** Создать `GetChatHistoryRequest`
- [ ] Параметры: chatId, fromMessageId, offset, limit

**1.6 Request: ViewMessagesRequest** (~20 мин)
- [ ] **RED:** Тест кодирования `ViewMessagesRequest`
- [ ] **GREEN:** Создать `ViewMessagesRequest`
- [ ] Параметры: chatId, messageIds, forceRead

**1.7 Response модели** ✅ (~30 мин) **[ЧАСТИЧНО ЗАВЕРШЕНО 2025-11-07]**
- [x] **RED:** Тест декодирования `ChatsResponse` (список chatIds)
- [x] **GREEN:** Создать `ChatsResponse`
- [ ] **RED:** Тест декодирования `MessagesResponse` (список Message)
- [ ] **GREEN:** Создать `MessagesResponse`

**1.8 Проверка** ✅ (~15 мин) **[ЗАВЕРШЕНО 2025-11-07]**
- [x] Проверить сборку: `swift build && swift test` (50 тестов проходят)
- [x] E2E тест: получено 100 чатов через реальный TDLib
- [x] Обновить DoCC документацию (E2E сценарий FetchUnreadMessages)
- [x] **Исправлена генерация DoCC:** glob → find, автогенерация в CI, .gitignore для .md
- [x] **Добавлен шаг валидации документации в TESTING.md** (шаг 10 в Outside-In TDD)

**Оценка времени:** ~2.5-3 часа

**Зависимости:** Нет (базовая инфраструктура уже есть)

**Разблокирует:** MVP-1.6 (ChannelMessageSource с декомпозицией)

---

### MVP-1.6. ChannelMessageSource: Получение непрочитанных через loadChats + updates (🔥 ПРИОРИТЕТ)

**Цель:** Реализовать получение непрочитанных сообщений из каналов через `loadChats` + updates механизм TDLib с применением декомпозиции по SRP.

**Архитектурное решение:**
- Отдельный `MessageSourceProtocol` (НЕ в TDLibClient)
- Декомпозиция на подкомпоненты: `ChannelCache`, `UpdatesHandler`, `MessageFetcher`
- Coordinator pattern: `ChannelMessageSource` координирует Workers
- Dependency Injection: зависимости через `init`

**Статус:** В работе - RED фаза завершена (E2E + Component тесты созданы, не компилируются)

**Контекст для следующей сессии (2025-01-08):**
- E2E и Component тесты написаны (RED - не компилируются, ждут реализации)
- Удалён устаревший GetChatsTests (component test на getChats)
- TESTING.md усилён: запрет на преждевременное создание Mock API
- Следующий шаг: декомпозиция на подкомпоненты (ChannelCache, UpdatesHandler, MessageFetcher) с Unit тестами

#### Задачи (по Outside-In TDD с декомпозицией):

**1.1 Обновление документации** (~20 мин) ✅
- [x] Обновить `FetchUnreadMessages.md` — упростить шаги, убрать технические детали
- [x] Добавить ссылку на E2E тест в `FetchUnreadMessages.md`
- [x] Обновить `TESTING.md` — добавить раздел "Декомпозиция при обнаружении сложности"
- [x] Обновить `ARCHITECTURE.md` — добавить раздел "Single Responsibility Principle (SRP)"

**1.2 E2E сценарий (тест)** ✅ (~30 мин) **[ЗАВЕРШЕНО 2025-01-08]**
- [x] **RED:** Создать `Tests/TgClientE2ETests/FetchUnreadMessagesScenarioTests.swift`
- [x] Тест: подключение → получение непрочитанных → проверка структуры
- [x] Использовать реальный TDLib клиент (упрощённая версия - фокус на ChannelMessageSource)
- [x] Тест НЕ КОМПИЛИРУЕТСЯ (нет ChannelMessageSource) ✔ RED достигнут
- [x] Удалён placeholder test `E2ETestsPlaceholder.swift`

**1.3 Component Test** ✅ (~30 мин) **[ЗАВЕРШЕНО 2025-01-08]**
- [x] **RED:** Создать `Tests/TgClientComponentTests/DigestCore/ChannelMessageSourceTests.swift`
- [x] Тест вызывает `messageSource.fetchUnreadMessages()` (фокус на интеграции, НЕ на внутренних шагах)
- [x] Тест НЕ КОМПИЛИРУЕТСЯ (нет ChannelMessageSource) ✔ RED достигнут
- [x] Документация TDLib методов: loadChats, getChat, getChatHistory с примерами JSON
- [x] **ВАЖНО:** Следование TDD - НЕ придумывать Mock API раньше Real (усилены инструкции в TESTING.md)
- [ ] Документировать найденные требования в комментариях теста:
  - loadChats loop (pagination)
  - updates handler (фоновый процесс)
  - ChannelCache (in-memory)
  - Фильтрация по type=channel + unreadCount>0
  - Получение сообщений из каналов

**1.4 Декомпозиция (архитектурное решение)** ✅ (~30 мин) **[ЗАВЕРШЕНО 2025-11-08]**
- [x] Выделить подкомпоненты по зонам ответственности:
  - `ChannelCache` (actor) — кэширование списка каналов
  - `UpdatesHandler` — обработка TDLib updates (TODO: следующая сессия)
  - `MessageFetcher` — получение сообщений из каналов (TODO: следующая сессия)
  - `ChannelMessageSource` — координатор
- [x] Создать пустые файлы (scaffold):
  - `Sources/DigestCore/Cache/ChannelCache.swift` ✅
  - `Sources/DigestCore/Sources/ChannelMessageSource.swift` ✅
  - `Sources/DigestCore/Models/SourceMessage.swift` ✅
  - `Sources/DigestCore/Protocols/MessageSourceProtocol.swift` ✅
  - `Sources/DigestCore/Updates/UpdatesHandler.swift` (TODO: следующая сессия)
  - `Sources/DigestCore/Fetchers/MessageFetcher.swift` (TODO: следующая сессия)
- [x] Добавить DigestCore target в Package.swift
- [x] Обновить зависимости тестов (TgClientComponentTests, TgClientE2ETests)
- [x] Проверить компиляцию: `swift build` успешно ✅
- [ ] Обновить `ARCHITECTURE.md` — добавить диаграмму компонентов (TODO: после GREEN фазы)

**1.5 Unit Tests для ChannelCache** (~1.5 часа)
- [ ] **RED:** `Tests/TgClientUnitTests/DigestCore/ChannelCacheTests.swift`
- [ ] Тесты:
  - `add(_:Chat)` — добавление канала (игнорирует non-channels)
  - `updateUnreadCount(chatId:count:)` — обновление счётчика
  - `getUnreadChannels()` — получение списка с unreadCount > 0
  - `remove(chatId:)` — удаление канала (если архивирован)
  - Edge cases: nil, пустой список, Int64.max
- [ ] **GREEN:** Реализация `ChannelCache`
- [ ] Actor isolation корректна (thread-safe)

**1.6 Unit Tests для UpdatesHandler** (~1.5 часа)
- [ ] **RED:** `Tests/TgClientUnitTests/DigestCore/UpdatesHandlerTests.swift`
- [ ] Тесты:
  - `start(tdlib:onUpdate:)` — запуск фонового процесса
  - `stop()` — остановка
  - Обработка `updateNewChat` → вызов callback
  - Обработка `updateChatReadInbox` → вызов callback
  - Edge cases: множественные starts, stop без start
- [ ] **GREEN:** Реализация `UpdatesHandler`
- [ ] Использовать `AsyncStream<Update>` от TDLibClient

**1.7 TDLib модели для loadChats/getChat** (~2 часа)
- [ ] **RED:** Unit-тесты для моделей:
  - `LoadChatsRequest` — параметры: chatList, limit
  - `LoadChatsResponse` — пустой Ok (все данные через updates)
  - `GetChatRequest` — параметр: chatId
  - `ChatResponse` — полная модель Chat (id, title, type, unreadCount, lastReadInboxMessageId, username)
  - `ChatType` — enum (private, basicGroup, supergroup, secret)
  - `Update` — enum для updates (updateNewChat, updateChatReadInbox)
- [ ] **GREEN:** Реализация моделей (Codable, Sendable, Equatable)
- [ ] **RED:** Component Test для TDLibClient:
  - `loadChats(chatList:limit:)` → Ok
  - `getChat(id:)` → Chat
  - `updates: AsyncStream<Update>` — stream для updates
- [ ] **GREEN:** Реализация в TDLibClient + MockTDLibClient
- [ ] Mock должен эмулировать updates sequence

**1.8 Unit Tests для MessageFetcher** (~1 час)
- [ ] **RED:** `Tests/TgClientUnitTests/DigestCore/MessageFetcherTests.swift`
- [ ] Тесты:
  - `fetch(from: [ChannelInfo])` → [SourceMessage]
  - Параллельные запросы через TaskGroup
  - Формирование ссылок (публичные/приватные каналы): `https://t.me/{username}/{messageId}`
  - Edge cases: пустой список, ошибка getChatHistory, канал без username
- [ ] **GREEN:** Реализация `MessageFetcher`
- [ ] Использовать MockTDLibClient

**1.9 Модели для getChatHistory** (~1.5 часа)
- [ ] **RED:** Unit-тесты:
  - `GetChatHistoryRequest` — параметры: chatId, fromMessageId, offset, limit
  - `MessagesResponse` — модель Messages (массив Message)
  - `Message` — модель сообщения (id, chatId, date, content)
  - `MessageContent` — enum (для MVP только textContent)
- [ ] **GREEN:** Реализация моделей
- [ ] **RED:** Component Test для TDLibClient.getChatHistory()
- [ ] **GREEN:** Реализация + Mock

**1.10 Protocol + Models для MessageSource** (~1 час)
- [ ] **RED:** Unit-тесты:
  - `SourceMessage` — модель для DigestCore (chatId, messageId, content, link, channelTitle)
  - `ChannelInfo` — модель для кэша (id, title, unreadCount, lastReadMessageId, username)
- [ ] **GREEN:** Реализация моделей (Codable, Equatable, Sendable)
- [ ] Создать `MessageSourceProtocol`:
  ```swift
  protocol MessageSourceProtocol {
      func fetchUnreadMessages() async throws -> [SourceMessage]
      func markAsRead(messages: [SourceMessage]) async throws
  }
  ```

**1.11 Модели для viewMessages (markAsRead)** (~1 час)
- [ ] **RED:** Unit-тесты:
  - `ViewMessagesRequest` — параметры: chatId, messageIds, forceRead
  - `ViewMessagesResponse` — Ok
- [ ] **GREEN:** Реализация моделей
- [ ] **RED:** Component Test для TDLibClient.viewMessages()
- [ ] **GREEN:** Реализация + Mock

**1.12 Integration: ChannelMessageSource** (~2 часа)
- [ ] **GREEN:** Реализация `ChannelMessageSource`
- [ ] Dependency Injection (cache, updatesHandler, messageFetcher, tdlib через init)
- [ ] Инициализация:
  - Запуск loadChats loop (пока не вернёт 404)
  - Запуск UpdatesHandler
  - Обработка updates → обновление cache
  - Флаг `isInitialized` для ожидания готовности
- [ ] `fetchUnreadMessages()`:
  - Ждать инициализации (while !isInitialized)
  - Получить непрочитанные из cache
  - Делегировать MessageFetcher
- [ ] `markAsRead(messages:)`:
  - Группировка по chatId
  - Вызов viewMessages для каждого чата
  - Error handling (логировать, но не прерывать)
- [ ] Component Test GREEN (с MockTDLibClient + реальные Workers)

**1.13 E2E validation** (~30 мин)
- [ ] Запустить E2E тест на реальном TDLib
- [ ] Проверить:
  - Получение всех каналов (не только 100)
  - Корректная фильтрация (только каналы с unreadCount > 0)
  - Корректное получение сообщений
  - Формирование ссылок (публичные/приватные)
- [ ] Логировать результаты для ручной проверки

**1.14 Refactor + Documentation** (~1 час)
- [ ] Refactor: edge cases, error handling, логирование
- [ ] Добавить DoCC комментарии для публичных API
- [ ] Запустить `./scripts/generate-docc-from-tests.sh`
- [ ] Проверить создание Component Test документации
- [ ] Обновить ARCHITECTURE.md — финальная диаграмма компонентов

**Оценка времени:** ~13-15 часов (разбить на 2-3 сессии)

**Зависимости:** MVP-1.5 (частично — Chat модель нужно расширить)

**Разблокирует:** MVP-2 (SummaryGenerator будет использовать SourceMessage модель)

**Критичные моменты:**
- ⚠️ AsyncStream для updates — может быть сложность в TDLibClient (нужна новая архитектура receive loop)
- ⚠️ loadChats pagination — нужна проверка на 404 (все чаты загружены)
- ⚠️ Thread-safety для ChannelCache (actor isolation)
- ⚠️ Graceful shutdown UpdatesHandler при ошибках
- ⚠️ Инициализация может занимать 10-30 сек (первый запуск) — нужен timeout

---

### MVP-2. SummaryGenerator (OpenAI Integration)

**Цель:** Генерация AI-саммари из списка сообщений.

**Архитектура:**
```swift
protocol SummaryGeneratorProtocol {
    func generateSummary(messages: [SourceMessage], maxLength: Int) async throws -> DigestSummary
}

class OpenAISummaryGenerator: SummaryGeneratorProtocol {
    // HTTP client для OpenAI API
}
```

#### Задачи:

**2.1 OpenAI HTTP Client** (~1.5 часа)
- [ ] Создать `OpenAIClient` (без зависимостей, прямые HTTP calls)
- [ ] Метод `sendChatCompletion(messages:, model:)` → `ChatCompletionResponse`
- [ ] Обработка ошибок (timeout, rate limit, 5xx)
- [ ] Retry логика (exponential backoff)
- [ ] Unit-тесты с моками URLSession

**2.2 Промпт для саммаризации** (~1 час)
- [ ] Разработать prompt template для дайджестов
- [ ] Формат: "Краткое резюме (2-3 предложения) + группировка по каналам"
- [ ] Инструкции для AI: Telegram Markdown, лимит 4096 символов
- [ ] Тестирование промпта с реальными сообщениями

**2.3 Генерация DigestSummary** (~1 час)
- [ ] Модель `DigestSummary` (summary, channelSummaries, totalMessages, period)
- [ ] Модель `ChannelSummary` (chatTitle, messageCount, summary, messageLinks)
- [ ] Парсинг ответа OpenAI → структурированный дайджест
- [ ] Unit-тесты

**2.4 Environment configuration** (~30 мин)
- [ ] Чтение `OPENAI_API_KEY` из env
- [ ] Выбор модели: `OPENAI_MODEL` (gpt-4-turbo / gpt-3.5-turbo)
- [ ] Timeout настройка: `OPENAI_TIMEOUT` (default 30s)

**Оценка времени:** ~3-4 часа

**Зависимости:** MVP-1 (SourceMessage модель)

---

### MVP-3. BotNotifier (Telegram Bot API)

**Цель:** Отправка дайджестов и алертов через Telegram бота.

**Архитектура:**
```swift
protocol BotNotifierProtocol {
    func send(summary: DigestSummary, chatId: Int64) async throws
    func sendAlert(error: Error, chatId: Int64) async throws
}

class TelegramBotNotifier: BotNotifierProtocol {
    // HTTP client для Telegram Bot API
}
```

#### Задачи:

**3.1 Telegram Bot HTTP Client** (~1 час)
- [ ] Создать `TelegramBotClient` (прямые HTTP calls)
- [ ] Метод `sendMessage(chatId:, text:, parseMode:)` → `Message`
- [ ] Поддержка Telegram MarkdownV2
- [ ] Обработка ошибок (4xx, 5xx)
- [ ] Unit-тесты с моками

**3.2 Форматирование дайджеста** (~1 час)
- [ ] Конвертация `DigestSummary` → Telegram Markdown
- [ ] Форматирование: жирный шрифт для заголовков, ссылки
- [ ] Экранирование спецсимволов MarkdownV2
- [ ] Unit-тесты

**3.3 Отправка алертов** (~30 мин)
- [ ] Метод `sendAlert(error:, chatId:)`
- [ ] Разные типы алертов: Auth error, AI error, Bot error
- [ ] Emoji для визуального разделения
- [ ] Unit-тесты

**3.4 Environment configuration** (~15 мин)
- [ ] Чтение `TELEGRAM_BOT_TOKEN` из env
- [ ] Чтение `TELEGRAM_BOT_CHAT_ID`
- [ ] Чтение `DIGEST_ALERT_CHAT_ID` (default = CHAT_ID)

**Оценка времени:** ~2.5-3 часа

**Зависимости:** MVP-2 (DigestSummary модель)

---

### MVP-4. StateManager (Persistence)

**Цель:** Хранение состояния последнего запуска.

#### Задачи:

**4.1 FileBasedStateManager** (~2 часа)
- [ ] Протокол `StateManagerProtocol`
- [ ] Реализация с JSON файлом (`~/.tdlib/digest_state.json`)
- [ ] Модель `DigestState` (lastSuccessfulRun, lastMessageIdByChat)
- [ ] Методы: `loadState()`, `saveState()`, `updateLastRun()`
- [ ] Thread-safe операции (FileManager + locks)
- [ ] Unit-тесты

**4.2 Миграция старых состояний** (~30 мин)
- [ ] Обработка отсутствия файла (первый запуск)
- [ ] Обработка поврежденного JSON (fallback to default)
- [ ] Логирование загрузки/сохранения состояния

**Оценка времени:** ~2.5 часа

**Зависимости:** Нет

---

### MVP-5. DigestOrchestrator (Coordination)

**Цель:** Координация всех компонентов для генерации дайджеста.

#### Задачи:

**5.1 Базовая структура** (~1 час)
- [ ] Класс `DigestOrchestrator` с DI всех сервисов
- [ ] Метод `run(mode: .scheduled | .onDemand) async throws`
- [ ] Логирование каждого этапа (structured logging)
- [ ] Unit-тесты с моками

**5.2 Оркестрация потока** (~2 часа)
- [ ] Загрузка состояния (StateManager)
- [ ] Получение сообщений (ChannelMessageSource)
- [ ] Генерация саммари (SummaryGenerator)
- [ ] Отправка через бота (BotNotifier)
- [ ] Отметка прочитанным (ChannelMessageSource)
- [ ] Сохранение состояния (StateManager)

**5.3 Error handling** (~1 час)
- [ ] Try-catch на каждом этапе
- [ ] Rollback: если отправка фейлится → НЕ помечать прочитанным
- [ ] Отправка алертов через BotNotifier при ошибках
- [ ] Partial success handling

**5.4 CLI интерфейс** (~1 час)
- [ ] `tg-digest scheduled` - scheduled режим
- [ ] `tg-digest on-demand` - on-demand режим
- [ ] Аргументы: `--dry-run` (не отправлять, только логи)
- [ ] Exit codes: 0 - успех, 1 - ошибка

**Оценка времени:** ~5 часов

**Зависимости:** Все предыдущие модули (MVP-1 to MVP-4)

---

## 📋 Normal Priority (MVP Phase 3-4)

### MVP-6. MonitoringService (Observability)

**Цель:** Мониторинг и алерты для продакшена.

#### Задачи:

**6.1 Structured Logging** (~1.5 часа)
- [ ] Интеграция swift-log
- [ ] JSON формат для логов
- [ ] Уровни: DEBUG, INFO, WARN, ERROR
- [ ] Контекст: timestamp, module, operation, duration
- [ ] Ротация логов (logrotate config)

**6.2 Healthcheck механизм** (~1 час)
- [ ] Heartbeat файл (`~/.tdlib/digest_heartbeat.txt`)
- [ ] Обновление после каждого успешного запуска
- [ ] Скрипт `/usr/local/bin/digest-healthcheck.sh`
- [ ] Cron задача для healthcheck (каждые 5 минут)
- [ ] Алерт если heartbeat старше 3 часов

**6.3 Telegram Self-Monitoring** (~30 мин)
- [ ] Алерт при старте приложения
- [ ] Алерт при успешном завершении
- [ ] Алерт при ошибках
- [ ] Daily summary

**Оценка времени:** ~3 часа

**Зависимости:** BotNotifier (MVP-3)

---

### MVP-7. Deployment (Linux VPS)

**Цель:** Развертывание на продакшен сервере.

#### Задачи:

**7.1 systemd Service** (~1 час)
- [ ] Файл `tg-digest.service`
- [ ] Hardening: user isolation, sandboxing, resource limits
- [ ] Restart policy: on-failure с backoff
- [ ] Логирование в journald

**7.2 Cron Setup** (~30 мин)
- [ ] Cron задача для scheduled запусков (09:00, 18:00)
- [ ] Запуск через systemd
- [ ] Логирование cron запусков

**7.3 Environment Setup** (~30 мин)
- [ ] `.env` файл с credentials
- [ ] Шаблон `.env.example`
- [ ] Инструкции по безопасному хранению секретов
- [ ] systemd EnvironmentFile

**7.4 Log Management** (~1 час)
- [ ] logrotate конфигурация
- [ ] journald limits (max size, retention)
- [ ] Скрипты для фильтрации логов
- [ ] Инструкции для troubleshooting

**7.5 Обновление DEPLOY.md** (~30 мин)
- [ ] Раздел "Digest Service Setup"
- [ ] Инструкции по установке systemd service
- [ ] Настройка cron
- [ ] Мониторинг и healthcheck

**Оценка времени:** ~3.5 часа

**Зависимости:** DigestOrchestrator (MVP-5), MonitoringService (MVP-6)

---

### MVP-8. Testing & Documentation

**Цель:** Покрытие тестами и обновление документации.

#### Задачи:

**8.1 Testing Strategy** (~2 часа)
- [ ] Обновить TESTING.md с учетом MVP модулей
- [ ] Unit-тесты: 80% coverage для core логики
- [ ] Component-тесты: DigestOrchestrator с моками
- [ ] E2E тест: полный цикл на VPS (manual)
- [ ] CI: `swift test` в GitHub Actions

**8.2 Documentation Updates** (~2 часа)
- [ ] README.md: Quick Start для MVP
- [ ] DEPLOY.md: Полная инструкция деплоя
- [ ] TROUBLESHOOTING.md: Частые ошибки MVP
- [ ] ARCHITECTURE.md: Диаграммы новых модулей
- [ ] .env.example: Все переменные окружения

**Оценка времени:** ~4 часа

**Зависимости:** Все предыдущие модули

---

## 💡 Low Priority (Technical Debt)

### TD-1. EnvironmentService абстракция

**Цель:** Типобезопасное чтение credentials из env.

- [ ] Протокол `EnvironmentServiceProtocol`
- [ ] `ProcessInfoEnvironmentService` для macOS/Linux
- [ ] `AppConfiguration` struct для типобезопасной конфигурации
- [ ] Валидация обязательных переменных при старте
- [ ] Unit-тесты

**Приоритет:** Нужно для MVP-2 и MVP-3 (перед началом)

**Оценка времени:** ~1.5 часа

---

### TD-2. Рефакторинг параметров TDLib

**Цель:** Улучшить читаемость и maintainability.

- [ ] Создать `Sources/TDLibAdapter/TDLibParameters.swift`
- [ ] Static метод `buildParameters(from config: TDConfig) -> [String: Any]`
- [ ] Документация каждого параметра

**Приоритет:** Low (можно сделать параллельно с MVP-1)

**Оценка времени:** ~1 час

---

### TD-3. Улучшение request-response механизма

**Цель:** Использовать `@extra` механизм TDLib вместо polling.

- [ ] Изучить механизм `@extra` в TDLib
- [ ] Рассмотреть варианты: async continuation, `AsyncStream`
- [ ] Вынести в переиспользуемую функцию `sendRequest<T>()`

**Приоритет:** Medium (нужно для множества запросов)

**Оценка времени:** ~2-3 часа

---

## 🔗 Документация

**Основные документы:**
- [MVP.md](.claude/MVP.md) - цели и scope MVP
- [ARCHITECTURE.md](.claude/ARCHITECTURE.md) - архитектура проекта
- [DEVELOPMENT.md](.claude/DEVELOPMENT.md) - правила разработки
- [TESTING.md](.claude/TESTING.md) - стратегия тестирования
- [BACKLOG.md](.claude/BACKLOG.md) - бэклог для версий после MVP
- [CHANGELOG.md](.claude/CHANGELOG.md) - история изменений

**Инфраструктура:**
- [SETUP.md](.claude/SETUP.md) - настройка окружения
- [DEPLOY.md](.claude/DEPLOY.md) - деплой на Linux VPS
- [CREDENTIALS.md](.claude/CREDENTIALS.md) - управление секретами
- [TROUBLESHOOTING.md](.claude/TROUBLESHOOTING.md) - частые проблемы

---

**Последнее обновление:** 2025-11-08
**Архив завершенных задач:** См. [CHANGELOG.md](.claude/CHANGELOG.md) (2025-11-06 | Архивация завершенных задач)

---

## 📚 Technical Debt (Documentation)

### TD-4. Автогенерация DoCC для внутренних моделей и компонентных тестов

**Цель:** Расширить `./scripts/generate-docc-from-tests.sh` для автоматической генерации документации из тестов.

**Проблема:**
- Сейчас скрипт работает только для E2E сценариев
- Компонентные тесты не генерируют документацию (нет ссылок на упоминаемые Request/Response модели)
- Внутренние модели DigestCore (ChannelInfo, SourceMessage) не документируются автоматически

**Требования:**
1. **Компонентные тесты** → DoCC статьи:
   - Пример: `TgClientComponentTests/TDLibAdapter/GetChatsTests.swift` → `GetChatsComponent.md`
   - Автоматический парсинг упоминаний Request/Response моделей в комментариях
   - Генерация ссылок: `- Request: <doc:GetChatsRequest>`, `- Response: <doc:ChatsResponse>`

2. **Unit-тесты внутренних моделей** → DoCC статьи:
   - Пример: `TgClientUnitTests/DigestCore/ChannelCacheTests.swift` → `ChannelCacheUnit.md`
   - Парсинг использованных моделей: `ChannelInfo`, `SourceMessage`
   - Генерация ссылок на модели

3. **Обновить скрипт:**
   - Добавить обработку `Tests/TgClientComponentTests/` (рекурсивно)
   - Добавить обработку `Tests/TgClientUnitTests/` (для DigestCore моделей)
   - Regex для парсинга упоминаний моделей в комментариях

**Задачи:**
- [ ] Изучить текущий скрипт `generate-docc-from-tests.sh`
- [ ] Добавить функцию `generate_component_docs()` для компонентных тестов
- [ ] Добавить функцию `generate_unit_model_docs()` для внутренних моделей
- [ ] Обновить regex для парсинга упоминаний Request/Response (например, `GetChatsRequest`, `ChatsResponse`)
- [ ] Добавить автоматическую генерацию ссылок `<doc:ModelName>`
- [ ] Протестировать на существующих тестах (GetChatsTests, ChannelCacheTests)
- [ ] Обновить `.github/workflows` для автогенерации в CI

**Приоритет:** Medium (нужно после завершения MVP-1.6, перед финальной документацией)

**Оценка времени:** ~2-3 часа

**Зависимости:** Нет (можно делать параллельно)

