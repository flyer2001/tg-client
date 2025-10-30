# Задачи проекта

## 🚀 Инструкции для новой сессии

**При запуске новой сессии:**
1. Прочитай топ-3 приоритета ниже
2. Предложи продолжить работу с фокусом на MVP
3. При необходимости (если задача неясна) — посмотри детали в [MVP.md](MVP.md)
4. **TDD обязателен**: пиши тесты ДО реализации (см. [TESTING.md](TESTING.md))

**Перед завершением сессии:**
- Обнови статус задач в этом файле
- Запиши выполненные задачи в [CHANGELOG.md](CHANGELOG.md) (только prepend через bash)
- Если нужно — добавь идеи в [IDEAS.md](IDEAS.md)

---

> 🎯 **MVP (цели и scope):** [MVP.md](MVP.md) — читать по требованию (большой файл)
> 💡 **Будущие фичи:** [IDEAS.md](IDEAS.md) — бэклог для версий после MVP
> 📝 **История изменений:** [CHANGELOG.md](CHANGELOG.md) — логи завершенных сессий
> 📋 **Последнее обновление:** 2025-10-30

---

## 🎯 Следующая сессия (топ-3 приоритета)

1. **[TEST-0.5a] GitHub Actions CI для Linux** 🔥 - автоматическая сборка и тесты на Linux
2. **[MVP-1.1] ChannelMessageSource: базовая структура** - протокол + TDLib реализация
3. **[MVP-2.1] OpenAI HTTP Client** - интеграция для генерации саммари

---

## 📊 High Priority (MVP Phase 1-2)

### DEV-0. Developer Experience

**Цель:** Настроить удобное окружение для разработки на Linux VPS с доступом с iPhone.

#### Задачи:

**0.1 Установка Claude CLI на Linux VPS** ✅
- [x] Установить Claude CLI на Linux сервер (v2.0.29 через npm)
- [x] Проверить совместимость с существующим окружением (Swift, TDLib)
- [ ] Настроить авторизацию Claude CLI (пользователь сделает сам)
- [x] Проверить доступ к проекту tg-client на VPS

**0.2 Настройка SSH доступа с iPhone** ✅
- [x] Установить SSH клиент на iPhone (Blink Shell или Termius)
- [x] Настроить SSH ключи для безопасного подключения (Ed25519)
- [x] Проверить подключение к VPS с iPhone (успешно)
- [x] Настроить удобную работу с Claude CLI через SSH

**0.3 Тестирование workflow** ✅
- [x] Авторизовать Claude CLI через `claude setup-token`
- [x] Проверить работу Claude CLI на VPS с iPhone
- [x] Попробовать выполнить простую задачу разработки с iPhone (сборка проекта)
- [x] Документировать процесс в SETUP.md и DEPLOY.md

---

### TEST-0. Покрытие существующего кода (до MVP-1)

**Цель:** Покрыть тестами существующую функциональность перед началом MVP разработки.

**Стратегия:** Вариант A (unit-тесты + manual E2E, без рефакторинга авторизации).

#### Задачи:

**0.1 Unit-тесты: TDLibRequestEncoder** ✅
- [x] Тест `testEncodeGetMeRequest()` - простой запрос без параметров
- [x] Тест `testEncodeSetTdlibParametersRequest()` - сложный запрос с snake_case
- [x] Тест `testEncodeSetAuthenticationPhoneNumberRequest()`
- [x] Тест `testEncodeCheckAuthenticationCodeRequest()`
- [x] Тест `testEncodeCheckAuthenticationPasswordRequest()`
- [x] Проверка валидности JSON формата
- [x] Проверка отсутствия camelCase ключей в JSON

**0.2 Unit-тесты: Response модели (декодирование)** ✅
- [x] `testDecodeAuthorizationStateWaitTdlibParameters()`
- [x] `testDecodeAuthorizationStateWaitPhoneNumber()`
- [x] `testDecodeAuthorizationStateWaitCode()`
- [x] `testDecodeAuthorizationStateWaitPassword()`
- [x] `testDecodeAuthorizationStateReady()`
- [x] `testDecodeTDLibError()`
- [x] Fallback behavior для invalid JSON

**0.3 Unit-тесты: TDLibUpdate (обёртка)** ✅
- [x] `testParseUpdateAuthorizationState()`
- [x] `testParseError()`
- [x] `testParseOkResponse()`
- [x] `testParseInvalidJSON()` - error handling

**0.4 Manual E2E тест** ✅
- [x] Создать скрипт `scripts/manual_e2e_auth.sh`
- [x] Проверка полного цикла авторизации с реальным TDLib
- [x] Поддержка Linux (приоритет) и macOS (опционально)
- [x] Документация в скрипте (требует credentials, не для CI)

**0.5 Linux Build Verification** (ВЫСОКИЙ ПРИОРИТЕТ)
- [ ] **0.5a: GitHub Actions CI**
  - [ ] Создать `.github/workflows/linux-build.yml`
  - [ ] Настроить job на Linux (ubuntu-latest)
  - [ ] Установка Swift toolchain + TDLib
  - [ ] Запуск `swift build` и `swift test`
  - [ ] Проверка что workflow работает (запуск/просмотр логов)
- [x] **0.5b: Manual VPS/Docker проверка** ✅ (сборка работает, авторизация успешна; см. заметку о SwiftPM в [DEPLOY.md](DEPLOY.md))
  - [x] Создать Linux окружение (VPS или Docker)
  - [x] Установить Swift + TDLib на Linux
  - [x] Запустить `swift build && swift test`
  - [x] Запустить `scripts/manual_e2e_auth.sh`
  - [x] Документировать процесс в [DEPLOY.md](DEPLOY.md) (секция Linux Setup)

**Примечание:** Component-тесты для авторизации откладываем (требуют рефакторинга 3.7 с DI/протоколами).

---

### MVP-1. ChannelMessageSource (TDLib Integration)

**Цель:** Получение непрочитанных сообщений из Telegram каналов.

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

#### Задачи:

**1.1 Создать протокол и базовую структуру**
- [ ] Определить протокол `MessageSourceProtocol`
- [ ] Создать модель `SourceMessage` (id, chatId, chatTitle, text, date, link)
- [ ] Создать `ChannelMessageSource` stub
- [ ] Unit-тесты для моделей

**1.2 Получение списка каналов**
- [ ] TDLib метод `getChats(chatList: .main)` - получить все чаты
- [ ] Фильтрация: только каналы (тип `channel`)
- [ ] Фильтрация: не в архиве (`chatList != .archive`)
- [ ] Фильтрация: есть непрочитанные (`unreadCount > 0`)
- [ ] Unit-тесты с моками TDLib

**1.3 Извлечение сообщений из канала**
- [ ] TDLib метод `getChatHistory(chatId:, limit:)`
- [ ] Получение только непрочитанных (после `lastReadOutboxMessageId`)
- [ ] Формирование ссылок: `t.me/<username>/<messageId>`
- [ ] Обработка каналов без username (приватные invite links)
- [ ] Unit-тесты

**1.4 Отметка прочитанным**
- [ ] TDLib метод `viewMessages(chatId:, messageIds:)`
- [ ] Вызов ТОЛЬКО после успешной отправки дайджеста
- [ ] Обработка ошибок (rollback если фейл)
- [ ] Unit-тесты

**1.5 Типизация TDLib методов**
- [ ] Request: `GetChats`, `GetChatHistory`, `ViewMessages`
- [ ] Response: `Chats`, `Messages`, `Ok`
- [ ] Update: `UpdateChatReadInbox` (опционально для отслеживания)

**Зависимости:** Базовая типизация TDLib (3.6 ✅)

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

**2.1 OpenAI HTTP Client**
- [ ] Создать `OpenAIClient` (без зависимостей, прямые HTTP calls)
- [ ] Метод `sendChatCompletion(messages:, model:)` → `ChatCompletionResponse`
- [ ] Обработка ошибок (timeout, rate limit, 5xx)
- [ ] Retry логика (exponential backoff)
- [ ] Unit-тесты с моками URLSession

**2.2 Промпт для саммаризации**
- [ ] Разработать prompt template для дайджестов
- [ ] Формат: "Краткое резюме (2-3 предложения) + группировка по каналам"
- [ ] Инструкции для AI: Telegram Markdown, лимит 4096 символов
- [ ] Тестирование промпта с реальными сообщениями

**2.3 Генерация DigestSummary**
- [ ] Модель `DigestSummary` (summary, channelSummaries, totalMessages, period)
- [ ] Модель `ChannelSummary` (chatTitle, messageCount, summary, messageLinks)
- [ ] Парсинг ответа OpenAI → структурированный дайджест
- [ ] Unit-тесты

**2.4 Handling длинных дайджестов**
- [ ] Проверка длины (4096 символов)
- [ ] Разбиение на несколько сообщений (если превышает лимит)
- [ ] Стратегия: сокращение деталей, группировка каналов
- [ ] Unit-тесты

**2.5 Environment configuration**
- [ ] Чтение `OPENAI_API_KEY` из env
- [ ] Выбор модели: `OPENAI_MODEL` (gpt-4-turbo / gpt-3.5-turbo)
- [ ] Timeout настройка: `OPENAI_TIMEOUT` (default 30s)

**Зависимости:** EnvironmentService (1.1)

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

**3.1 Telegram Bot HTTP Client**
- [ ] Создать `TelegramBotClient` (прямые HTTP calls)
- [ ] Метод `sendMessage(chatId:, text:, parseMode:)` → `Message`
- [ ] Поддержка Telegram MarkdownV2
- [ ] Обработка ошибок (4xx, 5xx)
- [ ] Unit-тесты с моками

**3.2 Форматирование дайджеста**
- [ ] Конвертация `DigestSummary` → Telegram Markdown
- [ ] Форматирование: жирный шрифт для заголовков, ссылки
- [ ] Экранирование спецсимволов MarkdownV2
- [ ] Unit-тесты (проверка корректного Markdown)

**3.3 Отправка алертов**
- [ ] Метод `sendAlert(error:, chatId:)` - форматирование ошибок
- [ ] Разные типы алертов: Auth error, AI error, Bot error, Cron missed
- [ ] Emoji для визуального разделения (🚨, ⚠️, ✅)
- [ ] Unit-тесты

**3.4 Environment configuration**
- [ ] Чтение `TELEGRAM_BOT_TOKEN` из env
- [ ] Чтение `TELEGRAM_BOT_CHAT_ID` (куда слать дайджесты)
- [ ] Чтение `DIGEST_ALERT_CHAT_ID` (куда слать алерты, default = CHAT_ID)

**Зависимости:** EnvironmentService (1.1)

---

### MVP-4. StateManager (Persistence)

**Цель:** Хранение состояния последнего запуска.

#### Задачи:

**4.1 FileBasedStateManager**
- [ ] Протокол `StateManagerProtocol`
- [ ] Реализация с JSON файлом (`~/.tdlib/digest_state.json`)
- [ ] Модель `DigestState` (lastSuccessfulRun, lastMessageIdByChat)
- [ ] Методы: `loadState()`, `saveState()`, `updateLastRun()`
- [ ] Thread-safe операции (FileManager + locks)
- [ ] Unit-тесты

**4.2 Миграция старых состояний**
- [ ] Обработка отсутствия файла (первый запуск)
- [ ] Обработка поврежденного JSON (fallback to default)
- [ ] Логирование загрузки/сохранения состояния

**Зависимости:** Нет

---

### MVP-5. DigestOrchestrator (Coordination)

**Цель:** Координация всех компонентов для генерации дайджеста.

#### Задачи:

**5.1 Базовая структура**
- [ ] Класс `DigestOrchestrator` с DI всех сервисов
- [ ] Метод `run(mode: .scheduled | .onDemand) async throws`
- [ ] Логирование каждого этапа (structured logging)
- [ ] Unit-тесты с моками

**5.2 Оркестрация потока**
- [ ] Загрузка состояния (StateManager)
- [ ] Получение сообщений (ChannelMessageSource)
- [ ] Генерация саммари (SummaryGenerator)
- [ ] Отправка через бота (BotNotifier)
- [ ] Отметка прочитанным (ChannelMessageSource)
- [ ] Сохранение состояния (StateManager)

**5.3 Error handling**
- [ ] Try-catch на каждом этапе
- [ ] Rollback: если отправка фейлится → НЕ помечать прочитанным
- [ ] Отправка алертов через BotNotifier при ошибках
- [ ] Partial success: если часть каналов обработана успешно

**5.4 CLI интерфейс**
- [ ] `tg-digest scheduled` - scheduled режим (учитывает timestamp)
- [ ] `tg-digest on-demand` - on-demand режим (игнорирует timestamp)
- [ ] Аргументы: `--dry-run` (не отправлять, только логи)
- [ ] Exit codes: 0 - успех, 1 - ошибка

**Зависимости:** Все предыдущие модули (MVP-1 to MVP-4)

---

## 📋 Normal Priority (MVP Phase 3-4)

### MVP-6. MonitoringService (Observability)

**Цель:** Мониторинг и алерты для продакшена.

#### Задачи:

**6.1 Structured Logging**
- [ ] Интеграция swift-log
- [ ] JSON формат для логов
- [ ] Уровни: DEBUG, INFO, WARN, ERROR
- [ ] Контекст: timestamp, module, operation, duration
- [ ] Ротация логов (logrotate config)

**6.2 Healthcheck механизм**
- [ ] Heartbeat файл (`~/.tdlib/digest_heartbeat.txt`) с timestamp
- [ ] Обновление после каждого успешного запуска
- [ ] Скрипт `/usr/local/bin/digest-healthcheck.sh` для проверки
- [ ] Cron задача для healthcheck (каждые 5 минут)
- [ ] Алерт если heartbeat старше 3 часов

**6.3 Telegram Self-Monitoring**
- [ ] Алерт при старте приложения (✅ Started)
- [ ] Алерт при успешном завершении (✅ Digest sent: N channels)
- [ ] Алерт при ошибках (🚨 Failed: <error>)
- [ ] Daily summary (📊 Stats за день)

**Зависимости:** BotNotifier (MVP-3)

---

### MVP-7. Deployment (Linux VPS)

**Цель:** Развертывание на продакшен сервере.

#### Задачи:

**7.1 systemd Service**
- [ ] Файл `tg-digest.service` для on-demand запусков
- [ ] Hardening: user isolation, sandboxing, resource limits
- [ ] Restart policy: on-failure с backoff
- [ ] Логирование в journald

**7.2 Cron Setup**
- [ ] Cron задача для scheduled запусков (09:00, 18:00)
- [ ] Запуск через systemd (не напрямую)
- [ ] Логирование cron запусков

**7.3 Environment Setup**
- [ ] `.env` файл с credentials
- [ ] Шаблон `.env.example` для репозитория
- [ ] Инструкции по безопасному хранению секретов
- [ ] systemd EnvironmentFile для загрузки .env

**7.4 Log Management**
- [ ] logrotate конфигурация для application логов
- [ ] journald limits (max size, retention)
- [ ] Скрипты для фильтрации логов (`digest-logs.sh`)
- [ ] Инструкции для troubleshooting

**7.5 Обновление DEPLOY.md**
- [ ] Раздел "Digest Service Setup"
- [ ] Инструкции по установке systemd service
- [ ] Настройка cron
- [ ] Мониторинг и healthcheck
- [ ] Типичные проблемы и решения

**Зависимости:** DigestOrchestrator (MVP-5), MonitoringService (MVP-6)

---

### MVP-8. Testing & Documentation

**Цель:** Покрытие тестами и обновление документации.

#### 8.1 Testing Strategy
- [ ] Обновить TESTING.md с учетом MVP модулей
- [ ] Unit-тесты: 80% coverage для core логики
- [ ] Component-тесты: DigestOrchestrator с моками
- [ ] E2E тест: полный цикл на VPS (manual)
- [ ] CI: `swift test` в GitHub Actions

#### 8.2 Documentation Updates
- [ ] README.md: Quick Start для MVP
- [ ] DEPLOY.md: Полная инструкция деплоя
- [ ] TROUBLESHOOTING.md: Частые ошибки MVP
- [ ] ARCHITECTURE.md: Диаграммы новых модулей
- [ ] .env.example: Все переменные окружения

**Зависимости:** Все предыдущие модули

---

## 💡 Low Priority (Technical Debt)

### 1.1 Создать EnvironmentService абстракцию

**Цель:** Типобезопасное чтение credentials из env.

- [ ] Протокол `EnvironmentServiceProtocol`
- [ ] `ProcessInfoEnvironmentService` для macOS/Linux
- [ ] `AppConfiguration` struct для типобезопасной конфигурации
- [ ] Валидация обязательных переменных при старте
- [ ] Unit-тесты

**Приоритет:** Нужно для MVP-2 и MVP-3 (перед началом)

---

### 3.2 Вынести параметры TDLib в константы

**Цель:** Улучшить читаемость и maintainability.

- [ ] Создать `Sources/TDLibAdapter/TDLibParameters.swift`
- [ ] Static метод `buildParameters(from config: TDConfig) -> [String: Any]`
- [ ] Документация каждого параметра + объяснение inline формата (TDLib 1.8.6+)

**Приоритет:** Low (можно сделать параллельно с MVP-1)

---

### 3.4 Добавить комментарии и документацию в TDLibAdapter

**Цель:** Улучшить читаемость существующего кода.

- [ ] Документировать класс `TDLibClient` (назначение, thread-safety, использование)
- [ ] Документировать метод `start()` (async/await, continuation)
- [ ] Документировать `processAuthorizationStates()` (state machine, диаграмма)
- [ ] Объяснить формат JSON-сообщений TDLib
- [ ] Inline комментарии к неочевидным местам (`await Task.yield()`, `@unchecked Sendable`)

**Приоритет:** Low (не блокирует MVP)

---

### 3.5 Разделение TDLibAdapter на несколько файлов

**Цель:** Улучшить структуру кода.

- [ ] `TDLibClient.swift` - основной класс
- [ ] `TDLibClient+Authorization.swift` - extension с логикой авторизации
- [ ] `TDLibClient+Logging.swift` - extension с настройкой логирования

**Приоритет:** Low (код работает, это рефакторинг)

---

### 3.7 Рефакторинг для тестируемости (Dependency Injection)

**Цель:** Возможность unit-тестирования с моками.

- [ ] Создать протокол `TDLibClientProtocol`
- [ ] Разделить на слои: `TDLibClient` (C API) + `TDLibAuthorizationHandler` (логика)
- [ ] Создать `MockTDLibClient` для тестов
- [ ] Покрыть тестами состояния авторизации, ошибки, edge cases

**Приоритет:** Medium (нужно если будем активно тестировать TDLib интеграцию)

---

### 1.2 Рефакторинг диалога авторизации

**Цель:** Вынести UI логику из TDLibAdapter.

- [ ] Вынести логику запроса credentials в `AuthenticationDialog`
- [ ] Методы: `askPhone()`, `askCode()`, `askPassword()`
- [ ] `AuthenticationDialogProtocol` для тестирования

**Приоритет:** Low (код работает, это улучшение структуры)

---

## 🔗 Ссылки на другие документы

- **Будущие фичи (v0.2.0+):** [IDEAS.md](IDEAS.md)
  - GroupChatMessageSource (группы с диалогами)
  - PrivateChatMessageSource (личные сообщения)
  - Whitelist/Blacklist UI через бота
  - Обработка медиа
  - История и поиск дайджестов
  - Персонализация (tone, length, language)
  - Автоматическая кодогенерация из TL схемы
  - Swift Macro для test-only init
  - Продвинутый мониторинг (Prometheus, Grafana)
  - Docker образ
  - Multi-user поддержка

---

## ✅ Завершенные фичи

### 2. C-заголовки (`shim.h`) ✅

**Статус:** Завершено 2025-10-24
**Коммит:** `b9b1be0`

Полностью документирован механизм C interop для TDLib.

**Детали:** [CHANGELOG.md](CHANGELOG.md#2025-10-24)

---

### 3.6 Типизация запросов и ответов TDLib (Type-Safe API) ✅

**Статус:** Завершено 2025-10-27

**Детали:** [CHANGELOG.md](CHANGELOG.md#2025-10-27)

---

### 3.3 Deprecated функции логирования ✅

**Статус:** Завершено 2025-10-24
**Коммит:** `e5832a8`

Заменены deprecated функции на современный JSON API через `td_execute()`.

**Детали:** [CHANGELOG.md](CHANGELOG.md#2025-10-24)

---

### 3.8 Рефакторинг метода авторизации ✅

**Статус:** Завершено 2025-10-26
**Коммит:** `dc886d4`

Защита от зависания, type-safe enums, организация моделей в отдельные файлы.

**Детали:** [CHANGELOG.md](CHANGELOG.md#2025-10-26-утро)

---

## 🤔 Вопросы для обсуждения

1. **EnvironmentService:** Делать сейчас (до MVP-2/MVP-3) или inline читать env?
2. **OpenAI SDK:** Готовая библиотека или прямые HTTP calls? (рекомендация: HTTP)
3. **Telegram Bot:** Long Polling или Webhook? (рекомендация: Long Polling для MVP)
4. **Deployment:** systemd или Docker? (рекомендация: systemd для single-user MVP)

---

**Дата создания:** 2025-10-19
**Последнее обновление:** 2025-10-28
