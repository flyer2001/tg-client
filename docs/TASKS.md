# Задачи проекта

## 🚀 Инструкции для новой сессии

**При запуске новой сессии:**
1. Прочитай топ-3 приоритета ниже
2. Предложи продолжить работу с фокусом на MVP
3. При необходимости (если задача неясна) — посмотри детали в [MVP.md](MVP.md)
4. **TDD обязателен**: пиши тесты ДО реализации (см. [TESTING.md](TESTING.md))

**Перед завершением сессии:**
- Обнови статус задач в этом файле
- **Актуализируй Swift-DocC документацию** (при добавлении новых модулей/компонентов, см. DEV-1)
- Запиши выполненные задачи в [CHANGELOG.md](CHANGELOG.md) (только prepend через bash)
- Если нужно — добавь идеи в [IDEAS.md](IDEAS.md)

---

> 🎯 **MVP (цели и scope):** [MVP.md](MVP.md) — читать по требованию (большой файл)
> 💡 **Будущие фичи:** [IDEAS.md](IDEAS.md) — бэклог для версий после MVP
> 📝 **История изменений:** [CHANGELOG.md](CHANGELOG.md) — логи завершенных сессий
> 📋 **Последнее обновление:** 2025-10-30

---

## 🎯 Следующая сессия (топ-3 приоритета)

1. **[DEV-3] Рефакторинг TDLibAdapter: High-Level API** 🚫🔥 - КРИТИЧНО! Блокирует component-тесты и MVP-1 (~3-5 часов)
2. **[DEV-2] Публичный репозиторий** 🔥 - Обновить README.md и docs/, подготовить beta релиз (~1 час)
3. **[MVP-1.5] Типизация TDLib методов** 🔥 - Chat, Message, GetChats, GetChatHistory, ViewMessages

> **См. детали:**
> - [DEV-3: Рефакторинг TDLib](#dev-3-рефакторинг-tdlibadapter-high-level-api--критический-приоритет) — план high-level API (следующая сессия!)
> - [REFACTORING_TDLIB_HIGH_LEVEL_API.md](REFACTORING_TDLIB_HIGH_LEVEL_API.md) — подробный план рефакторинга
> - [DEV-1: Документация](#dev-1-swift-docc-documentation--высокий-приоритет) — организация тестов и навигации
> - [MVP.md — TDLib API](MVP.md#tdlib-api-работа-с-непрочитанными-сообщениями) — детали работы с TDLib

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
- [x] **0.5a: GitHub Actions CI** ✅
  - [x] Создать `.github/workflows/linux-build.yml`
  - [x] Настроить job на Linux (ubuntu-24.04)
  - [x] Установка Swift toolchain + TDLib (с кэшированием)
  - [x] Запуск `swift build` и `swift test` (с workaround для SwiftPM hangs)
  - [ ] Проверка что workflow работает (запуск/просмотр логов) - требует проверки в браузере
- [x] **0.5b: Manual VPS/Docker проверка** ✅ (сборка работает, авторизация успешна; см. заметку о SwiftPM в [DEPLOY.md](DEPLOY.md))
  - [x] Создать Linux окружение (VPS или Docker)
  - [x] Установить Swift + TDLib на Linux
  - [x] Запустить `swift build && swift test`
  - [x] Запустить `scripts/manual_e2e_auth.sh`
  - [x] Документировать процесс в [DEPLOY.md](DEPLOY.md) (секция Linux Setup)

**Примечание:** Component-тесты для авторизации откладываем (требуют рефакторинга 3.7 с DI/протоколами).

---

### DEV-3. Рефакторинг TDLibAdapter: High-Level API (🔥 КРИТИЧЕСКИЙ ПРИОРИТЕТ)

**Цель:** Перевести TDLibAdapter с низкоуровневого `send/receive` API на высокоуровневый типобезопасный API.

**Зачем:**
- 🚫 **Блокирует DEV-1.4** (component-тесты авторизации) - нужен MockTDLibClient
- 🚫 **Блокирует MVP-1** (ChannelMessageSource) - нужны методы `getChats()`, `getChatHistory()`
- 🚫 **Стопорит написание новых фич** - текущий send/receive API неудобен и сложно тестируется

**Проблемы текущей архитектуры:**
1. Сложно тестировать (нужно мокать JSON строки)
2. Нет типобезопасности (`receive()` возвращает `[String: Any]?`)
3. Цикл авторизации с вручную парсингом JSON (~150 строк)
4. Невозможны component-тесты без реального TDLib

**Целевая архитектура:**
```swift
protocol TDLibClientProtocol {
    func setAuthenticationPhoneNumber(_ phone: String) async throws -> AuthorizationStateUpdate
    func checkAuthenticationCode(_ code: String) async throws -> AuthorizationStateUpdate
    // + другие методы
}
```

**📋 Подробный план:** См. [REFACTORING_TDLIB_HIGH_LEVEL_API.md](REFACTORING_TDLIB_HIGH_LEVEL_API.md)

#### Задачи (по TDD):

**Фаза 1: Протокол и Mock (1-2 часа)**
- [ ] **3.1a RED:** Написать component-тест `AuthenticationFlowTests.swift` с желаемым API
- [ ] **3.1b GREEN:** Создать `TDLibClientProtocol.swift` с high-level методами
- [ ] **3.1c GREEN:** Создать `MockTDLibClient.swift` для тестов (stub responses)
- [ ] **3.1d GREEN:** Создать `MockLogger.swift` для проверки логов
- [ ] **3.1e REFACTOR:** Добавить conformance `TDLibClient: TDLibClientProtocol` (stub methods)
- [ ] **3.1f:** Проверить компиляцию теста

**Фаза 2: Реализация (2-3 часа)**
- [ ] **3.2a GREEN:** Реализовать `waitForAuthorizationUpdate()` helper (использует TDLibUpdate enum)
- [ ] **3.2b GREEN:** Реализовать `setAuthenticationPhoneNumber()`
- [ ] **3.2c GREEN:** Реализовать `checkAuthenticationCode()`
- [ ] **3.2d GREEN:** Реализовать `checkAuthenticationPassword()`
- [ ] **3.2e:** Запустить тесты → GREEN
- [ ] **3.2f REFACTOR:** Упростить `processAuthorizationStates()` с использованием новых методов
- [ ] **3.2g:** Запустить все тесты (unit + component)
- [ ] **3.2h:** Проверить E2E тест `scripts/manual_e2e_auth.sh`

**Фаза 3: Документация (30 мин)**
- [ ] **3.3a:** Обновить `TDLibAdapter/README.md` с примерами нового API
- [ ] **3.3b:** Добавить doc comments к высокоуровневым методам
- [ ] **3.3c:** Обновить `ARCHITECTURE.md` с диаграммой нового API
- [ ] **3.3d:** Актуализировать `TESTING.md` про component-тесты

**Фаза 4: Очистка (30 мин)**
- [ ] **3.4a:** Проверить сборку на Linux (`swift build && swift test`)
- [ ] **3.4b:** Закоммитить изменения (по частям: протокол, mock, реализация, docs)
- [ ] **3.4c:** Обновить TASKS.md (отметить DEV-1.4 и MVP-1.5 как разблокированные)

**Оценка времени:** 3-5 часов

**Следующий шаг:** Фаза 1.1a - написать RED тест

**Зависимости:** Нет (можно начинать сразу)

**Разблокирует:**
- ✅ DEV-1.4 Component тест авторизации
- ✅ MVP-1.5 Типизация TDLib методов (getChats, getChatHistory)
- ✅ Все будущие component-тесты

---

### DEV-1. Swift-DocC Documentation (🔥 Высокий приоритет)

**Цель:** Организовать живую документацию проекта через Swift-DocC. Тесты = источник правды + навигация сверху вниз.

**Зачем:**
- Быстрая навигация по компонентам (особенно при росте проекта)
- Понимание E2E сценариев через ссылки на тесты
- Внешняя документация для публикации новых версий
- Удобство для себя: найти нужное поведение без поиска по коду

**Структура документации:**
```
Sources/TgClient/TgClient.docc/
├── TgClient.md                    # Главная (стек, фичи, статус)
├── E2E-Scenarios/                 # E2E сценарии
│   ├── Authentication.md          # ✅ Начать с этого
│   ├── FetchUnreadMessages.md     # TODO (после MVP-1)
│   └── GenerateSummary.md         # TODO (после MVP-2)
└── Component-Tests/               # Компонентная документация
    ├── TDLibAdapter.md            # TODO
    └── SummaryGenerator.md        # TODO (после MVP-2)
```

#### Задачи:

**1.1 Инфраструктура** ✅
- [x] Создать `Sources/TgClient/TgClient.docc/` структуру
- [x] Обновить `Package.swift` (добавить target `TgClient` с `.docc` + swift-docc-plugin)
- [x] Создать скрипт `scripts/preview-docs.sh` для локального preview
- [x] Добавить `.gitignore` для сгенерированной документации
- [x] Создать GitHub Actions workflow `.github/workflows/docs.yml`
- [x] Переписать workflow на Linux с кешированием TDLib (как в linux-build.yml)
- [x] **[USER-GITHUB]** Включить GitHub Pages (Settings → Pages → Source: GitHub Actions)
- [x] **[USER-GITHUB]** Проверить публикацию: https://flyer2001.github.io/tg-client/documentation/tgclient

**1.2 Главная страница** ✅
- [x] Создать `TgClient.md` (точка входа):
  - [x] Описание проекта (CLI-клиент Telegram для AI-саммари)
  - [x] Технологический стек (Swift 6, TDLib, Swift-Log, Swift Testing)
  - [x] Статус реализации (✅ Реализовано, 🚧 В разработке, 📋 Запланировано)
  - [x] Ссылки на E2E сценарии
  - [x] Список core модулей MVP
  - [x] Ссылки на внешние ресурсы (GitHub https://github.com/flyer2001/tg-client, TDLib docs)

**1.3 E2E: Авторизация** ✅
- [x] Создать `E2E-Scenarios/Authentication.md`:
  - [x] Описание сценария (phone → code → ready)
  - [x] Flow схема (включая 2FA)
  - [x] Таблица обработки ошибок (PHONE_NUMBER_INVALID, etc.)
  - [x] Ссылки на используемые компоненты (→ Component tests)
  - [x] Ссылки на unit-level модели (→ Unit tests)
  - [x] Ссылки на внешнюю документацию TDLib
  - [x] Диаграмма состояний авторизации

**1.4 Component тест: TDLibAdapter Auth (30 мин)**
- [ ] Создать `Tests/TgClientComponentTests/TDLibAdapter/AuthenticationFlowTests.swift`:
  - Doc comments с описанием scope
  - Ссылки на внешние TDLib docs
  - Сценарии: phone+code, 2FA, ошибки, network errors
  - Ссылки на related tests (unit, E2E)
  - **RED:** Тест `authenticateWithPhoneAndCode()` с MockTDLibClient
  - **GREEN:** Stub implementation (MockTDLibClient)
  - Проверка сборки: `swift build && swift test`

**1.5 Обновить unit-тесты с doc comments (20 мин)**
- [ ] Обновить `Tests/TgClientUnitTests/TDLibAdapter/ResponseDecodingTests.swift`:
  - Suite-level doc comments (scope, external API, related tests)
  - Test-level doc comments (TDLib response examples, docs links)
  - Ссылки на официальную документацию TDLib API
  - Примеры JSON из реальных ответов TDLib

**1.6 Скрипт для генерации индекса (15 мин, опционально)**
- [ ] Создать `scripts/generate-test-index.sh`:
  - Парсит все тестовые файлы
  - Генерирует `Tests/TEST_INDEX.md` с навигацией
  - Группировка по уровням (Unit / Component / E2E)
  - Извлечение `@Suite` описаний
  - Добавить в pre-commit hook (опционально)

**1.7 Правила актуализации документации** ✅
- [x] Добавить в [CONTRIBUTING.md](CONTRIBUTING.md):
  - [x] Секция "Swift-DocC документация" с правилами
  - [x] **Правило:** При добавлении нового модуля → создать article в `Component-Tests/`
  - [x] **Правило:** При добавлении E2E сценария → создать article в `E2E-Scenarios/`
  - [x] **Правило:** При добавлении модели/запроса → обновить unit-тесты с doc comments
  - [x] Добавлено в чеклист перед коммитом (пункт 3)
  - [x] Инструкции по локальному preview
- [x] Создать [README.md](../README.md) с секцией "Документация"
  - [x] Ссылка на GitHub Pages: https://flyer2001.github.io/tg-client/documentation/tgclient
  - [x] Инструкции по локальному preview

**1.8 Публикация документации** ✅
- [x] Настроить GitHub Actions для генерации статических страниц (`.github/workflows/docs.yml`)
- [x] Workflow для автоматической публикации на GitHub Pages
- [ ] **[USER-GITHUB]** Включить GitHub Pages в Settings → Pages → Source: GitHub Actions
- [ ] Добавить badge в README.md (опционально, после проверки что работает)

#### Критерии готовности:

- ✅ Главная страница открывается через `swift package preview-documentation`
- ✅ E2E сценарий авторизации полностью задокументирован с навигацией
- ✅ Component тест авторизации написан (хотя бы один тест)
- ✅ Unit-тесты имеют doc comments с примерами JSON
- ✅ Правила актуализации добавлены в CONTRIBUTING.md

#### Зависимости:

- Базовая инфраструктура проекта (✅ есть)
- Существующие unit-тесты для авторизации (✅ есть)

#### Оценка времени:

- **Первичная настройка (авторизация):** 1.5-2 часа
- **Актуализация при новом модуле:** 15-20 мин
- **Поддержка в будущем:** минимальная (при добавлении фичи)

---

### DEV-2. Публичный репозиторий (🔥 Высокий приоритет)

**Цель:** Оформить репозиторий для публичного доступа после того как сделан публичным.

**Контекст:** Репозиторий был приватным, теперь публичный. Нужно:
1. Обозначить что проект в активной разработке
2. Объяснить назначение папки `docs/` (для AI-assisted development)
3. Подготовить README.md как точку входа
4. Подготовить beta релиз для MVP

#### Задачи:

**2.1 Обновить README.md**
- [ ] Добавить badges (build status, documentation)
- [ ] Секция "⚠️ Project Status": проект в активной разработке, пока не готов к использованию
- [ ] Секция "🎯 What is this?": краткое описание проекта (2-3 предложения)
- [ ] Секция "📚 Documentation":
  - Ссылка на Swift-DocC: https://flyer2001.github.io/tg-client/documentation/tgclient
  - Объяснить что `docs/` - это рабочая документация для AI-assisted разработки (Claude CLI)
  - Ссылка на CONTRIBUTING.md для контрибьюторов
- [ ] Секция "🚀 MVP Roadmap": краткий список что планируется (см. MVP.md)
- [ ] Секция "🛠️ Development": как запустить локально (ссылка на SETUP.md)
- [ ] Лицензия (добавить LICENSE файл - MIT или Apache 2.0)

**2.2 Обновить docs/README.md (новый файл)**
- [ ] Создать индексную страницу для папки `docs/`
- [ ] Объяснить назначение: рабочая документация для AI-assisted разработки
- [ ] Список всех документов с кратким описанием:
  - ARCHITECTURE.md - архитектура проекта
  - TASKS.md - текущие задачи (живой документ)
  - MVP.md - план MVP и scope
  - CONTRIBUTING.md - правила разработки и коммитов
  - TESTING.md - стратегия тестирования
  - SETUP.md - настройка окружения
  - DEPLOY.md - деплой на Linux VPS
  - CHANGELOG.md - история изменений по сессиям
  - IDEAS.md - бэклог для версий после MVP
  - TROUBLESHOOTING.md - частые проблемы

**2.3 Подготовить beta релиз**
- [ ] Создать git tag `v0.1.0-beta` (для текущего состояния)
- [ ] Создать GitHub Release через `gh` CLI:
  - Заголовок: "v0.1.0-beta - Initial Public Release"
  - Описание:
    - Что уже работает (авторизация, TDLib adapter, unit-тесты)
    - Что в разработке (MVP features)
    - Предупреждение: не для production использования
  - Прикрепить changelog (из CHANGELOG.md)
- [ ] Обновить CHANGELOG.md с записью о публичном релизе

**2.4 Проверить отсутствие секретов**
- [x] Проверить `.gitignore` (все секреты игнорируются)
- [x] Grep по секретам в коммитах (api_key, password, token и т.д.)
- [x] Убедиться что credentials только из env (не хардкод)

#### Критерии готовности:

- [ ] README.md содержит статус проекта, описание, ссылки на документацию
- [ ] docs/README.md создан с навигацией
- [ ] Создан git tag и GitHub Release v0.1.0-beta
- [ ] LICENSE файл добавлен
- [ ] Нет секретов в истории git

#### Оценка времени:

- **README.md + docs/README.md:** 30 мин
- **Beta release + LICENSE:** 20 мин
- **Итого:** ~1 час

---

### MVP-1. ChannelMessageSource (TDLib Integration)

**Цель:** Получение непрочитанных сообщений из Telegram каналов.

> **📖 Детали работы с TDLib API:** [MVP.md — TDLib API: Работа с непрочитанными сообщениями](MVP.md#tdlib-api-работа-с-непрочитанными-сообщениями)

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

#### Задачи (по TDD: RED → GREEN → REFACTOR):

**1.5 Типизация TDLib методов** (делать первым!)
- [ ] **RED:** Тест декодирования `Chat` из JSON (с примером TDLib ответа + ссылка на docs)
- [ ] **GREEN:** Создать модель `Chat` с минимумом полей
- [ ] **REFACTOR:** Добавить Sendable, Equatable, документацию, edge cases
- [ ] **RED:** Тест декодирования `Message` из JSON
- [ ] **GREEN:** Создать модель `Message`
- [ ] **REFACTOR:** Добавить `MessageContent` (для MVP только text)
- [ ] **RED:** Тест кодирования `GetChatsRequest`
- [ ] **GREEN:** Создать `GetChatsRequest` (Sources/TDLibAdapter/TDLibCodableModels/Requests/)
- [ ] **RED:** Тест кодирования `GetChatHistoryRequest`
- [ ] **GREEN:** Создать `GetChatHistoryRequest`
- [ ] **RED:** Тест кодирования `ViewMessagesRequest`
- [ ] **GREEN:** Создать `ViewMessagesRequest`
- [ ] **RED:** Тест декодирования `Chats` и `Messages` ответов
- [ ] **GREEN:** Создать модели ответов
- [ ] Enum `ChatType` (channel, private, supergroup, etc.)
- [ ] Проверить сборку: `swift build && swift test`

**1.1 Протокол и модели DigestCore**
- [ ] **RED:** Тест инициализации `SourceMessage`
- [ ] **GREEN:** Создать `SourceMessage` (Sources/DigestCore/Models/)
- [ ] **REFACTOR:** Codable, Equatable, edge cases
- [ ] **RED:** Тест для `MessageSourceProtocol` (mock implementation)
- [ ] **GREEN:** Создать протокол `MessageSourceProtocol` (Sources/DigestCore/Protocols/)
- [ ] Создать stub `ChannelMessageSource` (Sources/DigestCore/Sources/)
- [ ] Проверить сборку: `swift build && swift test`

**1.2 Получение списка каналов** (component-тест)
- [ ] **RED:** Тест `fetchUnreadChannels()` с MockTDLibClient
- [ ] **GREEN:** Реализовать получение чатов через `getChats(chatList: .main)`
- [ ] **GREEN:** Фильтрация: только каналы (тип `channel`)
- [ ] **GREEN:** Фильтрация: не в архиве (`chatList != .archive`)
- [ ] **GREEN:** Фильтрация: есть непрочитанные (`unreadCount > 0`)
- [ ] **REFACTOR:** Error handling, логирование
- [ ] Тесты на edge cases (пустой список, ошибки API)

**1.3 Извлечение сообщений из канала** (component-тест)
- [ ] **RED:** Тест оптимизированного запроса (fromMessageId=0, limit=unreadCount)
- [ ] **GREEN:** `getChatHistory(chatId:, fromMessageId: 0, offset: 0, limit: unreadCount)`
- [ ] **GREEN:** Фильтр по `lastReadInboxMessageId` (защита от race condition)
- [ ] ⚠️ Использовать `lastReadInboxMessageId` (НЕ `lastReadOutboxMessageId`!)
- [ ] **GREEN:** Формирование ссылок: `https://t.me/<username>/<messageId>`
- [ ] **GREEN:** Обработка каналов без username (показывать "Private channel")
- [ ] **REFACTOR:** Конвертация `Message` → `SourceMessage`
- [ ] Тесты на edge cases (приватные каналы, пустая история)

**1.4 Отметка прочитанным**
- [ ] **RED:** Тест `markAsRead()` с MockTDLibClient
- [ ] **GREEN:** `viewMessages(chatId:, messageIds:, forceRead: true)`
- [ ] **GREEN:** Группировка по chatId (один запрос на чат)
- [ ] Вызов ТОЛЬКО после успешной отправки дайджеста (в DigestOrchestrator)
- [ ] **REFACTOR:** Обработка ошибок (rollback если фейл)
- [ ] Тесты на edge cases (пустой список, partial success)

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
**Последнее обновление:** 2025-10-31
