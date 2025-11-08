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
- **Context**: какая операция выполнялась (getChats, summarize, sendNotification)

**TDLib ошибки:** См. https://core.telegram.org/api/errors

---

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
  - Основные методы: `getChats`, `getChatHistory`, `sendMessage` (через бота)
- **swift-log**: https://github.com/apple/swift-log
