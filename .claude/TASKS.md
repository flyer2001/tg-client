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
> 📋 **Последнее обновление:** 2025-11-06

---

## 🎯 Следующая сессия (топ-3 приоритета)

> ⚠️ **ПЕРЕД НАЧАЛОМ:** Переписать задачи MVP-1.5 и MVP-1 по методологии **Outside-In TDD** (см. [TESTING.md](.claude/TESTING.md#outside-in-tdd-для-tdlib-интеграции))
> - Добавить шаги: E2E сценарий → Component Test → Fixtures → Unit Tests → Models → Protocol → Real → Mock → GREEN → Refactor
> - Указать ссылки на TDLib docs в комментариях Component тестов
> - Создать структуру `Tests/Fixtures/TDLib/` для JSON примеров

1. **[MVP-1.5] Типизация TDLib методов** 🔥 - Chat, Message, GetChats, GetChatHistory, ViewMessages (~2-3 часа)
2. **[MVP-1] ChannelMessageSource** - Получение непрочитанных сообщений из каналов (~3-4 часа)
3. **[MVP-2] SummaryGenerator** - AI-саммаризация через OpenAI (~3-4 часа)

> **См. детали:**
> - [MVP-1: ChannelMessageSource](#mvp-1-channelmessagesource-tdlib-integration) — получение сообщений
> - [MVP.md — TDLib API](MVP.md#tdlib-api-работа-с-непрочитанными-сообщениями) — детали работы с TDLib

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

**1.2 Enum ChatType** (~15 мин)
- [ ] **RED:** Тест декодирования всех типов чатов
- [ ] **GREEN:** Создать `ChatType` enum (private, supergroup, channel, secret, basic)
- [ ] **REFACTOR:** Документация для каждого типа

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

**Оценка времени:** ~2.5-3 часа

**Зависимости:** Нет (базовая инфраструктура уже есть)

**Разблокирует:** MVP-1 (ChannelMessageSource)

---

### MVP-1. ChannelMessageSource (TDLib Integration)

**Цель:** Получение непрочитанных сообщений из Telegram каналов.

> **📖 Детали работы с TDLib API:** [MVP.md — TDLib API: Работа с непрочитанными сообщениями](.claude/MVP.md#tdlib-api-работа-с-непрочитанными-сообщениями)

**Архитектура:**
```swift
protocol MessageSourceProtocol {
    func fetchUnreadMessages(since: Date?) async throws -> [SourceMessage]
    func markAsRead(messages: [SourceMessage]) async throws
}

class ChannelMessageSource: MessageSourceProtocol {
    // Реализация для каналов
}
```

#### Задачи (по TDD):

**1.1 Протокол и модели DigestCore** (~1 час)
- [ ] **RED:** Тест инициализации `SourceMessage`
- [ ] **GREEN:** Создать `SourceMessage` (Sources/DigestCore/Models/)
- [ ] **REFACTOR:** Codable, Equatable, edge cases
- [ ] **RED:** Тест для `MessageSourceProtocol` (mock implementation)
- [ ] **GREEN:** Создать протокол `MessageSourceProtocol` (Sources/DigestCore/Protocols/)
- [ ] Создать stub `ChannelMessageSource` (Sources/DigestCore/Sources/)

**1.2 Получение списка каналов** (~1 час)
- [ ] **RED:** Component-тест `fetchUnreadChannels()` с MockTDLibClient
- [ ] **GREEN:** Реализовать получение чатов через `getChats(chatList: .main)`
- [ ] **GREEN:** Фильтрация: только каналы (тип `channel`)
- [ ] **GREEN:** Фильтрация: не в архиве (`chatList != .archive`)
- [ ] **GREEN:** Фильтрация: есть непрочитанные (`unreadCount > 0`)
- [ ] **REFACTOR:** Error handling, логирование
- [ ] Тесты на edge cases

**1.3 Извлечение сообщений из канала** (~1.5 часа)
- [ ] **RED:** Тест оптимизированного запроса (fromMessageId=0, limit=unreadCount)
- [ ] **GREEN:** `getChatHistory(chatId:, fromMessageId: 0, offset: 0, limit: unreadCount)`
- [ ] **GREEN:** Фильтр по `lastReadInboxMessageId`
- [ ] **GREEN:** Формирование ссылок: `https://t.me/<username>/<messageId>`
- [ ] **GREEN:** Обработка каналов без username
- [ ] **REFACTOR:** Конвертация `Message` → `SourceMessage`
- [ ] Тесты на edge cases

**1.4 Отметка прочитанным** (~30 мин)
- [ ] **RED:** Тест `markAsRead()` с MockTDLibClient
- [ ] **GREEN:** `viewMessages(chatId:, messageIds:, forceRead: true)`
- [ ] **GREEN:** Группировка по chatId
- [ ] Вызов ТОЛЬКО после успешной отправки дайджеста
- [ ] **REFACTOR:** Обработка ошибок
- [ ] Тесты на edge cases

**Оценка времени:** ~3-4 часа

**Зависимости:** MVP-1.5 (типизация TDLib)

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

**Последнее обновление:** 2025-11-06
**Архив завершенных задач:** См. [CHANGELOG.md](.claude/CHANGELOG.md) (2025-11-06 | Архивация завершенных задач)
