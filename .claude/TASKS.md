# Задачи проекта

## 🚀 Инструкции для новой сессии

**При запуске новой сессии:**
1. Прочитай топ-3 приоритета ниже
2. Предложи продолжить работу с фокусом на MVP
3. При необходимости (если задача неясна) — посмотри детали в [MVP.md](.claude/MVP.md)
4. **TDD обязателен**: пиши тесты ДО реализации (см. [TESTING.md](.claude/TESTING.md))

**Перед завершением сессии:**
- Обнови статус задач в этом файле
- **Актуализируй Swift-DocC документацию** (при добавлении новых модулей/компонентов)
- Запиши выполненные задачи в [CHANGELOG.md](.claude/CHANGELOG.md) (только prepend через bash)
- Если нужно — добавь идеи в [BACKLOG.md](.claude/BACKLOG.md)

---

> 🎯 **MVP (цели и scope):** [MVP.md](.claude/MVP.md) — читать по требованию (большой файл)
> 💡 **Будущие фичи:** [BACKLOG.md](.claude/BACKLOG.md) — бэклог для версий после MVP
> 📝 **История изменений:** [CHANGELOG.md](.claude/CHANGELOG.md) — логи завершенных сессий, читать только по требованию (большой файл)
> 📋 **Последнее обновление:** 2025-11-12

---

## 🎯 Следующая сессия (топ-3 приоритета)

**Контекст предыдущей сессии (2025-11-10 утро):**
- ✅ **TD-5 Phase 1 ЗАВЕРШЕНА:** FoundationExtensions модуль + JSONCoding.swift (88 тестов проходят)
  - Создан `JSONEncoder.tdlib()` / `JSONDecoder.tdlib()` с `.convertToSnakeCase` / `.convertFromSnakeCase`
  - Удалены избыточные CodingKeys из 21 файла (оставлен только маппинг для `@type`)
  - Добавлены 16 unit-тестов для encoder/decoder (базовые + краевые случаи + round-trip)
- ✅ **Упрощение моделей:** chatList = "chat_list" → chatList (автоконвертация)
- ✅ **Централизация:** все JSONEncoder()/JSONDecoder() заменены на .tdlib()
- ✅ **Система мониторинга токенов:** команда `/start_analytics` для отслеживания расхода токенов в сессии
  - Создан `/tmp/tg_token_tracker.json` с автоматическим счётчиком сообщений
  - Workflow: каждые 3 сообщения запрос sync с `/usage` (не блокирует диалог)
  - Алерты при достижении 75%, 85%, 90% использования

**Контекст текущей сессии (2025-11-17 Session 2):**
- ✅ **MVP-1.8: getChatHistory() реализация ЗАВЕРШЕНА**
  - TDLibClient.getChatHistory() — реализация в TDLibClientProtocol + TDLibClient+HighLevelAPI
  - MockTDLibClient.getChatHistory() — mock реализация для тестов
  - **E2E проверка на production:** ✅ Работает! Получено 1 сообщение из Saved Messages (chatId = userId)
  - **Итого:** 104 unit-теста проходят (без изменений, модели уже были готовы)
- ✅ **Упрощён main.swift для E2E тестов**
  - Убран loadChats эксперимент (был креш из-за updates stream)
  - Добавлен простой тест getChatHistory() через Saved Messages
  - Теперь быстрый запуск для проверки новых методов
- ⏭️ **Следующий шаг:** MVP-1.6 ChannelMessageSource - fetchUnreadMessages() реализация

**Контекст предыдущей сессии (2025-11-17 Session 1):**
- ✅ **Усиление документации для архитектурного проектирования**
  - CLAUDE.md: добавлен Шаг 6.1 "Проговори архитектурные решения ВСЛУХ" с 4 блоками анализа
  - PROMPTS.md: усилена роль Senior Swift Architect — добавлен Блок 0 (предварительный анализ)
  - ARCHITECTURE.md: новый раздел "Logging Strategy" с уровнями логирования (info, error, debug, warning)
  - ARCHITECTURE.md: добавлен ADR-001 для fetchUnreadMessages() (производительность, память, отказоустойчивость)
  - TESTING.md: добавлено Rule #7 "НЕ используй raw JSON в тестах" (используй модельные конструкторы)
- ✅ **MVP-1.8: getChatHistory модели**
  - Message модель + FormattedText + MessageContent (text/unsupported) — 4 unit-теста GREEN
  - GetChatHistoryRequest модель — 3 unit-теста GREEN
  - MessagesResponse модель — 3 unit-теста GREEN
  - **Итого:** 104 unit-теста проходят (было 91, добавили 13 новых)
- ✅ **Logger интегрирован в ChannelMessageSource**
  - Добавлен через DI (Dependency Injection)
  - Обновлены Component и E2E тесты (передают no-op logger)

**Контекст предыдущей сессии (2025-11-13 Session 1):**
- ✅ **Итеративный Outside-In TDD:** Применили на практике для ChannelMessageSource
  - Высокоуровневый тест `fetchUnreadMessages()` (компилируется, падает на fatalError)
  - Попытка реализации → СТОП! Обнаружили нужен `loadChats() + updates` AsyncStream
  - Добавлен тест `loadChatsEmitsUpdateNewChat()` для недостающего функционала
  - Все тесты в одном файле — видна Outside-In декомпозиция
- ✅ **Удалён overengineering:** ChannelCache, ChannelInfo (были созданы БЕЗ попытки реализации)
- ✅ **Документация усилена:**
  - CLAUDE.md: добавлен обязательный шаг чтения TESTING.md + PROMPTS.md перед тестами
  - TESTING.md: добавлен "Итеративный алгоритм Outside-In" (реальный процесс работы)
  - PROMPTS.md: примеры UpdatesHandler помечены как гипотетические
  - BACKLOG.md: Realtime мониторинг (v0.2.0) с ссылками на коммиты
- ✅ **Проверены unit-тесты:** LoadChatsRequestTests, UpdateTests, OkResponseTests (все корректны)

**Приоритеты:**

1. **[MVP-1.6] ChannelMessageSource реализация** - fetchUnreadMessages() с loadChats + updates + getChatHistory
2. **[MVP-1.10] MessageSource Protocol + Models** - SourceMessage, ChannelInfo модели для DigestCore
3. **[MVP-2] SummaryGenerator** - OpenAI Integration для генерации AI-саммари

> **См. детали:**
> - [MVP-1.6: ChannelMessageSource](#mvp-16-channelmessagesource-получение-непрочитанных-через-loadchats--updates-приоритет) — детальный план с декомпозицией
> - [TESTING.md](.claude/TESTING.md#декомпозиция-при-обнаружении-сложности) — процесс декомпозиции
> - [ARCHITECTURE.md](.claude/ARCHITECTURE.md#single-responsibility-principle-srp) — паттерн Coordinator + Workers

---

## 📊 High Priority (MVP Phase 1-2)

### MVP-1.5. Типизация TDLib методов (🔥 В РАБОТЕ)

**Цель:** Создать типобезопасные модели для работы с чатами и сообщениями.

**Зачем:** Блокирует MVP-1 (ChannelMessageSource) - нужны методы `getChats()`, `getChatHistory()`, `viewMessages()`.

**Статус:** Частично выполнено (getChats готов, остальные методы - в работе)

#### Задачи (по TDD: RED → GREEN → REFACTOR):

**1.1 Модель Chat** (~30 мин)
- [ ] **RED:** Тест декодирования `Chat` из JSON (с примером TDLib ответа + ссылка на docs)
- [ ] **GREEN:** Создать модель `Chat` (Sources/TDLibAdapter/TDLibCodableModels/Responses/)
- [ ] **REFACTOR:** Добавить Sendable, Equatable, документацию
- [ ] Поля: id, type (enum ChatType), title, lastReadInboxMessageId, unreadCount

**1.2 Enum ChatType** ✅ (~15 мин) **[ЗАВЕРШЕНО 2025-01-08]**
- [x] **RED:** Тест декодирования всех типов чатов
- [x] **GREEN:** Создать `ChatType` enum (private, supergroup, channel, secret, basic)
- [x] **REFACTOR:** Документация для каждого типа
- [x] **Файлы:** `Sources/TDLibAdapter/TDLibCodableModels/Responses/ChatType.swift`, `Tests/TgClientUnitTests/.../ChatTests.swift`
- [x] **Тесты:** 6 unit-тестов проходят ✔

**1.3 Модель Message** ✅ (~45 мин) **[ЗАВЕРШЕНО 2025-11-17]**
- [x] **RED:** Тест round-trip для `Message` (используя конструкторы, БЕЗ raw JSON)
- [x] **GREEN:** Создать модель `Message` + `FormattedText` + `MessageContent` enum
- [x] **REFACTOR:** MessageContent (text/unsupported), все init под `#if DEBUG`
- [x] Поля: id, chatId, date, content (MessageContent)
- [x] **Тесты:** 4 unit-теста проходят ✔

**1.4 Request: GetChatsRequest** ✅ (~20 мин) **[ЗАВЕРШЕНО 2025-11-07]**
- [x] **RED:** Тест кодирования `GetChatsRequest`
- [x] **GREEN:** Создать `GetChatsRequest` (Sources/TDLibAdapter/TDLibCodableModels/Requests/)
- [x] Параметры: chatList (enum: main/archive), limit
- [x] **RED:** Component Test для getChats() с MockTDLibClient
- [x] **GREEN:** Реализация TDLibClient.getChats() + MockTDLibClient.getChats()
- [x] **REFACTOR:** Error handling documentation, ARCHITECTURE.md (Error Handling Strategy)

**1.5 Request: GetChatHistoryRequest** (~20 мин)
- [ ] **RED:** Тест кодирования `GetChatHistoryRequest`
- [ ] **GREEN:** Создать `GetChatHistoryRequest`
- [ ] Параметры: chatId, fromMessageId, offset, limit

**1.6 Request: ViewMessagesRequest** (~20 мин)
- [ ] **RED:** Тест кодирования `ViewMessagesRequest`
- [ ] **GREEN:** Создать `ViewMessagesRequest`
- [ ] Параметры: chatId, messageIds, forceRead

**1.7 Response модели** ✅ (~30 мин) **[ЗАВЕРШЕНО 2025-11-11]**
- [x] **RED:** Тест декодирования `ChatsResponse` (список chatIds)
- [x] **GREEN:** Создать `ChatsResponse`
- [x] **RED:** Тест декодирования `ChatResponse` (полная модель Chat) — 8 тестов
- [x] **GREEN:** Создать `ChatResponse` + `ChatType.Encodable`
- [ ] **TODO следующая сессия:** MessagesResponse (список Message)

**1.8 Проверка** ✅ (~15 мин) **[ЗАВЕРШЕНО 2025-11-07]**
- [x] Проверить сборку: `swift build && swift test` (50 тестов проходят)
- [x] E2E тест: получено 100 чатов через реальный TDLib
- [x] Обновить DoCC документацию (E2E сценарий FetchUnreadMessages)
- [x] **Исправлена генерация DoCC:** glob → find, автогенерация в CI, .gitignore для .md
- [x] **Добавлен шаг валидации документации в TESTING.md** (шаг 10 в Outside-In TDD)

**Оценка времени:** ~2.5-3 часа

**Зависимости:** Нет (базовая инфраструктура уже есть)

**Разблокирует:** MVP-1.6 (ChannelMessageSource с декомпозицией)

---

### MVP-1.6. ChannelMessageSource: Получение непрочитанных через loadChats + updates (🔥 ПРИОРИТЕТ)

**Цель:** Реализовать получение непрочитанных сообщений из каналов через `loadChats` + updates механизм TDLib с применением декомпозиции по SRP.

**Архитектурное решение:**
- Отдельный `MessageSourceProtocol` (НЕ в TDLibClient)
- Декомпозиция на подкомпоненты: `ChannelCache`, `UpdatesHandler`, `MessageFetcher`
- Coordinator pattern: `ChannelMessageSource` координирует Workers
- Dependency Injection: зависимости через `init`

**Статус:** В работе - RED фаза завершена (E2E + Component тесты созданы, не компилируются)

**Контекст для следующей сессии (2025-01-08):**
- E2E и Component тесты написаны (RED - не компилируются, ждут реализации)
- Удалён устаревший GetChatsTests (component test на getChats)
- TESTING.md усилён: запрет на преждевременное создание Mock API
- Следующий шаг: декомпозиция на подкомпоненты (ChannelCache, UpdatesHandler, MessageFetcher) с Unit тестами

#### Задачи (по Outside-In TDD с декомпозицией):

**1.1 Обновление документации** (~20 мин) ✅
- [x] Обновить `FetchUnreadMessages.md` — упростить шаги, убрать технические детали
- [x] Добавить ссылку на E2E тест в `FetchUnreadMessages.md`
- [x] Обновить `TESTING.md` — добавить раздел "Декомпозиция при обнаружении сложности"
- [x] Обновить `ARCHITECTURE.md` — добавить раздел "Single Responsibility Principle (SRP)"

**1.2 E2E сценарий (тест)** ✅ (~30 мин) **[ЗАВЕРШЕНО 2025-01-08]**
- [x] **RED:** Создать `Tests/TgClientE2ETests/FetchUnreadMessagesScenarioTests.swift`
- [x] Тест: подключение → получение непрочитанных → проверка структуры
- [x] Использовать реальный TDLib клиент (упрощённая версия - фокус на ChannelMessageSource)
- [x] Тест НЕ КОМПИЛИРУЕТСЯ (нет ChannelMessageSource) ✔ RED достигнут
- [x] Удалён placeholder test `E2ETestsPlaceholder.swift`

**1.3 Component Test** ✅ (~30 мин) **[ЗАВЕРШЕНО 2025-01-08]**
- [x] **RED:** Создать `Tests/TgClientComponentTests/DigestCore/ChannelMessageSourceTests.swift`
- [x] Тест вызывает `messageSource.fetchUnreadMessages()` (фокус на интеграции, НЕ на внутренних шагах)
- [x] Тест НЕ КОМПИЛИРУЕТСЯ (нет ChannelMessageSource) ✔ RED достигнут
- [x] Документация TDLib методов: loadChats, getChat, getChatHistory с примерами JSON
- [x] **ВАЖНО:** Следование TDD - НЕ придумывать Mock API раньше Real (усилены инструкции в TESTING.md)
- [ ] Документировать найденные требования в комментариях теста:
  - loadChats loop (pagination)
  - updates handler (фоновый процесс)
  - ChannelCache (in-memory)
  - Фильтрация по type=channel + unreadCount>0
  - Получение сообщений из каналов

**1.4 Декомпозиция (архитектурное решение)** ✅ (~30 мин) **[ЗАВЕРШЕНО 2025-11-08]**
- [x] Выделить подкомпоненты по зонам ответственности:
  - `ChannelCache` (actor) — кэширование списка каналов
  - `UpdatesHandler` — обработка TDLib updates (TODO: следующая сессия)
  - `MessageFetcher` — получение сообщений из каналов (TODO: следующая сессия)
  - `ChannelMessageSource` — координатор
- [x] Создать пустые файлы (scaffold):
  - `Sources/DigestCore/Cache/ChannelCache.swift` ✅
  - `Sources/DigestCore/Sources/ChannelMessageSource.swift` ✅
  - `Sources/DigestCore/Models/SourceMessage.swift` ✅
  - `Sources/DigestCore/Protocols/MessageSourceProtocol.swift` ✅
  - `Sources/DigestCore/Updates/UpdatesHandler.swift` (TODO: следующая сессия)
  - `Sources/DigestCore/Fetchers/MessageFetcher.swift` (TODO: следующая сессия)
- [x] Добавить DigestCore target в Package.swift
- [x] Обновить зависимости тестов (TgClientComponentTests, TgClientE2ETests)
- [x] Проверить компиляцию: `swift build` успешно ✅
- [ ] Обновить `ARCHITECTURE.md` — добавить диаграмму компонентов (TODO: после GREEN фазы)

**1.5 Unit Tests для ChannelCache** (~1.5 часа) ✅ **[ЗАВЕРШЕНО 2025-11-10]**
- [x] **RED:** `Tests/TgClientUnitTests/DigestCore/ChannelCacheTests.swift` ✅ Создан
- [x] Тесты написаны (13 тестов):
  - `add(_:ChannelInfo)` — добавление канала, обновление при дубликатах
  - `updateUnreadCount(chatId:count:)` — обновление счётчика, фильтрация при count=0
  - `getUnreadChannels()` — фильтрация + сортировка по unreadCount (DESC)
  - `remove(chatId:)` — удаление канала
  - Edge cases: Int64.max, Int32.max, nil username
- [x] **GREEN:** Реализация `ChannelCache` (actor с методами: add, updateUnreadCount, getUnreadChannels, remove) ✅
- [x] Проверить actor isolation (thread-safe) ✅
- [x] Запустить тесты и убедиться в GREEN ✅ (13 тестов проходят)

**Контекст для следующей сессии:**
- GREEN фаза завершена (все 13 тестов проходят)
- ChannelCache полностью реализован (actor-based, thread-safe)
- Следующий шаг: MVP-1.7 — TDLib модели для loadChats/getChat/updates

**1.6 ChannelMessageSource: Получение непрочитанных** (~4 часа) ⚠️ **[В РАБОТЕ 2025-11-12]**

**⚠️ КРИТИЧНО: Усвоенный урок (2025-11-12)**

Сделали overengineering - создали UpdatesHandler и ChannelCache БЕЗ реальной попытки написать Component Test.
Нарушили правило TESTING.md:328 "Декомпозиция ТОЛЬКО после реальной попытки".

**Что было не так:**
- ❌ Предположили что ChannelMessageSource будет сложным (без теста!)
- ❌ Создали UpdatesHandler (3 строки кода = `for await` loop) - overengineering
- ❌ Создали ChannelCache для realtime мониторинга - НЕ нужен для MVP

**MVP Use Case:**
- Cron запускается раз в N часов (stateless)
- Загружаем актуальное состояние чатов
- Формируем дайджест
- Завершаем работу (без realtime кеша)

**Архитектурное решение (Senior Architect review - исправленное):**

**ЗАЧЕМ нужны updates для MVP:**
НЕ для realtime мониторинга, а для **первоначальной загрузки** чатов!

**TDLib behavior:**
1. `loadChats()` → возвращает `Ok` (не список чатов!)
2. TDLib посылает `updateNewChat` для каждого загруженного чата через AsyncStream
3. `updateNewChat` содержит **полный Chat объект** (id, type, title, unreadCount, etc)
4. Повторяем `loadChats()` пока не получим 404 (все чаты загружены)

**Упрощенная архитектура:**
- ✅ ChannelMessageSource (coordinator) - единственный компонент
- ✅ MessageFetcher (helper) - получение сообщений
- ❌ UpdatesHandler - НЕ НУЖЕН (просто `for await` внутри ChannelMessageSource)
- ❌ ChannelCache - НЕ НУЖЕН (stateless для MVP)

```swift
actor ChannelMessageSource: MessageSourceProtocol {
    private let tdlib: TDLibClientProtocol
    private let messageFetcher: MessageFetcher

    func fetchUnreadMessages() async throws -> [SourceMessage] {
        var allChats: [Chat] = []

        // 1. Подписываемся на updates + загружаем чаты
        try await withThrowingTaskGroup(of: Void.self) { group in
            // Task 1: Слушаем updateNewChat
            group.addTask { [weak self] in
                guard let self else { return }
                for await update in await self.tdlib.updates {
                    if case .updateNewChat(let chat) = update {
                        allChats.append(chat)
                    }
                }
            }

            // Task 2: Загружаем все чаты через pagination
            group.addTask { [weak self] in
                guard let self else { return }
                while true {
                    do {
                        try await self.tdlib.loadChats(chatList: .main, limit: 100)
                    } catch let error as TDLibErrorResponse where error.isAllChatsLoaded {
                        break  // 404 - все чаты загружены
                    }
                }
            }

            try await group.waitForAll()
        }

        // 2. Фильтруем каналы с непрочитанными
        let unreadChannels = allChats.filter { chat in
            guard case .supergroup(_, isChannel: true) = chat.chatType else {
                return false
            }
            return chat.unreadCount > 0
        }

        // 3. Получаем сообщения
        return try await messageFetcher.fetch(from: unreadChannels)
    }
}
```

**Прогресс:**
- [x] ✅ **Документация усилена** (2025-11-12)
  - TESTING.md: правило "Декомпозиция ТОЛЬКО после реальной попытки"
  - DEVELOPMENT.md: правила про retain cycles и [weak self]
  - TESTING.md: правила про Task.sleep() (редкие исключения)
  - TESTING.md: правила оформления Component тестов

**Следующие задачи:**
- [ ] 📝 **Актуализация Component тестов** (~1.5 часа):
  - Объединить LoadChatsAndGetChatTests логику в ChannelMessageSourceTests
  - Описать green path: loadChats() loop + updateNewChat → фильтрация → fetchMessages
  - Описать edge cases: пустой список, все чаты прочитаны, ошибки loadChats
  - Убрать упоминания UpdatesHandler и ChannelCache из тестов
- [ ] Unit Tests для Update enum (RED)
- [ ] Models: Update enum implementation (GREEN)
- [ ] Real implementation: TDLibClient.updates AsyncStream (GREEN)
- [ ] Mock implementation: MockTDLibClient.updates support (GREEN)
- [ ] Real implementation: ChannelMessageSource (GREEN)
- [ ] Component Test (GREEN)
- [ ] E2E validation

**Realtime updates → BACKLOG** для будущих фич (например, бот может ответить "какие сейчас непрочитанные")

**1.7 TDLib модели для loadChats/getChat + updates AsyncStream** ✅ **[ЗАВЕРШЕНО 2025-11-17]**
- [x] **RED:** Unit-тесты для `LoadChatsRequest` ✅ (4 теста проходят)
  - `LoadChatsRequest` — параметры: chatList, limit ✅
  - `OkResponse` — универсальный успешный ответ TDLib ✅ (2 теста проходят)
- [x] **GREEN:** Реализация моделей (Codable, Sendable, Equatable) ✅
- [x] **RED:** Unit-тесты для `TDLibErrorResponse.isAllChatsLoaded` helper ✅ (3 новых теста)
- [x] **GREEN:** Реализация helper для 404 ошибки (pagination) ✅
- [x] **RED:** Unit-тесты для `GetChatRequest` ✅ (3 теста: базовый, отрицательный ID, edge cases)
- [x] **GREEN:** Реализация `GetChatRequest` ✅
- [x] **RED:** Unit-тесты для `ChatResponse` ✅ (8 тестов: 5 типов чатов + edge cases)
- [x] **GREEN:** Реализация `ChatResponse` + `ChatType.Encodable` ✅
- [x] **RED:** Unit-тесты для `Update` enum ✅ (5 тестов: updateNewChat, updateChatReadInbox, edge cases)
- [x] **GREEN:** Реализация `Update` enum (Codable, Sendable, Equatable) ✅
- [x] **GREEN:** Реализация `updates: AsyncStream<Update>` в TDLibClient ✅
  - Фоновый receive loop для обработки updates
  - AsyncStream.Continuation для yield updates
  - Фильтрация авторизационных событий и ошибок
- [x] **E2E тест на production сервере** ✅
  - Загружено 758 чатов за 10.5 секунд
  - 4 вызова loadChats() с pagination до 404
  - Таймаут 2 секунды между вызовами - оптимальный для MVP
  - Updates приходят асинхронно (не блокируют loadChats)
- [x] **Архитектурные улучшения** ✅ (2025-11-17)
  - MockTDLibClient: actor → class (точно имитирует Real TDLibClient)
  - MockTDLibClient.updates: реализован через lazy var (проще и понятнее)
  - Component Test исправлен: Chat → ChatResponse
  - Добавлены комментарии про ограничение "один подписчик" в TDLibClient

**Важные изменения:**
- Конвертация тестов из XCTest → Swift Testing
- Убрана избыточная документация "используется в"
- Добавлено правило: запрет force unwrap в тестах (Rule #6 в TESTING.md)
- Все `as!` заменены на `#require` (0 instances в проекте)

**Known Issues (Technical Debt):**
- ⚠️ TDLibClient.updates поддерживает только одного подписчика (FIXME в коде)
- Решение: broadcast через массив continuations (когда понадобится второй подписчик)
- Тест: unit-тест на двух подписчиков (пока рано писать)

**1.8 Unit Tests для MessageFetcher** (~1 час)
- [ ] **RED:** `Tests/TgClientUnitTests/DigestCore/MessageFetcherTests.swift`
- [ ] Тесты:
  - `fetch(from: [ChannelInfo])` → [SourceMessage]
  - Параллельные запросы через TaskGroup
  - Формирование ссылок (публичные/приватные каналы): `https://t.me/{username}/{messageId}`
  - Edge cases: пустой список, ошибка getChatHistory, канал без username
- [ ] **GREEN:** Реализация `MessageFetcher`
- [ ] Использовать MockTDLibClient

**1.9 Модели для getChatHistory** ✅ (~1.5 часа) **[ЗАВЕРШЕНО 2025-11-17 Session 2]**
- [x] **RED:** Unit-тесты:
  - `GetChatHistoryRequest` — параметры: chatId, fromMessageId, offset, limit ✅ (3 теста)
  - `MessagesResponse` — модель Messages (массив Message) ✅ (3 теста)
  - `Message` — модель сообщения (id, chatId, date, content) ✅ (4 теста)
  - `MessageContent` — enum (для MVP только textContent) ✅
- [x] **GREEN:** Реализация моделей ✅
- [x] **GREEN:** Реализация TDLibClient.getChatHistory() ✅
- [x] **GREEN:** MockTDLibClient.getChatHistory() ✅
- [x] **E2E:** Проверка на production (Saved Messages) ✅

**1.10 Protocol + Models для MessageSource** (~1 час)
- [ ] **RED:** Unit-тесты:
  - `SourceMessage` — модель для DigestCore (chatId, messageId, content, link, channelTitle)
  - `ChannelInfo` — модель для кэша (id, title, unreadCount, lastReadMessageId, username)
- [ ] **GREEN:** Реализация моделей (Codable, Equatable, Sendable)
- [ ] Создать `MessageSourceProtocol`:
  ```swift
  protocol MessageSourceProtocol {
      func fetchUnreadMessages() async throws -> [SourceMessage]
      func markAsRead(messages: [SourceMessage]) async throws
  }
  ```

**1.11 Модели для viewMessages (markAsRead)** (~1 час)
- [ ] **RED:** Unit-тесты:
  - `ViewMessagesRequest` — параметры: chatId, messageIds, forceRead
  - `ViewMessagesResponse` — Ok
- [ ] **GREEN:** Реализация моделей
- [ ] **RED:** Component Test для TDLibClient.viewMessages()
- [ ] **GREEN:** Реализация + Mock

**1.12 Integration: ChannelMessageSource** (~2 часа)
- [ ] **GREEN:** Реализация `ChannelMessageSource`
- [ ] Dependency Injection (cache, updatesHandler, messageFetcher, tdlib через init)
- [ ] Инициализация:
  - Запуск loadChats loop (пока не вернёт 404)
  - Запуск UpdatesHandler
  - Обработка updates → обновление cache
  - Флаг `isInitialized` для ожидания готовности
- [ ] `fetchUnreadMessages()`:
  - Ждать инициализации (while !isInitialized)
  - Получить непрочитанные из cache
  - Делегировать MessageFetcher
- [ ] `markAsRead(messages:)`:
  - Группировка по chatId
  - Вызов viewMessages для каждого чата
  - Error handling (логировать, но не прерывать)
- [ ] Component Test GREEN (с MockTDLibClient + реальные Workers)

**1.13 E2E validation** (~30 мин)
- [ ] Запустить E2E тест на реальном TDLib
- [ ] Проверить:
  - Получение всех каналов (не только 100)
  - Корректная фильтрация (только каналы с unreadCount > 0)
  - Корректное получение сообщений
  - Формирование ссылок (публичные/приватные)
- [ ] Логировать результаты для ручной проверки

**1.14 Refactor + Documentation** (~1 час)
- [ ] Refactor: edge cases, error handling, логирование
- [ ] Добавить DoCC комментарии для публичных API
- [ ] Запустить `./scripts/generate-docc-from-tests.sh`
- [ ] Проверить создание Component Test документации
- [ ] Обновить ARCHITECTURE.md — финальная диаграмма компонентов

**Оценка времени:** ~13-15 часов (разбить на 2-3 сессии)

**Зависимости:** MVP-1.5 (частично — Chat модель нужно расширить)

**Разблокирует:** MVP-2 (SummaryGenerator будет использовать SourceMessage модель)

**Критичные моменты:**
- ⚠️ AsyncStream для updates — может быть сложность в TDLibClient (нужна новая архитектура receive loop)
- ⚠️ loadChats pagination — нужна проверка на 404 (все чаты загружены)
- ⚠️ Thread-safety для ChannelCache (actor isolation)
- ⚠️ Graceful shutdown UpdatesHandler при ошибках
- ⚠️ Инициализация может занимать 10-30 сек (первый запуск) — нужен timeout

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

**2.1 OpenAI HTTP Client** (~1.5 часа)
- [ ] Создать `OpenAIClient` (без зависимостей, прямые HTTP calls)
- [ ] Метод `sendChatCompletion(messages:, model:)` → `ChatCompletionResponse`
- [ ] Обработка ошибок (timeout, rate limit, 5xx)
- [ ] Retry логика (exponential backoff)
- [ ] Unit-тесты с моками URLSession

**2.2 Промпт для саммаризации** (~1 час)
- [ ] Разработать prompt template для дайджестов
- [ ] Формат: "Краткое резюме (2-3 предложения) + группировка по каналам"
- [ ] Инструкции для AI: Telegram Markdown, лимит 4096 символов
- [ ] Тестирование промпта с реальными сообщениями

**2.3 Генерация DigestSummary** (~1 час)
- [ ] Модель `DigestSummary` (summary, channelSummaries, totalMessages, period)
- [ ] Модель `ChannelSummary` (chatTitle, messageCount, summary, messageLinks)
- [ ] Парсинг ответа OpenAI → структурированный дайджест
- [ ] Unit-тесты

**2.4 Environment configuration** (~30 мин)
- [ ] Чтение `OPENAI_API_KEY` из env
- [ ] Выбор модели: `OPENAI_MODEL` (gpt-4-turbo / gpt-3.5-turbo)
- [ ] Timeout настройка: `OPENAI_TIMEOUT` (default 30s)

**Оценка времени:** ~3-4 часа

**Зависимости:** MVP-1 (SourceMessage модель)

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

**3.1 Telegram Bot HTTP Client** (~1 час)
- [ ] Создать `TelegramBotClient` (прямые HTTP calls)
- [ ] Метод `sendMessage(chatId:, text:, parseMode:)` → `Message`
- [ ] Поддержка Telegram MarkdownV2
- [ ] Обработка ошибок (4xx, 5xx)
- [ ] Unit-тесты с моками

**3.2 Форматирование дайджеста** (~1 час)
- [ ] Конвертация `DigestSummary` → Telegram Markdown
- [ ] Форматирование: жирный шрифт для заголовков, ссылки
- [ ] Экранирование спецсимволов MarkdownV2
- [ ] Unit-тесты

**3.3 Отправка алертов** (~30 мин)
- [ ] Метод `sendAlert(error:, chatId:)`
- [ ] Разные типы алертов: Auth error, AI error, Bot error
- [ ] Emoji для визуального разделения
- [ ] Unit-тесты

**3.4 Environment configuration** (~15 мин)
- [ ] Чтение `TELEGRAM_BOT_TOKEN` из env
- [ ] Чтение `TELEGRAM_BOT_CHAT_ID`
- [ ] Чтение `DIGEST_ALERT_CHAT_ID` (default = CHAT_ID)

**Оценка времени:** ~2.5-3 часа

**Зависимости:** MVP-2 (DigestSummary модель)

---

### MVP-4. StateManager (Persistence)

**Цель:** Хранение состояния последнего запуска.

#### Задачи:

**4.1 FileBasedStateManager** (~2 часа)
- [ ] Протокол `StateManagerProtocol`
- [ ] Реализация с JSON файлом (`~/.tdlib/digest_state.json`)
- [ ] Модель `DigestState` (lastSuccessfulRun, lastMessageIdByChat)
- [ ] Методы: `loadState()`, `saveState()`, `updateLastRun()`
- [ ] Thread-safe операции (FileManager + locks)
- [ ] Unit-тесты

**4.2 Миграция старых состояний** (~30 мин)
- [ ] Обработка отсутствия файла (первый запуск)
- [ ] Обработка поврежденного JSON (fallback to default)
- [ ] Логирование загрузки/сохранения состояния

**Оценка времени:** ~2.5 часа

**Зависимости:** Нет

---

### MVP-5. DigestOrchestrator (Coordination)

**Цель:** Координация всех компонентов для генерации дайджеста.

#### Задачи:

**5.1 Базовая структура** (~1 час)
- [ ] Класс `DigestOrchestrator` с DI всех сервисов
- [ ] Метод `run(mode: .scheduled | .onDemand) async throws`
- [ ] Логирование каждого этапа (structured logging)
- [ ] Unit-тесты с моками

**5.2 Оркестрация потока** (~2 часа)
- [ ] Загрузка состояния (StateManager)
- [ ] Получение сообщений (ChannelMessageSource)
- [ ] Генерация саммари (SummaryGenerator)
- [ ] Отправка через бота (BotNotifier)
- [ ] Отметка прочитанным (ChannelMessageSource)
- [ ] Сохранение состояния (StateManager)

**5.3 Error handling** (~1 час)
- [ ] Try-catch на каждом этапе
- [ ] Rollback: если отправка фейлится → НЕ помечать прочитанным
- [ ] Отправка алертов через BotNotifier при ошибках
- [ ] Partial success handling

**5.4 CLI интерфейс** (~1 час)
- [ ] `tg-digest scheduled` - scheduled режим
- [ ] `tg-digest on-demand` - on-demand режим
- [ ] Аргументы: `--dry-run` (не отправлять, только логи)
- [ ] Exit codes: 0 - успех, 1 - ошибка

**Оценка времени:** ~5 часов

**Зависимости:** Все предыдущие модули (MVP-1 to MVP-4)

---

## 📋 Normal Priority (MVP Phase 3-4)

### MVP-6. MonitoringService (Observability)

**Цель:** Мониторинг и алерты для продакшена.

#### Задачи:

**6.1 Structured Logging** (~1.5 часа)
- [ ] Интеграция swift-log
- [ ] JSON формат для логов
- [ ] Уровни: DEBUG, INFO, WARN, ERROR
- [ ] Контекст: timestamp, module, operation, duration
- [ ] Ротация логов (logrotate config)

**6.2 Healthcheck механизм** (~1 час)
- [ ] Heartbeat файл (`~/.tdlib/digest_heartbeat.txt`)
- [ ] Обновление после каждого успешного запуска
- [ ] Скрипт `/usr/local/bin/digest-healthcheck.sh`
- [ ] Cron задача для healthcheck (каждые 5 минут)
- [ ] Алерт если heartbeat старше 3 часов

**6.3 Telegram Self-Monitoring** (~30 мин)
- [ ] Алерт при старте приложения
- [ ] Алерт при успешном завершении
- [ ] Алерт при ошибках
- [ ] Daily summary

**Оценка времени:** ~3 часа

**Зависимости:** BotNotifier (MVP-3)

---

### MVP-7. Deployment (Linux VPS)

**Цель:** Развертывание на продакшен сервере.

#### Задачи:

**7.1 systemd Service** (~1 час)
- [ ] Файл `tg-digest.service`
- [ ] Hardening: user isolation, sandboxing, resource limits
- [ ] Restart policy: on-failure с backoff
- [ ] Логирование в journald

**7.2 Cron Setup** (~30 мин)
- [ ] Cron задача для scheduled запусков (09:00, 18:00)
- [ ] Запуск через systemd
- [ ] Логирование cron запусков

**7.3 Environment Setup** (~30 мин)
- [ ] `.env` файл с credentials
- [ ] Шаблон `.env.example`
- [ ] Инструкции по безопасному хранению секретов
- [ ] systemd EnvironmentFile

**7.4 Log Management** (~1 час)
- [ ] logrotate конфигурация
- [ ] journald limits (max size, retention)
- [ ] Скрипты для фильтрации логов
- [ ] Инструкции для troubleshooting

**7.5 Обновление DEPLOY.md** (~30 мин)
- [ ] Раздел "Digest Service Setup"
- [ ] Инструкции по установке systemd service
- [ ] Настройка cron
- [ ] Мониторинг и healthcheck

**Оценка времени:** ~3.5 часа

**Зависимости:** DigestOrchestrator (MVP-5), MonitoringService (MVP-6)

---

### MVP-8. Testing & Documentation

**Цель:** Покрытие тестами и обновление документации.

#### Задачи:

**8.1 Testing Strategy** (~2 часа)
- [ ] Обновить TESTING.md с учетом MVP модулей
- [ ] Unit-тесты: 80% coverage для core логики
- [ ] Component-тесты: DigestOrchestrator с моками
- [ ] E2E тест: полный цикл на VPS (manual)
- [ ] CI: `swift test` в GitHub Actions

**8.2 Documentation Updates** (~2 часа)
- [ ] README.md: Quick Start для MVP
- [ ] DEPLOY.md: Полная инструкция деплоя
- [ ] TROUBLESHOOTING.md: Частые ошибки MVP
- [ ] ARCHITECTURE.md: Диаграммы новых модулей
- [ ] .env.example: Все переменные окружения

**Оценка времени:** ~4 часа

**Зависимости:** Все предыдущие модули

---

## 💡 Low Priority (Technical Debt)

### TD-1. EnvironmentService абстракция

**Цель:** Типобезопасное чтение credentials из env.

- [ ] Протокол `EnvironmentServiceProtocol`
- [ ] `ProcessInfoEnvironmentService` для macOS/Linux
- [ ] `AppConfiguration` struct для типобезопасной конфигурации
- [ ] Валидация обязательных переменных при старте
- [ ] Unit-тесты

**Приоритет:** Нужно для MVP-2 и MVP-3 (перед началом)

**Оценка времени:** ~1.5 часа

---

### TD-2. Рефакторинг параметров TDLib

**Цель:** Улучшить читаемость и maintainability.

- [ ] Создать `Sources/TDLibAdapter/TDLibParameters.swift`
- [ ] Static метод `buildParameters(from config: TDConfig) -> [String: Any]`
- [ ] Документация каждого параметра

**Приоритет:** Low (можно сделать параллельно с MVP-1)

**Оценка времени:** ~1 час

---

### TD-3. Улучшение request-response механизма

**Цель:** Использовать `@extra` механизм TDLib вместо polling.

- [ ] Изучить механизм `@extra` в TDLib
- [ ] Рассмотреть варианты: async continuation, `AsyncStream`
- [ ] Вынести в переиспользуемую функцию `sendRequest<T>()`

**Приоритет:** Medium (нужно для множества запросов)

**Оценка времени:** ~2-3 часа

---

## 🔗 Документация

**Основные документы:**
- [MVP.md](.claude/MVP.md) - цели и scope MVP
- [ARCHITECTURE.md](.claude/ARCHITECTURE.md) - архитектура проекта
- [DEVELOPMENT.md](.claude/DEVELOPMENT.md) - правила разработки
- [TESTING.md](.claude/TESTING.md) - стратегия тестирования
- [BACKLOG.md](.claude/BACKLOG.md) - бэклог для версий после MVP
- [CHANGELOG.md](.claude/CHANGELOG.md) - история изменений

**Инфраструктура:**
- [SETUP.md](.claude/SETUP.md) - настройка окружения
- [DEPLOY.md](.claude/DEPLOY.md) - деплой на Linux VPS
- [CREDENTIALS.md](.claude/CREDENTIALS.md) - управление секретами
- [TROUBLESHOOTING.md](.claude/TROUBLESHOOTING.md) - частые проблемы

---

**Последнее обновление:** 2025-11-11
**Архив завершенных задач:** См. [CHANGELOG.md](.claude/CHANGELOG.md) (2025-11-06 | Архивация завершенных задач)

---

## 📚 Technical Debt (Documentation)

### TD-4. Автогенерация DoCC для внутренних моделей и компонентных тестов

**Цель:** Расширить `./scripts/generate-docc-from-tests.sh` для автоматической генерации документации из тестов.

**Проблема:**
- Сейчас скрипт работает только для E2E сценариев
- Компонентные тесты не генерируют документацию (нет ссылок на упоминаемые Request/Response модели)
- Внутренние модели DigestCore (ChannelInfo, SourceMessage) не документируются автоматически

**Требования:**
1. **Компонентные тесты** → DoCC статьи:
   - Пример: `TgClientComponentTests/TDLibAdapter/GetChatsTests.swift` → `GetChatsComponent.md`
   - Автоматический парсинг упоминаний Request/Response моделей в комментариях
   - Генерация ссылок: `- Request: <doc:GetChatsRequest>`, `- Response: <doc:ChatsResponse>`

2. **Unit-тесты внутренних моделей** → DoCC статьи:
   - Пример: `TgClientUnitTests/DigestCore/ChannelCacheTests.swift` → `ChannelCacheUnit.md`
   - Парсинг использованных моделей: `ChannelInfo`, `SourceMessage`
   - Генерация ссылок на модели

3. **Обновить скрипт:**
   - Добавить обработку `Tests/TgClientComponentTests/` (рекурсивно)
   - Добавить обработку `Tests/TgClientUnitTests/` (для DigestCore моделей)
   - Regex для парсинга упоминаний моделей в комментариях

**Задачи:**
- [ ] Изучить текущий скрипт `generate-docc-from-tests.sh`
- [ ] Добавить функцию `generate_component_docs()` для компонентных тестов
- [ ] Добавить функцию `generate_unit_model_docs()` для внутренних моделей
- [ ] Обновить regex для парсинга упоминаний Request/Response (например, `GetChatsRequest`, `ChatsResponse`)
- [ ] Добавить автоматическую генерацию ссылок `<doc:ModelName>`
- [ ] Протестировать на существующих тестах (GetChatsTests, ChannelCacheTests)
- [ ] Обновить `.github/workflows` для автогенерации в CI

**Приоритет:** Medium (нужно после завершения MVP-1.6, перед финальной документацией)

**Оценка времени:** ~2-3 часа

**Зависимости:** Нет (можно делать параллельно)

---

### TD-5: Централизованные Encoder/Decoder + SwiftLint правила ⚠️ CRITICAL

**Проблема:**
- В проекте используются разные способы создания encoder/decoder
- Нет гарантии консистентности настроек (snake_case маппинг)
- Регулярно добавляется `import XCTest` вместо Swift Testing
- Нет автоматической проверки правил кодирования

**Цель:**
1. Централизовать создание encoder/decoder через `.tdlib()` factory методы
2. **ЗАПРЕТИТЬ** использование `JSONEncoder()` / `JSONDecoder()` напрямую во всём проекте
3. Добавить SwiftLint rules для автоматической проверки:
   - Блокировать `import XCTest` (должен быть `import Testing`)
   - Блокировать `JSONEncoder()` / `JSONDecoder()` (должны быть `.tdlib()`)
4. Создать test builders для упрощения тестов

**Решение:**

**Фаза 1: Централизованные Encoder/Decoder** ✅ **[ЗАВЕРШЕНО 2025-11-10]** (~40 мин)
- [x] Создать `Sources/FoundationExtensions/JSONCoding.swift` (модуль вместо Shared):
  ```swift
  import Foundation

  extension JSONEncoder {
      /// Централизованный encoder для TDLib API.
      ///
      /// Настройки:
      /// - snake_case encoding для всех ключей
      public static func tdlib() -> JSONEncoder {
          let encoder = JSONEncoder()
          encoder.keyEncodingStrategy = .convertToSnakeCase
          return encoder
      }
  }

  extension JSONDecoder {
      /// Централизованный decoder для TDLib API.
      ///
      /// Настройки:
      /// - snake_case decoding для всех ключей
      public static func tdlib() -> JSONDecoder {
          let decoder = JSONDecoder()
          decoder.keyDecodingStrategy = .convertFromSnakeCase
          return decoder
      }
  }
  ```
- [x] Найти все `JSONEncoder()` → заменить на `JSONEncoder.tdlib()` (11 файлов)
- [x] Найти все `JSONDecoder()` → заменить на `JSONDecoder.tdlib()` (11 файлов)
- [x] Удалить избыточные CodingKeys из моделей (21 файл): оставлен только маппинг для `@type`
- [x] Создать unit-тесты для `.tdlib()` методов (16 тестов): базовые + краевые + round-trip
- [x] Прогнать тесты: 88 тестов проходят ✅

**Фаза 2: SwiftLint правила** ✅ **[ЗАВЕРШЕНО 2025-11-11]**
- [x] SwiftLint интегрирован (CI + Git hooks)
- [x] Настроены custom rules и disabled_rules для TDD
- [x] Проверено на Linux сервере — CI проходит успешно ✅

**Фаза 3: Test Builders (~2 часа)**
- [ ] Создать `Tests/TestHelpers/TDLibTestBuilders.swift`:
  - `func makeGetChatsRequest(...) -> GetChatsRequest`
  - `func makeGetChatsResponse(...) -> GetChatsResponse`
  - `func makeChatInfo(...) -> ChatInfo`
  - `func makeTDLibError(...) -> TDLibErrorResponse`
- [ ] Рефакторить существующие тесты, убрать raw JSON где возможно
- [ ] Обновить TESTING.md: добавить раздел "Test Builders"

**Фаза 4: Рефакторинг тестов (~2 часа)**
- [ ] Рефакторить GetChatsRequestTests (использовать builders)
- [ ] Рефакторить TDLibErrorResponseTests (использовать builders)
- [ ] Рефакторить LoadChatsRequestTests (использовать builders)
- [ ] Прогнать все тесты, убедиться что ничего не сломалось

**Приоритет:** CRITICAL (блокирует консистентность кода)

**Оценка времени:** ~5-6 часов (фаза 1+2 критична, фаза 3+4 можно отложить)

**Зависимости:** Нет (можно делать сразу)

**Ссылки:**
- SwiftLint: https://github.com/realm/SwiftLint
- Custom Rules: https://realm.github.io/SwiftLint/rule-directory.html

### TD-6: Unit-тесты для TDLibRequestEncoder ✅ **[ЗАВЕРШЕНО 2025-11-10]**

**Проблема:**
- `TDLibRequestEncoder` использует `JSONEncoder.tdlib()`, но нет прямых тестов
- Нужна уверенность что Request модели правильно энкодятся с `.convertToSnakeCase`
- Сырой JSON в тестах показывает ожидаемый формат для TDLib API

**Цель:**
Создать unit-тесты для `TDLibRequestEncoder`, проверяющие:
1. Правильное использование `.tdlib()` encoder
2. Корректную конвертацию camelCase → snake_case
3. Сохранение явных CodingKeys (например, `@type`)

**Решение (~30 мин):**
- [x] Создать `Tests/TgClientUnitTests/TDLibAdapter/TDLibRequestEncoderTests.swift` (4 теста)
- [x] Тесты на реальных Request моделях:
  - `SetTdlibParametersRequest` (много полей с snake_case)
  - `LoadChatsRequest` (chatList → chat_list)
- [x] Проверить что в JSON используется snake_case
- [x] Round-trip тест: encode → parse JSON → проверить ключи
- [x] **Бонус:** Создать `TDLibResponseDecoderTests.swift` (5 тестов)
  - Проверка декодирования snake_case → camelCase
  - Тесты на UserResponse, ChatsResponse, TDLibErrorResponse
  - Опциональные поля, массивы, пустые массивы

**Результат:** 92 теста проходят (было 88, добавили 9 новых)

**Зависимости:** TD-5 Phase 1 (завершена)

---

### TD-8: Удаление getChats (заменён на loadChats + getChat)

**Проблема:**
- Метод `getChats()` возвращает только список ID чатов
- Для получения полной информации всё равно нужен `getChat(chatId:)` для каждого ID
- Правильный подход: `loadChats()` (pagination) + `getChat()` (детали)

**Используется только в:**
- `main.swift` (строка 67) - простая проверка после авторизации
- Unit-тесты (`GetChatsRequestTests`, `ChatsResponseTests`)
- MockTDLibClient
- DoCC документация

**Решение (~30 мин):**
- [ ] Заменить `getChats()` в `main.swift` на `loadChats()` + `getChat()` пример
- [ ] Удалить метод из `TDLibClientProtocol`
- [ ] Удалить реализацию из `TDLibClient+HighLevelAPI.swift`
- [ ] Удалить метод из `MockTDLibClient`
- [ ] Удалить `GetChatsRequest.swift`
- [ ] Удалить `ChatsResponse.swift`
- [ ] Удалить `GetChatsRequestTests.swift`
- [ ] Удалить `ChatsResponseTests.swift`
- [ ] Удалить DoCC документацию (`GetChatsRequestTests.md`, `ChatsResponseTests.md`)
- [ ] Запустить тесты: убедиться что всё компилируется

**Приоритет:** Low (после завершения MVP-1.7 Phase 3 - loadChats/getChat реализации)

**Оценка времени:** ~30 минут

**Зависимости:** MVP-1.7 Phase 3 (loadChats/getChat реализация должна быть завершена и проверена)

---

### TD-7: Test Builders + убрать raw JSON из ResponseTests ✅ **[ЗАВЕРШЕНО 2025-11-11]**

**Результат:**
- [x] TestHelpers модуль с `Encodable.toTDLibData()` helper
- [x] `TDLibResponse` перешёл на `Codable` для round-trip тестов
- [x] Убран raw JSON из всех Response тестов
- [x] 91 unit-тест проходят ✅

---
