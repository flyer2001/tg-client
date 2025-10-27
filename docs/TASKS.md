# Задачи проекта

> 📝 **История изменений:** см. [CHANGELOG.md](CHANGELOG.md)
> 📋 **Последнее обновление:** 2025-10-26

---

## 🎯 Следующая сессия (топ-3 приоритета)

1. **[3.6] Типизация запросов и ответов TDLib** - type-safe API вместо `[String: Any]`
2. **[3.4] Добавить комментарии в TDLibAdapter** - документация классов и методов
3. **[3.7] Рефакторинг для тестируемости** - DI, протоколы, mock-объекты

---

## 📊 High Priority

### 3.6 Типизация запросов и ответов TDLib (Type-Safe API)

**Проблема:** Используем `[String: Any]` - нет type-safety, автодополнения, возможны опечатки.

**Задачи:**
- [ ] Создать протоколы `TDLibRequest`, `TDLibResponse`
- [ ] Создать структуры для запросов: `GetMe`, `SetTdlibParameters`, `CheckAuthenticationCode` и др.
- [ ] Создать структуры для ответов: `User`, `Error`, `AuthorizationState`
- [ ] Создать `TDLibRequestEncoder` для сериализации
- [ ] Обновить методы `send()` и `receive()` для работы с типизированными объектами

**Ссылки:**
- [Подробное описание](CHANGELOG.md#2025-10-26-утро)

---

### 3.4 Добавить комментарии и документацию в TDLibAdapter

**Задачи:**
- [ ] Документировать класс `TDLibClient` (назначение, thread-safety, использование)
- [ ] Документировать метод `start()` (async/await, continuation)
- [ ] Документировать `processAuthorizationStates()` (state machine, диаграмма)
- [ ] Объяснить формат JSON-сообщений TDLib
- [ ] Inline комментарии к неочевидным местам (`await Task.yield()`, `@unchecked Sendable`)

---

### 3.7 Рефакторинг для тестируемости (Dependency Injection)

**Проблема:** Код привязан к C API, невозможно unit-тестирование.

**Задачи:**
- [ ] Создать протокол `TDLibClientProtocol`
- [ ] Разделить на слои: `TDLibClient` (C API) + `TDLibAuthorizationHandler` (логика)
- [ ] Создать `MockTDLibClient` для тестов
- [ ] Покрыть тестами состояния авторизации, ошибки, edge cases

---

## 📋 Normal Priority

### 3.2 Вынести параметры TDLib в константы

- [ ] Создать `Sources/TDLibAdapter/TDLibParameters.swift`
- [ ] Static метод `buildParameters(from config: TDConfig) -> [String: Any]`
- [ ] Документация каждого параметра + объяснение inline формата (TDLib 1.8.6+)

---

### 1.1 Создать EnvironmentService абстракцию

- [ ] Протокол `EnvironmentServiceProtocol`
- [ ] `ProcessInfoEnvironmentService` для macOS/Linux
- [ ] `AppConfiguration` struct для типобезопасной конфигурации
- [ ] Решить: `stateDir` опциональный или обязательный?
- [ ] Подумать о Windows/Docker поддержке (XDG paths)

---

### 4.1 Базовый мониторинг (MVP для продакшена)

- [ ] Heartbeat механизм (запись timestamp в файл)
- [ ] Health check скрипт (`/usr/local/bin/tg-client-healthcheck.sh`)
- [ ] Telegram Self-Monitoring (уведомления через Bot API)
- [ ] Cron задача для healthcheck
- [ ] Logrotate для ротации логов
- [ ] Structured logging (JSON формат)

---

## 💡 Low Priority

### 3.5 Разделение TDLibAdapter на несколько файлов

- [ ] `TDLibClient.swift` - основной класс
- [ ] `TDLibClient+Authorization.swift` - extension с логикой авторизации
- [ ] `TDLibClient+Logging.swift` - extension с настройкой логирования

---

### 1.2 Рефакторинг диалога авторизации

- [ ] Вынести логику запроса credentials в `AuthenticationDialog`
- [ ] Методы: `askPhone()`, `askCode()`, `askPassword()`
- [ ] `AuthenticationDialogProtocol` для тестирования

---

### 1.3 Улучшить механизм ожидания ответа `getMe`

**Проблема:** Топорная реализация polling'а с таймаутом.

- [ ] Изучить механизм `@extra` в TDLib для request-response паттерна
- [ ] Рассмотреть варианты: async continuation, `AsyncStream`, promise/future
- [ ] Вынести polling в переиспользуемую функцию

---

### 3.9 Автоматическая кодогенерация из TL схемы

**Цель:** Генератор Swift кода из `td_api.tl` для масштабирования типизации.

- [ ] Исследовать существующие решения (TDLibKit, TDLib-iOS)
- [ ] Создать минимальный TL парсер
- [ ] Генератор Swift кода (Request/Response types)
- [ ] Выборочная генерация через конфиг `tl-generator.yml`
- [ ] Интеграция с билд-процессом (SPM plugin)

**Зависимости:** Требует завершения 3.6 (базовая типизация)

---

### 4.2 Продвинутый мониторинг

- [ ] HTTP Health Endpoint (порт 8080)
- [ ] Metrics в файл для Prometheus
- [ ] Веб-интерфейс для логов (lnav → Grafana Loki)

**Примечание:** Делать после 4.1

---

### Локализация приложения

- [ ] Централизованная система перевода (промпты, ошибки)
- [ ] Варианты: Swift enum/struct, .strings файлы, JSON/YAML

---

## ✅ Завершенные фичи

### 2. C-заголовки (`shim.h`) ✅

**Статус:** Завершено 2025-10-24
**Коммит:** `b9b1be0`

Полностью документирован механизм C interop для TDLib.

**Детали:** [CHANGELOG.md](CHANGELOG.md#2025-10-24)

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

1. **stateDir**: оставить опциональным с дефолтом `~/.tdlib` или сделать обязательным?
2. **Windows**: планируется ли поддержка Windows в будущем?
3. **Логирование**: добавлять уровни (debug mode)?
4. **Тестирование**: планируется ли писать unit-тесты? (влияет на архитектуру)

---

**Дата создания:** 2025-10-19
**Последнее обновление:** 2025-10-26
