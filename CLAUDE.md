# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

---

**🚀 НАЧАЛО НОВОЙ СЕССИИ:**
При запуске новой сессии Claude Code **ОБЯЗАТЕЛЬНО** прочитай файл [TASKS.md](TASKS.md) и предложи продолжить работу над задачами оттуда. Этот файл содержит актуальный список TODO и контекст предыдущих сессий.

---

**📋 РАЗВЕРТЫВАНИЕ:** Для развертывания на Linux-сервере смотри [DEPLOY.md](DEPLOY.md) - там полная инструкция по установке Swift, TDLib, настройке systemd и отладке.

---

## Цель проекта

Это терминальный Telegram-клиент без UI для автоматизации работы с непрочитанными чатами.

**Основной сценарий работы:**
1. Клиент логинится через мой аккаунт
2. Получает непрочитанные сообщения из чатов
3. Составляет саммари через AI-агента (OpenAI/Anthropic)
4. Отправляет результат мне через чат-бота

**Требования к разработке:**
- Разработка ведётся на macOS, но релизная версия должна работать на Linux-сервере — обеспечить кросс-платформенную совместимость
- Обязательно продумать систему логирования для отслеживания прогресса и ошибок на каждом этапе
- Следовать TDD-подходу: сначала тесты, затем реализация
- Все новые внешние библиотеки должны быть актуальными (работать с Swift 6.0), с обновлениями не старше полугода

### Планируемые модули

1. **ChatFetcher** (получение непрочитанных чатов)
   - Использует TDLibAdapter для запросов к Telegram API
   - Фильтрует чаты по критерию «есть непрочитанные сообщения»
   - Возвращает структурированный список чатов с метаданными

2. **SummaryGenerator** (составление саммари)
   - Интегрируется с внешним AI API (например, OpenAI/Anthropic)
   - Принимает массив сообщений, возвращает краткое резюме
   - Обрабатывает ошибки API и таймауты

3. **BotNotifier** (отправка через бота)
   - Использует Telegram Bot API для отправки сообщений
   - Форматирует саммари в удобочитаемый вид (Markdown)
   - Логирует успешные отправки

4. **Logger** (система логирования)
   - Унифицированный интерфейс для всех модулей
   - Поддержка уровней: debug, info, warning, error
   - Вывод в консоль (разработка) и файл (продакшн)
   - Ротация логов на Linux-сервере

### Правила разработки

- **Тесты первыми**: Для каждого нового модуля сначала создаём `Tests/<Module>Tests/<Module>Tests.swift` с базовыми кейсами, затем пишем реализацию.
- **Работа с ветками**: Для каждой новой задачи создаём отдельную feature-ветку (например, `feature/chat-fetcher` или `fix/xcode-build`). Работаем в ней до полного завершения задачи и прохождения всех тестов. Только после этого мержим в `main`. Это позволяет держать `main` всегда в рабочем состоянии и облегчает code review.
  ```bash
  # Создание новой ветки для задачи
  git checkout -b feature/task-name

  # После завершения работы и прохождения тестов
  git push -u origin feature/task-name
  # Создаём Pull Request через GitHub CLI или веб-интерфейс
  ```
- **Кросс-платформенная проверка**: Используем `#if os(macOS)` / `#if os(Linux)` только там, где неизбежно. Регулярно собираем проект на Linux через Docker:
  ```bash
  docker run --rm -v $(pwd):/code swift:6.0 bash -c "cd /code && swift build"
  ```
- **Логирование на каждом шаге**: Перед любой операцией с внешним API (Telegram, AI, Bot) — лог типа `logger.info("Fetching unread chats...")`. После операции — `logger.info("Fetched \(count) chats")` или `logger.error("Failed to fetch: \(error)")`.
- **Обработка ошибок**: Все сетевые вызовы оборачиваем в `do-catch`, используем кастомные enum-ошибки (`enum ChatFetcherError: Error`).

## Предварительные требования

Проект требует установки TDLib и pkg-config в системе:
- macOS:
  ```bash
  brew install tdlib pkg-config
  ```
- Linux:
  ```bash
  apt install libtdjson-dev pkg-config
  ```

## Настройка окружения

Перед запуском приложения установите переменные окружения:
```bash
export TELEGRAM_API_ID=<your_api_id>
export TELEGRAM_API_HASH=<your_api_hash>
export TDLIB_STATE_DIR=~/.tdlib  # Опционально, по умолчанию ~/.tdlib

# ВАЖНО для macOS: указываем путь к pkg-config файлам TDLib
export PKG_CONFIG_PATH="/opt/homebrew/opt/tdlib/lib/pkgconfig:$PKG_CONFIG_PATH"
```

API credentials можно получить на https://my.telegram.org/apps

**Для постоянной настройки** добавьте эти переменные в `~/.zshrc` или `~/.bash_profile`:
```bash
echo 'export PKG_CONFIG_PATH="/opt/homebrew/opt/tdlib/lib/pkgconfig:$PKG_CONFIG_PATH"' >> ~/.zshrc
```

## SSH доступ к продакшен-серверу

Продакшен-сервер настроен в `~/.ssh/config` для автоматического подключения:

```bash
# Подключение к серверу (используется алиас из SSH config)
ssh ufohosting

# Или напрямую
ssh root@45.8.145.191
```

**Настройка SSH-ключа (уже выполнено):**
- SSH-ключ: `~/.ssh/ufohosting`
- Автозагрузка ключа настроена через `UseKeychain yes` в `~/.ssh/config`
- После перезагрузки macOS ключ загружается автоматически при первом использовании

**Проверка автозагрузки после перезагрузки:**
```bash
# Проверить загруженные ключи
ssh-add -l

# Если ключ не загружен, добавить вручную (современный синтаксис)
ssh-add --apple-use-keychain ~/.ssh/ufohosting
```

## Основные команды

**💡 Примечание:** Команды ниже для разработки на macOS. Для продакшен-развертывания на Linux см. [DEPLOY.md](DEPLOY.md)

### Сборка
```bash
# Убедитесь, что PKG_CONFIG_PATH установлен (см. "Настройка окружения")
swift build

# Продакшен-сборка (оптимизированная)
swift build -c release
```

### Запуск
```bash
# Разработка (с логами)
swift run tg-client

# Продакшен (без логов в терминале)
swift run tg-client 2>/dev/null

# С сохранением логов в файл
swift run tg-client 2>app.log
```

### Тесты
```bash
swift test
```

### Запуск конкретного теста
```bash
swift test --filter TelegramCoreTests
```

### Сборка в Docker (проверка Linux-совместимости)
```bash
docker run --rm -v $(pwd):/code swift:6.0 bash -c "cd /code && swift build"
```

## Частые проблемы

### Ошибка: 'td/telegram/td_json_client.h' file not found

**Причина**: Swift Package Manager не может найти заголовочные файлы TDLib.

**Решение**:
1. Убедитесь, что TDLib установлен: `brew list tdlib` (macOS)
2. Установите pkg-config: `brew install pkg-config` (macOS)
3. Установите переменную окружения:
   ```bash
   export PKG_CONFIG_PATH="/opt/homebrew/opt/tdlib/lib/pkgconfig:$PKG_CONFIG_PATH"
   ```

### Ошибка: argument 'dependencies' must precede argument 'path'

**Причина**: Неправильный порядок параметров в Package.swift для `.testTarget()`.

**Решение**: В Package.swift параметр `dependencies` должен идти перед `path`:
```swift
.testTarget(
    name: "TelegramCoreTests",
    dependencies: ["TelegramCore"],  // dependencies первым
    path: "Tests/TelegramCoreTests"
)
```

### Предупреждения о Sendable в Swift 6

**Причина**: Swift 6 включает строгую проверку concurrency.

**Решение**:
- Структуры данных должны соответствовать `Sendable` протоколу
- Closures, передаваемые между потоками, должны быть помечены как `@Sendable`
- Классы с mutable state используют `@unchecked Sendable` с ручным управлением синхронизацией

### Проблемы на Linux-сервере

**См. [DEPLOY.md](DEPLOY.md)** для решения проблем специфичных для Linux:
- Различия в установке TDLib (apt vs brew)
- Различия в pkg-config путях
- Настройка systemd для автозапуска
- Мониторинг и логирование на продакшене

## Архитектура

### Трёхслойная структура

1. **CTDLib (System Library)**: Swift-биндинги к нативному C API TDLib через module map
   - `Sources/CTDLib/shim.h`: Включает `td_json_client.h`
   - `Sources/CTDLib/module.modulemap`: Определяет системный модуль и линкует `libtdjson`

2. **TDLibAdapter (Middle Layer)**: Swift-обёртка над CTDLib, которая обрабатывает:
   - Жизненный цикл TDLib клиента (create/destroy)
   - JSON-коммуникацию с TDLib (методы `send`/`receive`)
   - State machine для процесса авторизации (обработка запросов телефона, кода, 2FA пароля)
   - Фоновый receive loop на выделенной dispatch queue
   - Конфигурацию логирования

   Ключевой тип: `TDLibClient` - основной интерфейс для взаимодействия с TDLib

3. **App (Executable)**: CLI-приложение, которое:
   - Читает credentials из переменных окружения
   - Предоставляет консольные промпты для авторизации
   - Демонстрирует базовое использование (логин и верификация через `getMe`)

### Паттерн коммуникации с TDLib

- Вся коммуникация использует JSON-словари с полем `@type`
- `send()` - асинхронный запрос к TDLib
- `receive(timeout:)` - блокирующий вызов для получения обновлений/ответов
- Авторизация использует паттерн state machine через обновления `updateAuthorizationState`

### Поток авторизации

Адаптер автоматически обрабатывает эти состояния:
1. `authorizationStateWaitTdlibParameters` → отправляет конфигурацию приложения
2. `authorizationStateWaitPhoneNumber` → запрашивает телефон
3. `authorizationStateWaitCode` → запрашивает SMS/app код
4. `authorizationStateWaitPassword` → запрашивает 2FA пароль (если включен)
5. `authorizationStateReady` → сигнализирует готовность через callback

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

## Стиль кода

- Отступы: 4 пробела
- Naming: camelCase для переменных, PascalCase для типов
- Асинхронность: Swift Concurrency (async/await) для сетевых вызовов
- Комментарии: на русском языке для бизнес-логики, на английском для технических деталей
- Обработка ошибок: используем кастомные enum с associated values для контекста

## Git коммиты

- Сообщения коммитов на русском языке
- **НЕ добавлять** "Generated with Claude Code" или "Co-Authored-By: Claude"
- Формат: краткое описание, затем список изменений через дефис
- Коммитить логически связанные изменения вместе
- **ВАЖНО: Разделяй коммиты:**
  - Изменения в коде (Sources/, Tests/) - отдельный коммит
  - Изменения в документации (CLAUDE.md, DEPLOY.md, TASKS.md) - отдельный коммит
  - Это упрощает code review и позволяет откатывать изменения независимо
