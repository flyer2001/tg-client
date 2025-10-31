# MVP: Telegram Digest Bot

> **Дата создания:** 2025-10-28
> **Статус:** Planning
> **Версия:** 0.1.0

---

## 🎯 Продуктовое видение

### Проблема
Информационная перегрузка в Telegram каналах: десятки непрочитанных сообщений, которые невозможно быстро просмотреть.

### Решение
Автоматический дайджест непрочитанных сообщений из каналов с AI-саммари, доставляемый через Telegram бота 2 раза в день + по требованию.

### Целевая аудитория (MVP)
- Автор проекта
- Тестовый пользователь (1-2 человека)

---

## ✅ Функционал MVP (Must Have)

### 1. Сбор сообщений из каналов
- **Scope:** Только Telegram каналы (не группы, не личные чаты)
- **Фильтр:** Каналы НЕ находящиеся в архиве
- **Типы сообщений:** Только текст
- **Лимиты:** Без ограничений по количеству (в рамках лимита TG API)

**Будущее улучшение:** Whitelist каналов (если простой UX для настройки)

### 2. AI Саммаризация (OpenAI)
- **Провайдер:** OpenAI API (GPT-4 или GPT-3.5-turbo)
- **Архитектура:** Абстракция `SummaryGeneratorProtocol` для смены провайдера
- **Формат вывода:**
  - Краткое саммари в начале (2-3 предложения)
  - Группировка по каналам
  - Ссылки на оригинальные сообщения
- **Ограничения:**
  - Максимум 4096 символов (лимит Telegram API для текстового сообщения)
  - Если больше → разбиение на несколько сообщений
- **Формат:** Telegram Markdown (жирный шрифт, курсив, ссылки)

### 3. Доставка через Telegram Bot
- **Куда:** Личный чат с ботом (пользователь → бот)
- **Формат:** Telegram MarkdownV2
- **Режимы запуска:**
  - **Scheduled:** 2 раза в день (cron)
  - **On-demand:** Команда `/digest` в боте

### 4. Отметка прочитанным
- **Когда:** ТОЛЬКО после успешной отправки всех саммари сообщений
- **Как:** TDLib API `viewMessages` для всех обработанных каналов
- **Rollback:** Если отправка фейлится → НЕ помечать прочитанным

### 5. Хранение состояния
- **Минимальное:** Timestamp последней успешной обработки
- **Формат:** JSON файл `~/.tdlib/digest_state.json`
- **Структура:**
  ```json
  {
    "last_successful_run": "2025-10-28T14:30:00Z",
    "last_message_id_by_chat": {
      "chat_12345": 67890
    }
  }
  ```

### 6. Мониторинг и алерты
- **Логирование:**
  - Structured logging (JSON) для каждого этапа
  - Уровни: DEBUG, INFO, WARN, ERROR
  - Ротация логов (logrotate)
- **Алерты через TG бот:**
  - Ошибка авторизации
  - Ошибка AI API (timeout, quota, 5xx)
  - Ошибка отправки бота
  - Пропущенный cron запуск (heartbeat)
- **Healthcheck:**
  - Скрипт `/usr/local/bin/digest-healthcheck.sh`
  - Проверка последнего heartbeat (файл с timestamp)
  - Cron задача для мониторинга

### 7. Deployment
- **Платформа:** Linux VPS (Ubuntu/Debian)
- **Режим:** systemd service + cron для scheduled запусков
- **Конфигурация:** Переменные окружения (credentials, API keys)
- **Логи:** Centralized logging с инструкциями фильтрации

---

## 🚫 Не входит в MVP (Future Features)

### Отложенные фичи (v0.2.0+)
- Обработка медиа (фото, видео, документы) → текстовые описания
- Чтение групп с диалогами (threading)
- Обсуждения внутри каналов (comments)
- Личные сообщения (DM)
- Whitelist/Blacklist UI через бота
- Настройка частоты через бота (сейчас hardcoded 2 раза/день)
- Экспорт в другие форматы (email, RSS)
- История дайджестов (архив)
- Поиск по старым дайджестам
- Теги и категоризация каналов
- Персонализация саммари (тон, длина, язык)

### Технические улучшения (Backlog)
- Продвинутый мониторинг (Prometheus + Grafana)
- Веб-интерфейс для управления
- Multi-user поддержка (несколько пользователей на одном инстансе)
- Docker образ для простого деплоя
- Horizontal scaling (queue-based processing)

---

## 📋 Технические требования MVP

### Архитектура (модули)

```
┌─────────────────────────────────────────────────────────┐
│                    DigestOrchestrator                   │
│              (main entry point, координатор)            │
└─────────────────────────────────────────────────────────┘
                           │
        ┌──────────────────┼──────────────────┐
        ▼                  ▼                  ▼
┌───────────────┐  ┌──────────────┐  ┌──────────────┐
│ MessageSource │  │SummaryGenerator│  │ BotNotifier  │
│ (Channels MVP)│  │   (OpenAI)    │  │  (TG Bot API)│
└───────────────┘  └──────────────┘  └──────────────┘
        │                  │                  │
        └──────────────────┴──────────────────┘
                           ▼
                  ┌─────────────────┐
                  │  StateManager   │
                  │ (timestamp JSON)│
                  └─────────────────┘
                           ▼
                  ┌─────────────────┐
                  │ MonitoringService│
                  │  (alerts, logs) │
                  └─────────────────┘
```

### Ключевые компоненты

#### 1. MessageSource (Channel Implementation)
- Протокол: `MessageSourceProtocol` (абстракция для разных типов чатов)
- Реализация: `ChannelMessageSource` (MVP - только каналы)
- Будущие реализации: `GroupChatMessageSource`, `PrivateChatMessageSource`
- Методы:
  - `fetchUnreadMessages(since: Date?) async throws -> [SourceMessage]`
  - `markAsRead(messages: [SourceMessage]) async throws`

##### TDLib API: Работа с непрочитанными сообщениями

> **Документация TDLib:** https://core.telegram.org/tdlib/docs/

**Механизм отслеживания непрочитанных:**

TDLib отслеживает состояние прочитанности на стороне сервера Telegram. Каждый чат содержит:

- `unreadCount: Int` — количество непрочитанных сообщений (поддерживается сервером)
- `lastReadInboxMessageId: Int64` — ID последнего прочитанного входящего сообщения
- `lastReadOutboxMessageId: Int64` — ID последнего отправленного сообщения (для личных чатов)

**Методы TDLib API:**

1. **`getChats(chatList:, limit:)`** → возвращает `Chats`
   - Получает список чатов с актуальным `unreadCount` и `lastReadInboxMessageId`
   - Параметр `chatList` может быть `.main` (основной список) или `.archive`
   - Документация: https://core.telegram.org/tdlib/docs/classtd_1_1td__api_1_1get_chats.html

2. **`getChatHistory(chatId:, fromMessageId:, offset:, limit:)`** → возвращает `Messages`
   - `fromMessageId: Int64` — ID сообщения, от которого начать (включительно)
   - `offset: Int` — смещение относительно fromMessageId (обычно 0)
   - `limit: Int` — количество сообщений для получения
   - Сообщения возвращаются в **обратном хронологическом порядке** (новые → старые)
   - Документация: https://core.telegram.org/tdlib/docs/classtd_1_1td__api_1_1get_chat_history.html

3. **`viewMessages(chatId:, messageIds:, forceRead:)`** → возвращает `Ok`
   - Отмечает сообщения как прочитанные (обновляет `lastReadInboxMessageId`)
   - `forceRead: true` — отметить как прочитанные (не только просмотренные)
   - Документация: https://core.telegram.org/tdlib/docs/classtd_1_1td__api_1_1view_messages.html

**Оптимизация: получение только непрочитанных без клиентской фильтрации**

TDLib не имеет метода "дай только непрочитанные", но можно оптимизировать запрос:

```swift
// Шаг 1: Получить информацию о чате
let chats = try await tdlib.send(GetChatsRequest(chatList: .main, limit: 100))
let unreadChannels = chats.filter { $0.type == .channel && $0.unreadCount > 0 }

// Шаг 2: Для каждого канала получить непрочитанные
for channel in unreadChannels {
    // Запросить ровно unreadCount сообщений, начиная с последнего
    let history = try await tdlib.send(
        GetChatHistoryRequest(
            chatId: channel.id,
            fromMessageId: 0,  // 0 = начать с последнего сообщения
            offset: 0,
            limit: channel.unreadCount
        )
    )

    // Фильтр для гарантии (защита от race condition)
    let unreadMessages = history.messages.filter {
        $0.id > channel.lastReadInboxMessageId
    }

    // Все полученные сообщения будут непрочитанными (если unreadCount точный)
}

// Шаг 3: После успешной отправки дайджеста
try await tdlib.send(
    ViewMessagesRequest(
        chatId: channel.id,
        messageIds: unreadMessages.map { $0.id },
        forceRead: true
    )
)
```

**Важные замечания:**

- ⚠️ **Race condition:** между `getChats` и `getChatHistory` кто-то может прочитать сообщения → всегда фильтровать по `lastReadInboxMessageId`
- ✅ **Эффективность:** используя `limit: unreadCount` минимизируем трафик
- ✅ **Надёжность:** фильтр по `messageId > lastReadInboxMessageId` гарантирует корректность

**Формирование ссылок на сообщения:**

```swift
// Для публичных каналов (с username)
let link = "https://t.me/\(channel.username)/\(message.id)"

// Для приватных каналов (без username)
// Требует invite link, в MVP — пропускаем или показываем "Private channel"
```

#### 2. SummaryGenerator
- Протокол: `SummaryGeneratorProtocol`
- Реализации:
  - `OpenAISummaryGenerator` (MVP)
  - `ClaudeSummaryGenerator` (future)
  - `MockSummaryGenerator` (tests)
- Методы:
  - `generateSummary(messages:, maxLength:) async throws -> DigestSummary`

#### 3. BotNotifier
- Протокол: `BotNotifierProtocol`
- Реализация: `TelegramBotNotifier`
- Методы:
  - `send(summary:, chatId:) async throws`
  - `sendAlert(error:, chatId:) async throws`

#### 4. StateManager
- Протокол: `StateManagerProtocol`
- Реализация: `FileBasedStateManager`
- Методы:
  - `loadState() throws -> DigestState`
  - `saveState(_:) throws`
  - `getLastRunTimestamp() -> Date?`
  - `updateLastRun(_:) throws`

#### 5. MonitoringService
- Логирование: `swift-log` + structured JSON
- Алерты: через `BotNotifier`
- Healthcheck: heartbeat файл + cron

### Модели данных

```swift
struct DigestState: Codable {
    let lastSuccessfulRun: Date
    let lastMessageIdByChat: [Int64: Int64]
}

struct Message {
    let id: Int64
    let chatId: Int64
    let chatTitle: String
    let text: String
    let date: Date
    let link: String  // t.me/channel/123
}

struct DigestSummary {
    let summary: String  // краткое резюме (2-3 предложения)
    let channelSummaries: [ChannelSummary]
    let totalMessages: Int
    let periodStart: Date
    let periodEnd: Date
}

struct ChannelSummary {
    let chatId: Int64
    let chatTitle: String
    let messageCount: Int
    let summary: String
    let messageLinks: [String]
}
```

### Зависимости

```swift
// Package.swift
dependencies: [
    .package(url: "https://github.com/apple/swift-log.git", from: "1.6.4"),
    // OpenAI SDK - TBD (может быть прямые HTTP calls)
]
```

### Environment Variables

```bash
# Telegram Client (TDLib)
TELEGRAM_API_ID=...
TELEGRAM_API_HASH=...
TELEGRAM_PHONE=...

# Telegram Bot (для отправки)
TELEGRAM_BOT_TOKEN=...
TELEGRAM_BOT_CHAT_ID=...  # куда слать дайджесты

# OpenAI
OPENAI_API_KEY=...
OPENAI_MODEL=gpt-4-turbo  # или gpt-3.5-turbo

# State
DIGEST_STATE_DIR=~/.tdlib

# Monitoring
DIGEST_ALERT_CHAT_ID=...  # куда слать алерты (может быть тот же что и дайджесты)
```

---

## 🎬 User Flow (MVP)

### Scheduled Run (Cron)

```
1. Cron запускает `tg-digest scheduled` (2 раза в день: 09:00, 18:00)
2. DigestOrchestrator:
   a. Проверяет timestamp последнего запуска
   b. MessageSource получает непрочитанные сообщения из каналов (не в архиве)
   c. Для каждого канала извлекает сообщения после last_message_id
   d. SummaryGenerator создает AI-саммари
   e. BotNotifier отправляет в TG бота
   f. Если успешно → MessageSource.markAsRead для всех каналов
   g. Обновляет timestamp в StateManager
3. Healthcheck записывает heartbeat
4. При ошибке → отправка алерта через BotNotifier
```

### On-Demand Run (Telegram Bot)

```
1. Пользователь отправляет `/digest` в бота
2. Bot webhook вызывает `tg-digest on-demand`
3. Тот же flow что и scheduled, но:
   - Игнорирует timestamp (всегда обрабатывает непрочитанные)
   - Отправляет статус "Генерирую дайджест..." сразу
```

---

## ✅ Критерии готовности MVP

### Функциональные требования
- [ ] Успешная авторизация TDLib клиента
- [ ] Получение списка непрочитанных каналов (не в архиве)
- [ ] Извлечение текстовых сообщений с ссылками
- [ ] Генерация AI-саммари через OpenAI API
- [ ] Отправка дайджеста через Telegram бота
- [ ] Отметка сообщений прочитанными
- [ ] Сохранение/восстановление состояния (timestamp)
- [ ] Scheduled запуск через cron (2 раза/день)
- [ ] On-demand запуск через бота (`/digest`)
- [ ] Алерты в TG бот при критичных ошибках

### Технические требования
- [ ] TDD: минимум 80% code coverage для core логики
- [ ] Structured logging (JSON) для всех операций
- [ ] Healthcheck скрипт + cron мониторинг
- [ ] systemd service для Linux VPS
- [ ] Документация деплоя (DEPLOY.md обновлен)
- [ ] Инструкции по фильтрации логов (скрипты)

### Документация
- [ ] README.md обновлен (quick start)
- [ ] DEPLOY.md обновлен (systemd + cron setup)
- [ ] TROUBLESHOOTING.md (частые ошибки + логи)
- [ ] Примеры environment variables (.env.example)

### Тестирование
- [ ] Unit-тесты для SummaryGenerator (моки OpenAI)
- [ ] Unit-тесты для ChannelFetcher (моки TDLib)
- [ ] Unit-тесты для StateManager
- [ ] Component-тесты для DigestOrchestrator
- [ ] Manual E2E тест на VPS (полный цикл)

---

## 🚀 План выхода MVP (Roadmap)

### Phase 1: Core Components (2-3 недели)
1. **ChannelFetcher** (TDLib integration)
   - Получение списка каналов
   - Фильтрация (не в архиве)
   - Извлечение сообщений
   - Отметка прочитанным
2. **SummaryGenerator** (OpenAI integration)
   - OpenAI API client
   - Промпт для саммаризации
   - Handling лимитов (4096 символов)
3. **BotNotifier** (Telegram Bot API)
   - Отправка текстовых сообщений
   - Markdown форматирование
   - Error handling

### Phase 2: Orchestration & State (1 неделя)
4. **StateManager** (persistence)
   - JSON файл с timestamp
   - Load/Save операции
5. **DigestOrchestrator** (координация)
   - Связывание всех компонентов
   - Error handling между модулями
   - Rollback логика

### Phase 3: Deployment & Monitoring (1 неделя)
6. **MonitoringService**
   - Structured logging
   - Алерты через TG бот
   - Healthcheck скрипт
7. **Deployment**
   - systemd service
   - cron setup
   - Логи + фильтрация

### Phase 4: Testing & Documentation (1 неделя)
8. **Testing**
   - Unit-тесты (80% coverage)
   - E2E тесты
9. **Documentation**
   - DEPLOY.md
   - TROUBLESHOOTING.md
   - README.md

**Итого:** ~6 недель до готового MVP

---

## 📊 Метрики успеха (после запуска)

### Технические метрики
- Uptime > 99% (за месяц)
- Successful runs > 95% (cron запуски)
- API errors < 5% (OpenAI + TG Bot)
- Avg processing time < 2 минуты (per run)

### Продуктовые метрики
- Количество дайджестов в день: 2 (scheduled) + N (on-demand)
- Среднее количество каналов в дайджесте: X
- Среднее количество сообщений в дайджесте: Y
- User feedback: "полезно" vs "не читаю"

---

## 🤔 Открытые вопросы

1. **OpenAI SDK:** Использовать готовую библиотеку или писать HTTP client?
   - Плюсы SDK: меньше кода, поддержка retry/timeout
   - Минусы SDK: зависимость, потенциальные breaking changes

2. **Telegram Bot режим:** Webhook vs Long Polling?
   - Webhook: требует HTTPS, быстрее
   - Long Polling: проще setup, подходит для MVP

3. **Структура логов:** JSON строки или structured fields?
   - JSON: легче парсить для анализа
   - Structured: читабельнее для человека

4. **Deployment:** Docker или нативный systemd?
   - Docker: easier replication, isolated env
   - Systemd: lighter, faster startup

**Предлагаемое решение для MVP:**
- OpenAI: прямые HTTP calls (меньше зависимостей)
- Bot: Long Polling (проще для MVP)
- Logs: JSON строки (для будущего Prometheus/Loki)
- Deployment: systemd (меньше overhead для single user)

---

**Создатель:** @flyer2001
**Версия документа:** 1.0
**Последнее обновление:** 2025-10-28
