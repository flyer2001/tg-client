# Задачи на рефакторинг (TODO)

## 📝 Резюме последней сессии

✅ **Сессия от 2025-10-24: Исправление сборки Xcode и рефакторинг логирования**

Успешно исправили критическую проблему с запуском проекта в Xcode, улучшили логирование и настроили конфигурацию для работы с Claude Code:

**Что сделали:**
1. **Исправили ошибку компиляции в Xcode** - добавили флаг `-parse-as-library` для executable target
2. **Исправили чтение переменных окружения** - перешли с `getenv()` на `ProcessInfo.processInfo.environment`
3. **Отключили избыточные логи TDLib** - добавили глобальные настройки логирования через `td_log.h`
4. **Добавили новый заголовок** - включили `td_log.h` в `shim.h` для доступа к функциям логирования
5. **Настроили конфигурацию проекта** - добавили CLAUDE.md, TASKS.md, DEPLOY.md и настройки для Claude Code
6. **Настроили автоматическую загрузку SSH ключа** - добавили конфигурацию в `~/.ssh/config` для GitHub
7. **✅ Исправили deprecated функции логирования** - заменили C API на современный JSON API через `td_execute()`
8. **✅ Документировали C interop механизм** - добавили подробные комментарии в shim.h и module.modulemap

**Созданные коммиты:**
- `22e43ff` - Исправлена сборка в Xcode и обработка переменных окружения
- `410113c` - Снижена детализация логирования TDLib
- `d35a010` - Добавлена конфигурация для работы с Claude Code
- `e5832a8` - Заменены deprecated функции логирования TDLib на современный API
- `1f416d2` - Обновлён статус задачи 3.3
- `b9b1be0` - Добавлена документация для C interop механизма
- `8c806ca` - Обновлён статус задачи 2.1

Все изменения запушены в `main`.

**Следующая задача:**
- **Задача 3.4** - Добавить комментарии и документацию в TDLibAdapter (объёмная задача, см. детали ниже)

---

## ✅ Задачи на следующую сессию

### 1. Рефакторинг `main.swift`

#### 1.1 Создать `EnvironmentService` абстракцию
- [ ] Создать файл `Sources/App/EnvironmentService.swift`
- [ ] Определить протокол `EnvironmentServiceProtocol`
- [ ] Реализовать `ProcessInfoEnvironmentService` для macOS/Linux
- [ ] Создать `AppConfiguration` struct для типобезопасной конфигурации
- [ ] **Решить:** оставить `stateDir` опциональным или сделать обязательным?
  - **Текущее состояние:** используется дефолтное значение `~/.tdlib` если не указан
  - **Вопрос для обсуждения:** критично ли, если пользователь не укажет путь?
- [ ] Подумать о будущей поддержке Windows/Docker (XDG paths на Linux)
  - Windows: `%USERPROFILE%\AppData\Local\tdlib`
  - Docker: `/var/lib/tdlib` или `/app/data`
  - Linux XDG: `$XDG_DATA_HOME/tdlib`

**Примечание:** Сейчас реализация для macOS и Linux одинаковая (через `ProcessInfo` и `FileManager`), но абстракция полезна для:
- Будущей поддержки других платформ
- Тестирования (можно мокнуть `EnvironmentServiceProtocol`)
- Четкого разделения ответственности

#### 1.2 Рефакторинг диалога авторизации
- [ ] Вынести логику запроса credentials в отдельный struct/class `AuthenticationDialog`
- [ ] Методы: `askPhone()`, `askCode()`, `askPassword()`
- [ ] Возможно, добавить `AuthenticationDialogProtocol` для тестирования
- [ ] Рассмотреть вариант с консольным вводом vs другие варианты (stdin, файл, и т.д.)

#### 1.3 Улучшить механизм ожидания ответа `getMe`
**Текущая проблема:**
```swift
while Date().timeIntervalSince(started) < 5 {
    if let obj = td.receive(timeout: 0.5), let type = obj["@type"] as? String {
        if type == "user" { ... }
    }
}
```
Это топорная реализация polling'а с таймаутом.

**Задачи:**
- [ ] Изучить, есть ли в TDLib нативный способ ждать конкретный ответ
- [ ] Изучить механизм `@extra` в TDLib для request-response паттерна
- [ ] Рассмотреть варианты:
  - Async continuation с timeout (`withTimeout`)
  - Использовать `AsyncStream` для обработки updates
  - Создать очередь запросов с promise/future паттерном
- [ ] Возможно, такой polling будет нужен в будущем - вынести в переиспользуемую функцию

### 2. Разобраться с C-заголовками (`shim.h`) ✅

**Статус:** Завершено в коммите `b9b1be0`

**Что сделали:**
- ✅ Изучили, как работает `module.modulemap` в Swift Package Manager
- ✅ Поняли роль `shim.h` как промежуточного заголовка (umbrella header)
- ✅ Документировали назначение каждого заголовка (td_json_client.h, td_log.h)
- ✅ Добавили подробные комментарии в `shim.h` с объяснением паттерна
- ✅ Добавили комментарии в `module.modulemap` с разбором каждой директивы
- ✅ Добавили ссылки на официальную документацию Swift и Clang

**Результат:** Механизм C interop полностью документирован в самих файлах, что упрощает понимание архитектуры для будущих разработчиков

### 3. Рефакторинг `TDLibAdapter.swift`

**Текущие проблемы:**
- Много логики в одном файле
- TDConfig определён inline
- Параметры TDLib захардкожены в коде
- Используются deprecated функции логирования
- Недостаточно комментариев для понимания работы

#### 3.1 Вынести `TDConfig` в отдельный файл
- [ ] Создать `Sources/TDLibAdapter/TDConfig.swift`
- [ ] Переместить туда struct `TDConfig`
- [ ] Добавить документацию к каждому полю:
  - `apiId`: API ID из https://my.telegram.org/apps
  - `apiHash`: API Hash из https://my.telegram.org/apps
  - `stateDir`: Директория для хранения базы данных TDLib
  - `logPath`: Путь к файлу логов TDLib

#### 3.2 Вынести параметры TDLib в константы
**Текущая проблема:**
```swift
let request: [String: Any] = [
    "@type": "setTdlibParameters",
    "use_test_dc": false,
    "database_directory": config.stateDir + "/db",
    // ... 15+ строк параметров
]
```

**Задачи:**
- [ ] Создать `Sources/TDLibAdapter/TDLibParameters.swift`
- [ ] Создать struct `TDLibParameters` с:
  - Static метод `buildParameters(from config: TDConfig) -> [String: Any]`
  - Документацией каждого параметра
- [ ] Добавить комментарий, почему используется inline формат (TDLib >= 1.8.6 требует это)
- [ ] Добавить ссылку на changelog TDLib про изменение API между версиями
- [ ] Объяснить разницу между старым форматом (nested `parameters` object) и новым (inline)

**Справка:**
- TDLib 1.8.0-1.8.5: использовали вложенный объект `parameters`
- TDLib 1.8.6+: требуют inline параметры
- Мы используем TDLib 1.8.56 (HEAD)

#### 3.3 Исправить deprecated функции логирования ✅
**Статус:** Завершено в коммите `e5832a8`

**Что сделали:**
- ✅ Изучили документацию TDLib для актуальных функций логирования
- ✅ Проверили заголовок `td_log.h` на наличие новых функций
- ✅ Заменили `td_set_log_verbosity_level()` и `td_set_log_file_path()` на `td_execute()` с JSON-запросами
- ✅ Удалили дублирующую функцию `setLog()`
- ✅ Добавили ссылку на документацию в комментарии

**Результат:** Код компилируется без warnings, используется современный рекомендуемый API

#### 3.4 Добавить комментарии и документацию
- [ ] Добавить заголовочный комментарий к файлу с описанием назначения
- [ ] Документировать класс `TDLibClient`:
  - Что это такое (Swift-обёртка над TDLib C API)
  - Как использовать
  - Thread-safety (@unchecked Sendable и почему)
- [ ] Документировать метод `start()`:
  - Объяснить async/await паттерн
  - Описать, что метод блокируется до завершения авторизации
  - Объяснить continuation и зачем нужен `onReady` callback
- [ ] Документировать `receiveLoop()`:
  - Описать state machine авторизации TDLib
  - Добавить диаграмму состояний (ASCII или ссылка на docs)
  - Объяснить каждый authorization state:
    - `authorizationStateWaitTdlibParameters`
    - `authorizationStateWaitEncryptionKey`
    - `authorizationStateWaitPhoneNumber`
    - `authorizationStateWaitCode`
    - `authorizationStateWaitPassword`
    - `authorizationStateReady`
    - `authorizationStateClosed`
- [ ] Объяснить флаг `parametersSet`:
  - Почему нужен
  - Проблема двойной отправки параметров
  - Разница между `updateAuthorizationState` и прямым ответом
- [ ] Документировать формат JSON-сообщений TDLib:
  - Структура с `@type`
  - Примеры запросов и ответов
  - Ссылка на TDLib API документацию
- [ ] Добавить inline комментарии к неочевидным местам:
  - `await Task.yield()` - зачем нужен
  - `@unchecked Sendable` - почему безопасно

#### 3.5 Рассмотреть разделение на несколько файлов
Если после рефакторинга файл всё ещё большой, рассмотреть разделение:
- [ ] `TDLibClient.swift` - основной класс
- [ ] `TDLibClient+Authorization.swift` - extension с логикой авторизации
- [ ] `TDLibClient+Logging.swift` - extension с настройкой логирования

#### 3.6 Типизация запросов и ответов TDLib (Type-Safe API)

**Текущая проблема:**
Сейчас используем `[String: Any]` для запросов и ответов, что:
- Приводит к опечаткам в именах полей
- Нет автодополнения в IDE
- Нет проверки типов на этапе компиляции
- Нужно вручную проверять наличие полей через `as?`

**Задачи:**

- [ ] **Создать базовый протокол для запросов**
  ```swift
  protocol TDLibRequest: Encodable {
      static var type: String { get }
  }
  ```

- [ ] **Создать структуры для каждого типа запроса** (начать с используемых):
  - [ ] `SetLogVerbosityLevel` - https://core.telegram.org/tdlib/docs/classtd_1_1td__api_1_1set_log_verbosity_level.html
  - [ ] `GetAuthorizationState` - https://core.telegram.org/tdlib/docs/classtd_1_1td__api_1_1get_authorization_state.html
  - [ ] `SetTdlibParameters` - https://core.telegram.org/tdlib/docs/classtd_1_1td__api_1_1set_tdlib_parameters.html
  - [ ] `CheckDatabaseEncryptionKey`
  - [ ] `SetAuthenticationPhoneNumber`
  - [ ] `CheckAuthenticationCode`
  - [ ] `CheckAuthenticationPassword`
  - [ ] `GetMe`
  - Каждая структура содержит ссылку на официальную документацию в комментарии

- [ ] **Создать JSON-билдер для запросов**
  - [ ] Создать `Sources/TDLibAdapter/TDLibRequestEncoder.swift`
  - [ ] Метод `encode<T: TDLibRequest>(_ request: T) throws -> [String: Any]`
  - [ ] Автоматически добавляет поле `@type` из `T.type`
  - [ ] Использует JSONEncoder для сериализации

- [ ] **Создать базовый протокол для ответов**
  ```swift
  protocol TDLibResponse: Decodable {
      static var type: String { get }
  }
  ```

- [ ] **Создать структуры Response для типизации ответов**:
  - [ ] `User` - ответ на getMe
  - [ ] `Error` - общая структура ошибки TDLib
  - [ ] `AuthorizationState` с enum для всех состояний
  - [ ] Response для каждого типа update (начать с используемых)

- [ ] **Обновить метод `send()` для использования типизированных запросов**:
  - [ ] Убрать `try!` - заменить на `throws`
  - [ ] Добавить перегрузку `send<T: TDLibRequest>(_ request: T) throws`
  - [ ] Логировать ошибки сериализации с контекстом

- [ ] **Обновить метод `receive()` для типизированных ответов**:
  - [ ] Добавить перегрузку `receive<T: TDLibResponse>(timeout: Double) throws -> T?`
  - [ ] Автоматическая десериализация в нужный тип

**Пример использования (после рефакторинга):**
```swift
// Вместо:
client.send(["@type": "getMe"])

// Будет:
try client.send(GetMe())

// Вместо:
if let obj = client.receive(timeout: 5.0),
   let type = obj["@type"] as? String,
   type == "user" {
    let firstName = obj["first_name"] as? String
}

// Будет:
if let user: User = try client.receive(timeout: 5.0) {
    print(user.firstName)
}
```

#### 3.7 Рефакторинг для тестируемости (Dependency Injection)

**Текущая проблема:**
Код жёстко привязан к C API TDLib, что делает невозможным:
- Unit-тестирование логики авторизации без реального подключения
- Мокирование TDLib для тестов
- Изолированное тестирование каждого состояния авторизации
- TDD-подход для нового функционала

**Задачи:**

- [ ] **Создать протокол для абстракции над TDLib**
  ```swift
  protocol TDLibClientProtocol {
      func send(_ json: [String: Any])
      func receive(timeout: Double) -> [String: Any]?
  }
  ```

- [ ] **Разделить ответственность на слои**:
  - [ ] `TDLibClient` - низкоуровневая обёртка над C API (реализует `TDLibClientProtocol`)
  - [ ] `TDLibAuthorizationHandler` - высокоуровневая логика авторизации
  - [ ] Принимает `TDLibClientProtocol` через DI

- [ ] **Создать Mock для тестов**:
  ```swift
  class MockTDLibClient: TDLibClientProtocol {
      var responses: [[String: Any]] = []
      var sentRequests: [[String: Any]] = []

      func send(_ json: [String: Any]) {
          sentRequests.append(json)
      }

      func receive(timeout: Double) -> [String: Any]? {
          return responses.isEmpty ? nil : responses.removeFirst()
      }
  }
  ```

- [ ] **Покрыть тестами после рефакторинга**:
  - [ ] Каждое состояние авторизации (6 states)
  - [ ] Обработка ошибок TDLib
  - [ ] Edge cases: 2FA включен/выключен
  - [ ] Таймауты и повторные попытки
  - [ ] Флаг `parametersSet` (двойная отправка)

**Приоритет:** Medium (делать после базовых рефакторингов 3.4-3.7)

#### 3.8 Рефакторинг метода авторизации

**Текущие проблемы:**
- `receiveLoop()` - название не отражает что метод только для авторизации
- Хардкод `timeout: 1.0` - важный параметр без возможности управления
- Слишком большая вложенность и развилки для обработки состояний
- `askPassword` не опциональный, хотя 2FA может быть не включен

**Задачи:**

- [ ] **Переименовать `receiveLoop()` → `authorizeAndWaitForReady()`**
  - Название должно явно отражать назначение метода

- [ ] **Вынести хардкод timeout в константу/параметр**:
  - [ ] Добавить `private let authorizationPollTimeout: Double = 1.0` в класс
  - [ ] Или сделать параметром конфига: `TDConfig.authPollTimeout`
  - [ ] Добавить комментарий почему выбран этот timeout

- [ ] **Сделать `askPassword` опциональным параметром**:
  ```swift
  public func start(
      config: TDConfig,
      askPhone: @escaping @Sendable () async -> String,
      askCode: @escaping @Sendable () async -> String,
      askPassword: (@Sendable () async -> String)? = nil
  ) async
  ```
  - Если пользователь не передал колбэк и TDLib запросил пароль - логировать ошибку

- [ ] **Упростить вложенность в методе авторизации**:
  - [ ] Вынести обработку каждого состояния в отдельный метод:
    - `handleWaitTdlibParameters(config:)`
    - `handleWaitEncryptionKey()`
    - `handleWaitPhoneNumber(askPhone:)`
    - `handleWaitCode(askCode:)`
    - `handleWaitPassword(askPassword:)`
  - [ ] Использовать guard/early return вместо глубокой вложенности
  - [ ] Создать enum `AuthorizationState` вместо строковых сравнений

- [ ] **Улучшить обработку ошибок**:
  - [ ] Если `askPassword == nil` но TDLib запросил пароль - выбросить ошибку
  - [ ] Добавить таймаут на всю авторизацию (например, 5 минут)
  - [ ] Логировать все переходы между состояниями на уровне debug

---

### 4. Настройка мониторинга и продакшен-инфраструктуры

#### 4.1 Базовый мониторинг (MVP для продакшена)

**Heartbeat механизм**
- [ ] Реализовать запись timestamp в файл `~/.tdlib/heartbeat` при каждом запуске основного цикла
  - Что это: простой индикатор что бот "жив" и не завис
  - Как работает: при каждой итерации (например, каждые 5-10 минут) бот записывает текущий Unix timestamp в файл
  - Зачем: процесс может быть запущен, но завис на каком-то шаге - heartbeat это обнаружит

**Health check скрипт**
- [ ] Создать bash-скрипт `/usr/local/bin/tg-client-healthcheck.sh`
  - Проверяет существование процесса tg-client
  - Проверяет что heartbeat файл обновлялся в последние 30 минут
  - Проверяет использование памяти (предупреждение если > 80% от лимита)
  - При проблемах отправляет alert в Telegram через Bot API

**Telegram Self-Monitoring**
- [ ] Настроить отправку уведомлений через Bot API
  - При старте сервиса: "✅ tg-client started"
  - При критических ошибках: "❌ Critical error: {message}"
  - При остановке (graceful shutdown): "🛑 tg-client stopped"

**Автоматизация проверок**
- [ ] Настроить cron задачу для периодического запуска healthcheck
  ```bash
  */5 * * * * /usr/local/bin/tg-client-healthcheck.sh
  ```
  - Запускается каждые 5 минут
  - Проверяет heartbeat и статус процесса
  - Отправляет alert если что-то не так

**Ротация логов**
- [ ] Настроить logrotate для автоматической ротации логов
  - Что это: автоматическое архивирование старых логов чтобы они не занимали весь диск
  - Как работает: каждый день создается новый лог-файл, старые сжимаются (gzip)
  - Зачем: без ротации логи растут бесконечно и могут заполнить диск
  - Конфигурация: хранить 7 дней логов, сжимать старые файлы
  - Пример: `app.log` (сегодня, 10MB) → `app.log.1.gz` (вчера, 2MB сжатый)

**Structured Logging**
- [ ] Добавить structured logging в формате JSON для легкого парсинга
  ```swift
  logger.info("Processing unread chats", metadata: [
      "chat_count": "\(count)",
      "timestamp": "\(Date())"
  ])
  ```
  - Легко парсить автоматически
  - Удобно для будущей интеграции с Grafana/Loki

#### 4.2 Продвинутый мониторинг (для будущего масштабирования)

**HTTP Health Endpoint**
- [ ] Добавить mini HTTP-сервер на порт 8080
  - `GET /health` → JSON с статусом сервиса
  - `GET /metrics` → Prometheus-совместимые метрики
  - Позволит использовать внешние мониторинги (UptimeRobot, Better Uptime)

**Metrics в файл**
- [ ] Экспорт метрик в простой текстовый формат
  - Количество обработанных чатов
  - Время обработки
  - Использование памяти
  - Готовит почву для Prometheus

**Веб-интерфейс для логов (опционально)**
- [ ] Исследовать варианты просмотра логов через браузер:
  - **Простой вариант:** lnav в терминале (TUI с поиском и фильтрацией)
  - **Средний вариант:** Dozzle (если будет использоваться Docker)
  - **Продвинутый вариант:** Grafana Loki
    - Promtail → читает логи и отправляет в Loki
    - Loki → хранит и индексирует логи
    - Grafana → показывает в веб-интерфейсе с поиском и фильтрами
  - **Рекомендация:** начать с lnav и journalctl, переходить к Grafana только при необходимости

**Grafana + Prometheus (если потребуется)**
- [ ] Настроить сбор метрик через Prometheus
- [ ] Создать дашборд в Grafana для визуализации
- [ ] Настроить алерты на основе метрик

**Примечание:** Задачи из 4.2 **НЕ приоритетны** на старте. Начать с 4.1 (базовый мониторинг).

---

## 📌 Приоритеты

**High Priority (сделать в первую очередь):**
1. ✅ ~~Исправить deprecated функции логирования (3.3)~~ - Завершено
2. ✅ ~~Разобраться с shim.h (2.1)~~ - Завершено
3. ✅ ~~Вынести TDConfig (3.1)~~ - Завершено
4. ✅ ~~Добавить README.md в TDLibAdapter~~ - Завершено
5. **Добавить комментарии в TDLibAdapter (3.4)** - почти готово
6. **Сделать askPassword опциональным (3.8)** - быстро исправить
7. **Рефакторинг метода авторизации (3.8)** - упростить вложенность и переименовать

**Medium Priority:**
8. **Рефакторинг для тестируемости (3.7)** - DI и протоколы для unit-тестов
9. **Типизация запросов и ответов (3.6)** - type-safe API (большая задача)
10. Вынести TDLib параметры (3.2) - делает код чище
11. Создать EnvironmentService (1.1) - хорошая архитектура

**Low Priority (можно отложить):**
11. Рефакторинг AuthenticationDialog (1.2) - косметика
12. Улучшить polling getMe (1.3) - работает, но не красиво
13. Разделение на несколько файлов (3.5) - делать после других рефакторингов

---

## 🤔 Вопросы для обсуждения

1. **stateDir в EnvironmentService**: оставить опциональным с дефолтом или сделать обязательным?
2. **Платформы**: планируется ли поддержка Windows в будущем?
3. **Логирование**: нужно ли добавлять уровни логирования (debug mode)?
4. **Тестирование**: планируется ли писать unit-тесты? (влияет на выбор архитектуры)

---

**Дата создания:** 2025-10-19
**Последнее обновление:** 2025-10-25
