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

Все изменения запушены в `main`.

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

---

## 📌 Приоритеты

**High Priority (сделать в первую очередь):**
1. ✅ ~~Исправить deprecated функции логирования (3.3)~~ - Завершено
2. ✅ ~~Разобраться с shim.h (2.1)~~ - Завершено
3. Добавить комментарии в TDLibAdapter (3.4) - для понимания кода

**Medium Priority:**
4. Вынести TDConfig (3.1) - улучшает структуру
5. Вынести TDLib параметры (3.2) - делает код чище
6. Создать EnvironmentService (1.1) - хорошая архитектура

**Low Priority (можно отложить):**
7. Рефакторинг AuthenticationDialog (1.2) - косметика
8. Улучшить polling getMe (1.3) - работает, но не красиво

---

## 🤔 Вопросы для обсуждения

1. **stateDir в EnvironmentService**: оставить опциональным с дефолтом или сделать обязательным?
2. **Платформы**: планируется ли поддержка Windows в будущем?
3. **Логирование**: нужно ли добавлять уровни логирования (debug mode)?
4. **Тестирование**: планируется ли писать unit-тесты? (влияет на выбор архитектуры)

---

**Дата создания:** 2025-10-19
**Последнее обновление:** 2025-10-24
