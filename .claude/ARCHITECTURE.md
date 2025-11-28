# Архитектура проекта

## Трёхслойная структура

### 1. CTDLib (System Library)
Swift-биндинги к нативному C API TDLib через module map:
- `Sources/CTDLib/shim.h`: Включает `td_json_client.h`
- `Sources/CTDLib/module.modulemap`: Определяет системный модуль и линкует `libtdjson`

### 2. TDLibAdapter (Middle Layer)
Swift-обёртка над CTDLib, которая обрабатывает:
- Жизненный цикл TDLib клиента (create/destroy)
- JSON-коммуникацию с TDLib (методы `send`/`receive`)
- State machine для процесса авторизации (обработка запросов телефона, кода, 2FA пароля)
- Фоновый receive loop на выделенной dispatch queue
- Конфигурацию логирования

**Ключевой тип**: `TDLibClient` - основной интерфейс для взаимодействия с TDLib

### 3. App (Executable)
CLI-приложение, которое:
- Читает credentials из переменных окружения
- Предоставляет консольные промпты для авторизации
- Демонстрирует базовое использование (логин и верификация через `getMe`)

## Паттерн коммуникации с TDLib

- Вся коммуникация использует JSON-словари с полем `@type`
- `send()` - асинхронный запрос к TDLib
- `receive(timeout:)` - блокирующий вызов для получения обновлений/ответов
- Авторизация использует паттерн state machine через обновления `updateAuthorizationState`

## Поток авторизации

Адаптер автоматически обрабатывает эти состояния:
1. `authorizationStateWaitTdlibParameters` → отправляет конфигурацию приложения
2. `authorizationStateWaitPhoneNumber` → запрашивает телефон
3. `authorizationStateWaitCode` → запрашивает SMS/app код
4. `authorizationStateWaitPassword` → запрашивает 2FA пароль (если включен)
5. `authorizationStateReady` → сигнализирует готовность через callback

## Модули (планируемые)

Пока в одном таргете, но как логические границы:

- **ChatFetcher** → возвращает непрочитанные с метаданными
- **SummaryGenerator** → принимает массив сообщений, отдаёт краткое резюме; таймауты/ошибки обрабатывает внутри
- **BotNotifier** → форматирует Markdown и отправляет, логирует успех/ошибки
- **Logger** → единый интерфейс debug/info/warn/error; консоль (dev) и файл (prod)

### Модуль TelegramCore

Сейчас это placeholder-модуль (`Sources/TelegramCore/TelegramCore.swift`), предназначенный для высокоуровневой бизнес-логики Telegram. Имеет базовый test suite в `Tests/TelegramCoreTests/`.

## Паттерны кода

При работе с TDLib:
- Всегда проверяйте наличие поля `@type` в полученных JSON-объектах
- Используйте dispatch queues корректно - receive loop работает на фоновой queue
- Структура директории состояния: `$TDLIB_STATE_DIR/{db,files}` плюс `tdlib.log`
- Клиент автоматически уничтожается при deinit, освобождая ресурсы TDLib

## Error Handling Strategy

### Принципы обработки ошибок

В проекте различаем три категории ошибок внешних сервисов:

#### 1. Recoverable (можно retry)
Временные проблемы, которые могут исчезнуть при повторной попытке:
- Network timeout
- TDLib 500 (можно пересоздать клиент)
- Rate limit 429 (retry с exponential backoff)

#### 2. Unrecoverable (требуется вмешательство администратора)
Критичные ошибки, при которых автоматический retry бесполезен:
- **SESSION_REVOKED / AUTH_KEY_UNREGISTERED**: Пользователь завершил все сессии → нужна ре-авторизация
- **USER_DEACTIVATED**: Аккаунт заблокирован/деактивирован → проверить статус аккаунта
- **500 (TDLib closed)**: TDLib client в final state → restart приложения
- **406**: Внутренняя ошибка TDLib, не показывать пользователю

#### 3. Service-specific (специфичные для сервиса)
- **OpenAI quota exceeded**: Skip summary, отправить raw messages
- **Bot API rate limit**: Exponential backoff

### Graceful Shutdown

При критичной ошибке (unrecoverable) приложение должно:
1. **Сохранить состояние**: Прогресс обработки (последний обработанный chat_id)
2. **Cleanup resources**: Закрыть соединения, flush логи
3. **Exit с понятным сообщением**: Указать причину и рекомендуемые действия

**Пример:**
```
[ERROR] SESSION_REVOKED: Telegram session terminated by user
[INFO] Progress saved: processed 50/100 chats (last_id=12345)
[ACTION] Re-authorization required. Run: ./tg-client auth
```

### Circuit Breaker Pattern

**TODO (post-MVP):** Предотвращение retry loops при критичных ошибках.

**Проблема:** Если TDLib возвращает SESSION_REVOKED, а DigestOrchestrator в retry loop → спам запросов.

**Решение:**
- Считать последовательные ошибки одного типа
- После N ошибок подряд (например, 3) → stop, перейти в graceful shutdown
- Не применять для transient errors (network timeout)

**Пример реализации:**
```swift
actor CircuitBreaker {
    private var consecutiveErrors: [String: Int] = [:]

    func recordError(code: Int) throws {
        let key = String(code)
        consecutiveErrors[key, default: 0] += 1

        if consecutiveErrors[key]! >= 3 {
            throw CircuitBreakerError.open(code: code)
        }
    }

    func reset() {
        consecutiveErrors.removeAll()
    }
}
```

**Связанные задачи:** См. `.claude/IDEAS.md` → RESIL-1, RESIL-2, RESIL-3

### Логирование ошибок

Все ошибки внешних сервисов логируются с метаданными:
- **Error code** и **message** из сервиса
- **Категория** (recoverable/unrecoverable)
- **Retry count** (если применимо)
- **Context**: какая операция выполнялась (loadChats, summarize, sendNotification)

**TDLib ошибки:** См. https://core.telegram.org/api/errors

---

## Logging Strategy

### Принципы логирования

Проект использует **swift-log** для structured logging.

**Цели:**
- Debugging в development (понимание потока выполнения)
- Observability в production (мониторинг, алерты)
- Troubleshooting (анализ проблем через journald/logrotate)

### Уровни логирования

#### `.info` — Основные вехи операций

**Когда использовать:**
- Начало/завершение ключевых операций
- Итоговые метрики (count, duration)
- Успешное завершение внешних вызовов

**Примеры:**
```swift
logger.info("fetchUnreadMessages() started")
logger.info("Loaded \(count) chats from TDLib")
logger.info("Completed", metadata: [
    "messages": "\(messages.count)",
    "channels": "\(unreadChannels.count)",
    "duration": "\(duration)s"
])
```

**Правило:** Один `.info()` на вход/выход операции + итог.

#### `.error` — Ошибки и исключительные ситуации

**Когда использовать:**
- Любые `catch` блоки (особенно в partial failure)
- Критичные ошибки (SESSION_REVOKED, network timeout)
- Неожиданные состояния (404 не там где ожидали)

**Примеры:**
```swift
logger.error("Failed to fetch from channel", metadata: [
    "chatId": "\(chat.id)",
    "title": "\(chat.title)",
    "error": "\(error.localizedDescription)"
])

logger.error("SESSION_REVOKED: re-authorization required")
```

**Правило:** Всегда включать context (chatId, operationName) + error details.

#### `.debug` — Детальная информация для разработки

**Когда использовать:**
- Промежуточные этапы операций (для debugging flow)
- Детали внутренних состояний (actor state, cache hits/misses)
- Входные/выходные параметры (только в development)

**Примеры:**
```swift
logger.debug("Filtering channels", metadata: [
    "totalChats": "\(allChats.count)",
    "channels": "\(channelCount)",
    "withUnread": "\(unreadCount)"
])

logger.debug("getChatHistory request", metadata: [
    "chatId": "\(chatId)",
    "limit": "\(limit)"
])
```

**Правило:** Не логировать sensitive data (tokens, credentials). В production `.debug` обычно отключён.

#### `.warning` — Нештатные, но не критичные ситуации

**Когда использовать:**
- Partial failure (один канал упал, остальные OK)
- Retry попытки (перед exponential backoff)
- Deprecated API usage

**Примеры:**
```swift
logger.warning("Skipping channel due to error", metadata: [
    "chatId": "\(chat.id)",
    "error": "\(error)"
])

logger.warning("Retry attempt \(retryCount)/3 for loadChats")
```

**Правило:** Warning НЕ останавливает операцию, но требует внимания.

### Dependency Injection для Logger

**Правило:** Каждый компонент получает Logger через `init` (не создаёт внутри).

```swift
public actor ChannelMessageSource: MessageSourceProtocol {
    private let tdlib: TDLibClientProtocol
    private let logger: Logger  // DI

    public init(tdlib: TDLibClientProtocol, logger: Logger) {
        self.tdlib = tdlib
        self.logger = logger
    }
}
```

**В production:**
```swift
let logger = Logger(label: "com.tg-client.ChannelMessageSource")
let messageSource = ChannelMessageSource(tdlib: tdlibClient, logger: logger)
```

**В тестах (no-op logger):**
```swift
import Logging

let logger = Logger(label: "test") { _ in
    SwiftLogNoOpLogHandler()
}
let messageSource = ChannelMessageSource(tdlib: mockClient, logger: logger)
```

### Structured Logging (metadata)

**Правило:** Используй `metadata` для key-value данных (для парсинга в будущем).

```swift
// ✅ Хорошо: structured metadata
logger.info("Completed", metadata: [
    "operation": "fetchUnreadMessages",
    "messages": "\(count)",
    "duration": "\(duration)"
])

// ❌ Плохо: всё в строке
logger.info("Completed fetchUnreadMessages: \(count) messages in \(duration)s")
```

**Обоснование:**
- Metadata можно фильтровать/парсить (например, в journald)
- Post-MVP: экспорт логов в JSON для аналитики

### Критичные точки логирования (по ADR-001)

**Для `ChannelMessageSource.fetchUnreadMessages()`:**
1. `.info` — Начало операции
2. `.info` — После loadChats (count чатов)
3. `.info` — После фильтрации (count каналов с непрочитанными)
4. `.debug` — Начало параллельных getChatHistory
5. `.error` — Ошибки getChatHistory (с chatId, title)
6. `.info` — Завершение (итоговый count, duration)

**Минимум для MVP:** Пункты 1, 2, 5, 6 (остальные — Post-MVP оптимизация).

### Конфигурация в production

**Уровень логирования настраивается через ENV:**
```bash
export LOG_LEVEL=info  # production default
export LOG_LEVEL=debug  # для troubleshooting
```

**В коде:**
```swift
LoggingSystem.bootstrap { label in
    var handler = StreamLogHandler.standardOutput(label: label)
    handler.logLevel = ProcessInfo.processInfo.environment["LOG_LEVEL"].flatMap {
        Logger.Level(rawValue: $0)
    } ?? .info
    return handler
}
```

**См. также:**
- ADR-001 (Блок 4: Логирование) — архитектурные решения для fetchUnreadMessages
- `.claude/DEVELOPMENT.md` → Git Commit Rules (упоминание логирования в commit messages)

---

## Single Responsibility Principle (SRP)

### Применение в проекте

Проект следует принципу **Single Responsibility Principle**: каждый модуль/класс/компонент отвечает за одну зону ответственности.

### Когда разбивать компонент?

**Признаки нарушения SRP:**
1. Класс/actor > 100 строк кода
2. Множество приватных методов для разных задач
3. Сложность тестирования (mock должен эмулировать несколько аспектов)
4. Название компонента содержит "And" или "Manager" (размытая ответственность)

**Решение:** Декомпозиция на подкомпоненты с чёткими зонами ответственности.

### Паттерн: Coordinator + Workers

**Coordinator (координатор):**
- Не содержит бизнес-логику
- Делегирует задачи Workers
- Управляет жизненным циклом

**Worker (рабочий компонент):**
- Содержит конкретную логику
- Одна чётко определённая ответственность
- Легко тестируется изолированно

### Пример: ChannelMessageSource

**Архитектура:**
```
ChannelMessageSource (Coordinator)
├─ ChannelCache (Worker) — кэширование списка каналов
├─ UpdatesHandler (Worker) — обработка TDLib updates
├─ MessageFetcher (Worker) — получение сообщений из каналов
└─ TDLibClient (External Dependency) — адаптер к TDLib
```

**Зоны ответственности:**

| Компонент | Ответственность | Тестируется |
|-----------|----------------|-------------|
| `ChannelCache` | Хранение и обновление списка каналов в памяти | Изолированно (unit tests) |
| `UpdatesHandler` | Прослушивание TDLib updates, маршрутизация событий | Изолированно (unit tests) |
| `MessageFetcher` | Получение сообщений через TDLibClient | С MockTDLibClient |
| `ChannelMessageSource` | Координация: инициализация, делегирование задач | Component test (с реальными Workers) |

**Преимущества:**
- ✅ Простота тестирования (каждый Worker изолированно)
- ✅ Переиспользование (ChannelCache можно использовать в других модулях)
- ✅ Масштабируемость (добавление функций не раздувает один класс)
- ✅ Читаемость (понятно где искать логику кэширования, где — обработку updates)

### Dependency Injection

**Правило:** Компоненты получают зависимости через `init`, не создают внутри себя.

```swift
// ❌ Плохо: создаёт зависимости внутри
actor ChannelMessageSource {
    private let cache = ChannelCache()  // Tight coupling
    private let tdlib = TDLibClient()   // Нельзя заменить на mock
}

// ✅ Хорошо: зависимости через init
actor ChannelMessageSource {
    private let cache: ChannelCache
    private let tdlib: TDLibClientProtocol  // Protocol для мокирования

    init(cache: ChannelCache, tdlib: TDLibClientProtocol) {
        self.cache = cache
        self.tdlib = tdlib
    }
}
```

**См. также:**
- `.claude/TESTING.md` → Декомпозиция при обнаружении сложности
- `.claude/TESTING.md` → Senior Architect: Проверка на архитектурные риски

---

## Architecture Decision Records (ADR)

Этот раздел содержит архитектурные решения для ключевых компонентов системы.

### ADR-001: ChannelMessageSource.fetchUnreadMessages() (2025-11-17)

**Контекст:**
Реализация получения непрочитанных сообщений из Telegram каналов для формирования дайджеста.

**Решения (по 4 блокам анализа):**

#### 1. Производительность

**Проблема:**
- Операция: `getChatHistory()` для каждого канала с непрочитанными
- Типичное количество: 10-100 каналов
- Последовательное выполнение: 50 каналов × 1 сек = **50 секунд** ⚠️

**Решение:**
- ✅ **TaskGroup для параллельного getChatHistory()**
- Ожидаемое время: ~3-5 секунд (сетевой лимит + TDLib concurrency)

**Реализация:**
```swift
try await withThrowingTaskGroup(of: [SourceMessage].self) { group in
    for chat in unreadChannels {
        group.addTask {
            try await self.fetchMessagesFromChat(chat)
        }
    }
}
```

**Обоснование:**
- Критично для UX (пользователь ждёт дайджест)
- Стандартный паттерн Swift Concurrency для сетевых запросов

#### 2. Память

**Анализ:**
- Чаты: loadChats() может вернуть 1000+ (типично 100-300)
- Каналы с непрочитанными: обычно 10-100 после фильтрации
- Сообщения на канал: limit = 100 (ограничение TDLib getChatHistory)
- Размер: 100 каналов × 10 сообщений × 5 KB = **5 MB** (приемлемо)

**Решение для MVP:**
- ✅ **НЕ нужна пагинация getChatHistory** (TDLib ограничивает max=100)
- ✅ **Пагинация loadChats УЖЕ РЕАЛИЗОВАНА** (цикл до 404)

**Post-MVP:**
- Если нужно >100 сообщений на канал → добавить пагинацию getChatHistory

#### 3. Отказоустойчивость

**Проблема:**
- getChatHistory() может упасть для отдельного канала (удалён, нет доступа)
- Вопрос: падает ли вся операция?

**Решение:**
- ✅ **Partial success с логированием**
- Если 1 из 50 каналов упал → логируем ошибку, пропускаем канал, продолжаем

**Реализация:**
```swift
group.addTask {
    do {
        return try await self.fetchMessagesFromChat(chat)
    } catch {
        // TODO: Logger.error(...)
        print("Failed to fetch from channel \(chat.title): \(error)")
        return []  // Пропускаем канал
    }
}
```

**Обоснование:**
- Частичный дайджест лучше чем полный провал
- Пользователь получает результат из доступных каналов

**Post-MVP:**
- Собирать статистику ошибок
- Алерт если >50% каналов упали (проблема с TDLib)

#### 4. Логирование

**Критичные точки:**
1. Начало: `fetchUnreadMessages() started`
2. После loadChats: `Loaded X chats from TDLib`
3. Фильтрация: `Found Y unread channels (out of X)`
4. Начало getChatHistory: `Fetching messages from Y channels (parallel)`
5. Ошибка getChatHistory: `Failed to fetch from channel {title} (chatId={id}): {error}`
6. Завершение: `Completed: Z messages from Y channels (duration={time})`

**Решение для MVP:**
- ✅ Использовать `print()` для логов (простота)
- Post-MVP: Интеграция swift-log для structured logging

**Статус:** ✅ Архитектурные решения приняты, готовы к реализации

**Тесты для проверки решений:**
- Component Test: `ChannelMessageSourceTests.fetchUnreadMessages()` (happy path)
- Component Test: `ChannelMessageSourceTests.fetchUnreadMessages_partialFailure()` (один канал упал)
- Component Test: `ChannelMessageSourceTests.fetchUnreadMessages_parallelism()` (проверка параллельности)

---

### ADR-002: TDLib Unified Background Loop (2025-11-19)

**Контекст:**
При реализации TDLibAdapter обнаружена критичная race condition: `td_json_client_receive()` возвращает ОДИН message из единой очереди, но два места вызывали его одновременно:
- Authorization loop (`processAuthorizationStates`)
- Background updates loop (`startUpdatesLoop`)

**Проблема:**
```
Thread 1: receive() → получает updateAuthorizationState
Thread 2: receive() → получает ok response
```
Результат: authorization loop ждёт state, который получил updates loop → **deadlock**.

**Решения (по 4 блокам анализа):**

#### 1. Производительность

**Анализ:**
- Операция: `td_json_client_receive(timeout)` - блокирующий C-вызов
- Частота: ~100-1000 вызовов/сек (зависит от активности TDLib)
- Критично: Минимизировать overhead маршрутизации messages

**Решение:**
- ✅ **Единый background loop** - ТОЛЬКО он вызывает `receive()`
- ✅ **NSLock вместо DispatchQueue** - минимальный overhead для thread synchronization
- ✅ **CheckedContinuation** - zero-copy передача результата в ожидающий Task

**Реализация:**
```swift
final class ResponseWaiters: @unchecked Sendable {
    private let lock = NSLock()
    private var waiters: [String: CheckedContinuation<[String: Any], Error>] = [:]

    func addWaiter(for type: String, continuation: CheckedContinuation<[String: Any], Error>) {
        lock.lock()
        waiters[type] = continuation
        lock.unlock()
    }

    func resumeWaiter(for type: String, with response: [String: Any]) -> Bool {
        lock.lock()
        let continuation = waiters.removeValue(forKey: type)
        lock.unlock()

        guard let continuation else { return false }
        nonisolated(unsafe) let unsafeResponse = response
        continuation.resume(returning: unsafeResponse)
        return true
    }
}
```

**Обоснование:**
- NSLock: ~50ns overhead (vs DispatchQueue ~1μs)
- Критично для high-frequency маршрутизации (1000+ msg/sec)

#### 2. Память

**Анализ:**
- Background loop: 1 Task на весь жизненный цикл клиента
- ResponseWaiters: Dictionary с ~5-10 активными waiters (по expectedType)
- Каждый waiter: CheckedContinuation (~64 bytes)
- Общий overhead: **<1 KB** (приемлемо)

**Решение для MVP:**
- ✅ **Маршрутизация по expectedType** (простота реализации)
- ⚠️ **Известная проблема:** При параллельных запросах одного типа (например, `messages`) continuation leaked

**Post-MVP:**
- 🔄 Использовать `@extra` field для request_id маршрутизации
- 🔄 Dictionary<RequestID, Continuation> вместо Dictionary<Type, Continuation>

**Обоснование:**
- MVP: последовательные запросы → expectedType достаточно
- Production: параллельные getChatHistory() → нужен request_id

#### 3. Отказоустойчивость

**Анализ потенциальных сбоев:**
1. TDLib вернул error вместо ожидаемого response
2. Background loop упал (Task cancellation)
3. Waiter ждёт response, который никогда не придёт (timeout)

**Решение:**

**3.1. Error handling:**
```swift
if type == "error" {
    let error = TDLibErrorResponse(code: code, message: message)
    // Пробрасываем error в первый ожидающий waiter
    // MVP: перебираем известные типы (ok, user, chats, messages, ...)
    for expectedType in ["ok", "user", "chats", "messages", "updateAuthorizationState"] {
        if responseWaiters.resumeWaiterWithError(for: expectedType, error: error) {
            break
        }
    }
}
```

**3.2. Loop cancellation:**
```swift
deinit {
    updatesContinuation?.finish()
    updatesTask?.cancel()
    responseWaiters.cancelAll()  // Отменяем все ожидающие continuations
}
```

**3.3. Authorization timeout:**
- Уже реализовано: `authorizationTimeout` (300 сек)
- Уже реализовано: `maxAuthorizationAttempts` (500 итераций)

**Статус:** ✅ Базовая отказоустойчивость реализована
**TODO (post-MVP):** Request timeout для getChatHistory/loadChats

#### 4. Логирование

**Критичные точки:**
1. Loop start: `startUpdatesLoop: background loop started`
2. Message routing: `trace` level (updateOption, decoded Update - НЕ спамить debug!)
3. Error routing: `debug` level `error response [404]: Not Found`
4. No waiter: `warning` level `no waiter for response type 'messages'`
5. Authorization states: `info` level `Authorization state: authorizationStateReady`

**Решение:**
- ✅ `trace` для high-frequency events (updateOption)
- ✅ `debug` для request/response lifecycle
- ✅ `info` для business-critical events (authorization, chats loaded)
- ✅ `warning` для unexpected states (no waiter)

**Реализация:**
```swift
// High-frequency: trace
appLogger.trace("startUpdatesLoop: received @type='\(type)'")
appLogger.trace("startUpdatesLoop: decoded Update, yielding to stream")

// Routing: debug
appLogger.debug("startUpdatesLoop: response type '\(type)', notifying waiter")

// Business logic: info
appLogger.info("Authorization state: \(stateType)")
appLogger.info("TDLib authorization READY")
```

**Статус:** ✅ Логирование очищено от спама, критичные события видны

---

**Архитектурная диаграмма:**

```
┌─────────────────────────────────────────────┐
│ Background Loop (ЕДИНСТВЕННЫЙ)              │
│                                             │
│  while !Task.isCancelled {                  │
│    guard let obj = receive(timeout: 0.1)    │  ← ТОЛЬКО ЗДЕСЬ вызывается receive()
│                                             │
│    switch obj["@type"] {                    │
│      case "error":                          │
│        → resumeWaiterWithError()            │
│      case "update*":                        │
│        → AsyncStream.yield(update)          │
│      case "ok", "user", "chats", ...:       │
│        → responseWaiters.resumeWaiter()     │  ← Будит ожидающий Task
│    }                                        │
│  }                                          │
└─────────────────────────────────────────────┘
         ▲                          │
         │                          │
         │                          ▼
┌────────┴──────────┐   ┌────────────────────┐
│ Authorization     │   │ High-Level API     │
│ Loop              │   │ (loadChats, etc.)  │
│                   │   │                    │
│ waitForResponse() │   │ waitForResponse()  │  ← Регистрируют continuation
│   @type=          │   │   @type=           │     и ЖДУТ resume
│   "updateAuth...  │   │   "ok"             │
└───────────────────┘   └────────────────────┘
```

**Ключевое решение:** Никто КРОМЕ background loop НЕ вызывает `receive()` → race condition устранён.

---

**Тесты для проверки решений:**
- ✅ Component Test: Authorization flow проходит (phone → code → 2FA → ready)
- ✅ Component Test: loadChats() работает с ошибкой 404
- ✅ Component Test: Параллельные getChatHistory() (с continuation leaked warning - известная проблема MVP)

**Статус:** ✅ Реализовано и проверено на production TDLib (2025-11-19)

**Известные ограничения (Post-MVP):**
- ⚠️ Continuation leaked при параллельных запросах одного типа
- ⚠️ Нет request timeout для getChatHistory/loadChats
- ⚠️ Маршрутизация error по expectedType (нужен @extra для точности)

---

## Зависимости

См. `Package.swift`. Основные:
- TDLib (системная библиотека через Homebrew/apt)
- swift-log 1.6.4+ (для логирования)

При добавлении новых зависимостей:
- Проверяйте совместимость со Swift 6.0
- Убедитесь, что библиотека активно поддерживается (обновления за последние 6 месяцев)
- Проверяйте кросс-платформенную поддержку (macOS + Linux)

## Документация используемых библиотек

- **TDLib**: https://core.telegram.org/tdlib/docs
  - Основные методы: `loadChats`, `getChatHistory`, `sendMessage` (через бота)
- **swift-log**: https://github.com/apple/swift-log
