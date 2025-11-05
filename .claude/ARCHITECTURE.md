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
