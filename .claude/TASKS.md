# Задачи проекта

> **Последнее обновление:** 2025-12-08 (getChatHistory bugfix завершён)
> **Текущая версия:** v0.3.0 (осталось: TSan проверка)

---

## 🔄 НАПОМИНАНИЕ: Проверка ретро (2025-12-08)

**Статус:** ⏳ следующая проверка через 3 дня (2025-12-08)

**Что делать:**
1. Выполнить промпт: [TASKS.md#проверка-гипотез-ретро](#-проверка-гипотез-ретро)
2. Append результат в [RETRO-RESULT.md](archived/RETRO-RESULT.md)
3. Обновить эту дату на +3 дня

**История:**
- ✅ 2025-12-05 - первая проверка выполнена (инцидент: чуть не создали MockSummaryGenerator)

---

## ✅ ЗАВЕРШЕНО: SwiftPM Bug Investigation + Community Response

**Статус:** ✅ Полная диагностика завершена, отчёты отправлены

**Linux (завершено):**
- ✅ Swift 6.2 → 6.0 downgrade
- ✅ Package.swift: `swift-tools-version: 6.0`
- ✅ Проверено: сборка, тесты, incremental builds работают
- ✅ Отчёт SwiftPM мейнтейнеру: https://github.com/swiftlang/swift-package-manager/issues/9441

**Диагностика (2025-12-07):**
- ✅ strace test на Linux (KVM) - обнаружен livelock в epoll_wait()
- ✅ strace test на macOS (Docker Desktop) - НЕ воспроизводится
- ✅ lldb backtrace получен (bare metal Swift 6.2.1) - **корневая причина найдена!**
- ✅ Системная информация собрана для хостера
- ✅ Ответы отправлены в Swift Forums + GitHub Issue

**Ключевые находки:**
1. **Root cause: flock() deadlock** - SwiftPM зависает на `FileLock.lock()` в `Lock.swift:146`
2. **НЕ epoll issue** - strace был misleading, настоящая проблема в file locking
3. **KVM-specific issue** - проблема воспроизводится только на KVM virtualization
4. **НЕ network issue** - strace показал отсутствие GitHub вызовов
5. **Окружение:** Ubuntu 24.04.3, kernel 6.8.0-60, KVM, 1 CPU core, 961Mi RAM

**lldb backtrace (критичный thread #2):**
```
frame #0: libc.so.6`flock + 11
frame #1: swift-package`FileLock.lock(type=, blocking=) at Lock.swift:146:16
frame #2: swift-package`SwiftCommandState.acquireLockIfNeeded() at SwiftCommandState.swift:1103:39
```

**Community Response:**
- Swift Forums: https://forums.swift.org/t/83562 - KVM virtualization гипотеза
- GitHub Issue: 3 комментария (strace + lldb backtrace + flock analysis)
- Хостер: отчёт + strace logs (swiftpm-strace.log.gz, 170KB)

**macOS (TODO на следующей сессии):**
1. Установить Swift 6.0 toolchain на macOS
2. Проверить сборку и тесты
3. Запустить E2E тест `SummaryGenerationE2ETests` (отложен с Linux)
4. Проверить TSan на macOS (отложен с Linux)

**Детали:** см. `.claude/archived/swiftpm-hang-testing-2025-12-05.md`

---

## 📋 Текущая задача

### ✅ BUGFIX v0.3.0: getChatHistory + folder фильтрация — ЗАВЕРШЁН

**Статус:** ✅ Завершён (2025-12-08)

**Выполнено:**
1. ✅ Применена корректная логика getChatHistory для непрочитанных:
   - `lastReadInboxMessageId=0` → `(fromMessageId=0, offset=0, limit=N)`
   - `lastReadInboxMessageId>0` → `(fromMessageId=lastRead, offset=-N, limit=N)`
   - Добавлен параметр `maxChatHistoryLimit` (default: 100)
2. ✅ Исправлена фильтрация каналов: folder > archive (приоритет folder)
3. ✅ Удалены DEBUG логи
4. ✅ Добавлены regression tests (+2 теста для getChatHistory)
5. ✅ Обновлён тест для folder > archive фильтрации
6. ✅ 205 тестов GREEN (было 203)
7. ✅ E2E проверка на реальном клиенте: работает корректно
8. ✅ 3 коммита созданы (Sources, Tests, Docs)

**Research-First:**
- Создан тестовый канал @aidigestcreator
- Live эксперименты с offset на реальном TDLib
- WebFetch документации для уточнения семантики

**Изменённые файлы:**
- `Sources/DigestCore/Sources/ChannelMessageSource.swift` — getChatHistory логика + folder фильтрация
- `Tests/TgClientComponentTests/DigestCore/ChannelMessageSourceTests.swift` — +2 теста

**Ретроспектива:**
- Зафиксирован анализ в `.claude/retro-v0.3.0-questions.md` (Вопрос 4)
- Research-First спас от пропущенной логики
- Обсуждение != Реализация (нужен failing test как якорь)

---

### v0.3.0: DigestOrchestrator — ЗАВЕРШЁН ✅

**Полный scope:** см. [MVP.md - SummaryGenerator](MVP.md#2-summarygenerator-в-разработке)

**Стратегия:** Outside-In TDD с правилом "Mock только boundaries"
1. ✅ **SummaryGenerator:** OpenAISummaryGenerator + HTTPClient абстракция
2. ✅ **DigestOrchestrator:** Координация pipeline с логированием
3. ✅ **E2E тест:** Включён (Swift 6.0 решил SwiftPM bug!)

**Итого тестов:** 146 passed (было 128 в v0.2.0)
- Component: 5 (DigestOrchestrator) + 6 (OpenAISummaryGenerator) = 11
- Unit: 7 (Models + JSONCoding)
- E2E: 1 (реальный OpenAI API)

---

### ✅ Завершено (сессия 2025-12-05 #2: DigestOrchestrator)

**DigestOrchestrator реализация:**
1. ✅ Component тест (RED) - DigestOrchestratorTests.swift (5 тестов)
2. ✅ DigestOrchestrator.swift - координатор с логированием
3. ✅ E2E тест включён - SummaryGenerationE2ETests (Swift 6.0 fix)
4. ✅ Все тесты GREEN - 146/146 passed

**Новые файлы:**
- `Sources/DigestCore/Orchestrators/DigestOrchestrator.swift` - координатор pipeline
- `Tests/TgClientComponentTests/DigestCore/DigestOrchestratorTests.swift` - Component тесты (5)

**Изменённые файлы:**
- `Tests/TgClientE2ETests/SummaryGenerationE2ETests.swift` - убран .disabled(), тест включён

**Решения/контекст:**
- **Правило мокирования соблюдено:** DigestOrchestrator использует реальный OpenAISummaryGenerator + MockHTTPClient (НЕ MockSummaryGenerator!)
- **E2E работает на Linux:** Swift 6.0 решил проблему SwiftPM incremental build hang
- **v0.3.0 Scope:** Только координация SummaryGenerator (MessageSource/BotNotifier интеграция — в v0.4.0)
- **Actor isolation:** DigestOrchestrator = actor для thread-safe логирования

**Тесты:** 5 Component + 1 E2E = 6 новых тестов

---

### ✅ Завершено (сессия 2025-12-05 #1: GitHub + Ретро)

**Документация (критичное исправление):**
1. ✅ **Правило "Mock только boundaries"** добавлено в TESTING.md + ROLES.md
2. ✅ **Проверка ретро (первая)** - выполнена, найден инцидент
3. ✅ **GitHub issue #9441** - мейнтейнер ответил (статус обновлён)
4. ✅ **Напоминание ретро** - добавлено в TASKS.md (2025-12-08)

**Component тесты (Цикл 3):**
1. ✅ MockHTTPClient - Result-based реализация с actor isolation
2. ✅ OpenAIModels - вынесены в отдельный файл (Request/Response)
3. ✅ JSONEncoder/Decoder.openAI() - централизованные кодеры
4. ✅ Component тесты OpenAISummaryGenerator - 6 тестов (все GREEN)
5. ✅ Unit тесты OpenAIModels - 3 roundtrip теста (все GREEN)
6. ✅ Unit тесты JSONCoding - 3 теста для OpenAI API (все GREEN)
7. ✅ OpenAIError - добавлен Equatable для Swift Testing

**Файлы (новые):**
- `Sources/DigestCore/Generators/OpenAIModels.swift` - модели OpenAI API
- `Tests/TgClientComponentTests/DigestCore/OpenAISummaryGeneratorTests.swift` - Component тесты (6)
- `Tests/TgClientUnitTests/DigestCore/OpenAIModelsTests.swift` - Unit тесты (3)
- `Sources/FoundationExtensions/JSONCoding.swift` - добавлены .openAI() методы
- `Tests/TgClientUnitTests/FoundationExtensions/JSONCodingTests.swift` - Unit тесты (3)

**Файлы (изменённые):**
- `Tests/TestHelpers/MockHTTPClient.swift` - реализован (Result-based + actor isolation)
- `Sources/DigestCore/Generators/OpenAISummaryGenerator.swift` - использует JSONEncoder/Decoder.openAI()

**Решения/контекст:**
- **TDD цикл:** RED (Component) → GREEN (MockHTTPClient + Models) → Unit тесты → REFACTOR
- **Без raw JSON:** Unit тесты используют roundtrip (encode → decode), документация в ссылках на API
- **Actor isolation:** MockHTTPClient.setStubResult() вместо прямого доступа к var
- **OpenAIError.Equatable:** для Swift Testing #expect(throws:)
- **⚠️ Инцидент:** Чуть не создали MockSummaryGenerator (остановил пользователь) → правило было в ретро, но не в TESTING.md

**Тесты:** 13 passed (6 Component + 7 Unit)

---

### ✅ Завершено (сессия 2025-12-04)

**Цикл 1:**
1. ✅ Spike - OpenAI API исследован + research библиотек
2. ✅ DocC документация - SummaryGenerator.md (85 строк)
3. ✅ E2E тест (RED) - SummaryGenerationE2ETests.swift
4. ✅ SummaryGeneratorProtocol - интерфейс создан
5. ✅ OpenAISummaryGenerator - реализация с URLSession
6. ⏳ E2E → GREEN - **отложен до macOS** (SwiftPM bug)

**Цикл 2:**
7. ✅ HTTPClientProtocol + HTTPError (best practices)
8. ✅ URLSessionHTTPClient - продакшн реализация
9. ✅ MockHTTPClient - заглушка с TODO
10. ✅ Refactor - inject HTTPClient в OpenAISummaryGenerator
11. ✅ OpenAIError - добавлены unauthorized, rateLimited

**Файлы:**
- `Sources/DigestCore/HTTP/HTTPClientProtocol.swift`
- `Sources/DigestCore/HTTP/URLSessionHTTPClient.swift`
- `Sources/DigestCore/Generators/OpenAISummaryGenerator.swift` (refactored)
- `Tests/TestHelpers/MockHTTPClient.swift` (заглушка)
- `.claude/archived/openai-libraries-research-2025-12-04.md`

---

### 🎯 Следующие шаги

## 🚀 Release Checklist: v0.3.0

**Статус:** ⏳ В процессе
**Цель:** Получить первый real-world дайджест + git tag v0.3.0

---

## 🐛 КРИТИЧНЫЙ BUGFIX: Архивные каналы в дайджесте

**Проблема:** `loadChats(chatList: .main)` возвращает архивные каналы → попадают в дайджест

**Причина:**
- TDLib присылает `updateNewChat` БЕЗ поля `positions` (пустое)
- Реальные позиции приходят в `updateChatPosition` (который мы НЕ декодируем)
- Слушаем только `updateNewChat` → теряем информацию о списках (.main, .archive, .folder)

**Решение:** Декодировать `updateChatPosition`, мержить positions, фильтровать архивные

**Подход:** Bugfix (Fix → E2E → Regression Test) - см. [retro-v0.3.0-questions.md](retro-v0.3.0-questions.md)

---

### Шаг 1: Модели и декодирование

- [ ] **ChatList enum** - `.main`, `.archive`, `.folder(id: Int)`
  - Файл: `Sources/TgClientModels/Models/ChatList.swift`
  - Decode из: `{"@type": "chatListMain"}`, `"chatListArchive"`, `{"@type": "chatListFolder", "chat_folder_id": 123}`

- [ ] **ChatPosition struct** - (list, order, isPinned)
  - Файл: `Sources/TgClientModels/Models/ChatPosition.swift`
  - Поля: `list: ChatList`, `order: Int64`, `isPinned: Bool`

- [ ] **ChatResponse.positions** - добавить поле
  - Файл: `Sources/TgClientModels/Responses/ChatResponse.swift`
  - `public let positions: [ChatPosition]`
  - Decode как опциональное (может быть пустым в updateNewChat)

- [ ] **Update.chatPosition case** - добавить
  - Файл: `Sources/TgClientModels/Responses/Update.swift`
  - `case chatPosition(chatId: Int64, position: ChatPosition)`
  - Decode из: `{"@type": "updateChatPosition", "chat_id": ..., "position": {...}}`

---

### Шаг 2: Фильтрация в ChannelMessageSource

- [ ] **Слушать updateChatPosition** в `loadAllChats()`
  - Файл: `Sources/DigestCore/Sources/ChannelMessageSource.swift`
  - В Task: `if case .chatPosition(chatId, position) = update`
  - Мержить positions в ChatCollector

- [ ] **ChatCollector: мержить positions**
  - Добавить метод: `updatePosition(chatId:, position:)`
  - При `add(chat)` - positions могут быть пустыми
  - При `updatePosition` - добавляем/обновляем position для chatId

- [ ] **Фильтровать архивные каналы**
  - После сбора всех чатов + positions
  - Фильтр: `chat.positions.contains { $0.list == .archive }` → удалить
  - Или: только чаты с position `.main` или `.folder` (без `.archive`)

---

### ❓ Вопрос для обсуждения: DigestOrchestrator - нужен ли?

**Проблема:** DigestOrchestrator добавляет дополнительный уровень абстракции, но по факту только вызывает SummaryGenerator + логирует.

**Текущая архитектура:**
```
DigestOrchestrator
  └─> SummaryGenerator (OpenAISummaryGenerator)
```

**Альтернатива:**
- Добавить логгер в SummaryGenerator напрямую
- Убрать DigestOrchestrator как избыточную абстракцию
- MessageSource → SummaryGenerator → BotNotifier (прямая цепочка)

**За DigestOrchestrator:**
- Координирует pipeline (потенциально может добавлять retry logic, fallback)
- Централизованное логирование на уровне "дайджест готов"
- Будущая extension: группировка сообщений, фильтрация

**Против:**
- Сейчас только proxy для SummaryGenerator
- Дополнительный уровень = сложность без выгоды
- Логгер можно inject в SummaryGenerator

**TODO:** Обсудить с пользователем и принять решение (удалить или оставить с планом расширения)

---

### ✅ Шаг 3: E2E manual + Research — ЗАВЕРШЁН

**Результаты:**
- ✅ Debug логи убраны
- ✅ Manual E2E выполнен (swift run tg-client)
- ✅ Research выполнен - обнаружены edge cases для тестов

**Обнаруженные edge cases от TDLib:**

1. **order=0 означает "убрать из списка"**
   - Большинство `chatListFolder` без `folder_id` приходят с `order=0`
   - Такие позиции нужно игнорировать (чат удалён из этого списка)

2. **chatListFolder без chat_folder_id**
   - TDLib присылает `type="chatListFolder"` БЕЗ поля `chat_folder_id`
   - Это удалённая/деактивированная папка
   - Всегда приходит с `order=0` → игнорируем

3. **isPinned может отсутствовать**
   - Поле `is_pinned` опционально в JSON
   - Нужен `decodeIfPresent` с default=false

4. **order приходит как String (не Int64)**
   - TDLib присылает большие числа (> 2^53) как String для точности
   - Пример: `"9221294784512000005"`
   - Нужен helper `decodeInt64(forKey:)` - создан ✅

5. **chat_folder_id приходит как Int (может быть String)**
   - По документации: `int32`
   - Для консистентности создан helper `decodeInt32(forKey:)` ✅

6. **Чат может иметь несколько positions**
   - Один чат может быть в нескольких списках одновременно
   - Пример: `.main` + `.folder(id: 123)` (обычный кейс)
   - Пример: `.main` + `.folder(id: 0, order=0)` (удалённая папка)
   - ChatCollector мержит positions по chatId ✅

7. **Все чаты имеют позицию в .main**
   - Даже архивные каналы имеют позицию в `.main` (с `order > 0`)
   - Поэтому фильтрация по `.archive` безопасна - чаты НЕ потеряются

**Файлы созданы:**
- `Sources/FoundationExtensions/KeyedDecodingContainer+Int64.swift` - helpers для int64/int32
- `Tests/TgClientUnitTests/FoundationExtensions/KeyedDecodingContainerInt64Tests.swift` - 12 Unit тестов (все GREEN)

---

### ✅ Шаг 4: Unit тесты на модели — ЗАВЕРШЁН

**Результаты:**
- ✅ ChatListTests - 11 тестов GREEN
- ✅ ChatPositionTests - 13 тестов GREEN
- ✅ UpdateTests - +6 тестов для chatPosition case GREEN
- ✅ Все тесты: 188/188 passed (было 146)

**Созданные файлы:**
- `Tests/TgClientUnitTests/Models/ChatListTests.swift` - 11 тестов
- `Tests/TgClientUnitTests/Models/ChatPositionTests.swift` - 13 тестов

**Изменённые файлы:**
- `Tests/TgClientUnitTests/TDLibAdapter/TDLibCodableModels/Responses/UpdateTests.swift` - +6 тестов
- `Sources/TgClientModels/Responses/Update.swift` - import FoundationExtensions, decodeInt64/decodeInt32
- `Sources/TgClientModels/Responses/ChatType.swift` - import FoundationExtensions, decodeInt64
- `Sources/TgClientModels/Responses/Message.swift` - import FoundationExtensions, decodeInt64
- `Sources/TgClientModels/Models/ChatPosition.swift` - public init, убран explicit mapping isPinned
- `Sources/TgClientModels/Requests/LoadChatsRequest.swift` - убран explicit mapping chatFolderId

**Важные находки:**
1. **Конфликт convertFromSnakeCase + explicit CodingKeys** - при использовании JSONDecoder.tdlib() НЕ нужны explicit mappings типа `case isPinned = "is_pinned"` - автоматическая конверсия работает
2. **Helper decodeInt64/decodeInt32 нужен везде** - TDLib присылает Int64/Int32 как String для больших чисел
3. **Public init для ChatPosition** - упрощает создание в тестах

---

### Шаг 5: Регрессионный Component тест (следующая задача)

- [ ] **ChannelMessageSourceTests: архивный канал**
  - Файл: `Tests/TgClientComponentTests/Sources/ChannelMessageSourceTests.swift`
  - Тест: "Архивный канал с unreadCount > 0 НЕ попадает в результат"
  - Mock: эмулировать `updateNewChat` + `updateChatPosition` с `.archive`
  - Expect: `fetchUnreadMessages()` возвращает пустой массив (или без этого канала)

- [ ] **ChannelMessageSourceTests: канал в папке**
  - Тест: "Канал в папке (.folder) с unreadCount > 0 попадает в результат"
  - Mock: `updateChatPosition` с `.folder(id: 123)`
  - Expect: канал присутствует в результате

- [ ] **ChannelMessageSourceTests: канал в архиве + папке**
  - Тест: "Канал одновременно в .archive и .folder НЕ попадает"
  - Mock: два `updateChatPosition` (один .archive, один .folder)
  - Expect: канал отфильтрован (archive имеет приоритет)

---

### Шаг 6: TSan проверка (Thread Sanitizer)

- [ ] **Запустить TSan на Unit тестах**
  - Команда: `swift test --sanitize=thread --filter TgClientUnitTests 2>&1`
  - Проверить: нет data races в ChatCollector (мержинг positions)
  - Проверить: нет data races в новых моделях

- [ ] **Если TSan находит race:**
  - Исправить (добавить actor isolation или locks)
  - Перезапустить TSan

---

### Шаг 7: Проверка всех тестов

- [ ] **Все тесты GREEN на macOS**
  - `swift test 2>&1` → ожидается 146 + новые тесты (~5-7) = ~152 тестов

- [ ] **Сборка работает на Linux** (если есть доступ)
  - `swift build` на Linux (через SSH или CI)
  - Убедиться что `ChatList`, `ChatPosition` компилируются

---

### Шаг 8: Мини-рефлексия Bugfix подхода

- [ ] **Провести мини-ретро** (5-10 минут)
  - Записать в [retro-v0.3.0-questions.md](retro-v0.3.0-questions.md) секцию "Bugfix процесс"
  - Вопросы:
    - Сработал ли E2E manual test ДО написания тестов? (нашли ли краевые кейсы?)
    - Помогло ли это избежать лишних итераций?
    - Не забыли ли регрессионный тест?
    - Что улучшить в процессе?

- [ ] **Документировать Bugfix процесс** в TESTING.md
  - Добавить секцию "Bugfix Workflow (известная проблема, ясное решение)"
  - Описать шаги: Fix → E2E → Unit → Regression → TSan → Рефлексия
  - Когда использовать vs TDD Red→Green

---

### Код и тесты
- [x] DigestOrchestrator Component тесты (5 тестов GREEN)
- [x] E2E тест включён и работает (SummaryGenerationE2ETests)
- [x] Все тесты GREEN (146/146 passed на macOS)
- [x] **Запуск E2E теста с реальным OpenAI API** - работает (6 сек, 469 chars дайджест)
- [x] **Проверка всех тестов на macOS** - Swift 6.1.2 работает корректно (SwiftPM баг только на Linux)

### Интеграция с реальными данными
- [x] **Pipeline работает на реальных данных** (TDLib → DigestOrchestrator → OpenAI)
- ⚠️ **Критичный баг найден:** Архивные каналы попадают в дайджест → см. Bugfix секцию выше

### Документация
- [x] CHANGELOG.md — v0.3.0 описан (сессия 2025-12-05)
- [x] **MVP.md** — обновлено "Текущая версия: 0.3.0" (2025-12-06)
- [x] **retro-v0.3.0-questions.md** — создан файл ретро с 2 вопросами для анализа
- [ ] **CLAUDE.md** — отложено (обновим после bugfix архивных каналов)
- [ ] **ARCHITECTURE.md** — проверить актуальность диаграмм
- [ ] **README.md** — проверить актуальность (если есть)

### Git и релиз
- [x] Коммиты сделаны (DigestOrchestrator + тесты)
- [x] Git push выполнен
- [ ] **Git tag v0.3.0** — создать после успешной проверки
- [ ] **GitHub Release** (опционально) — краткое описание v0.3.0

### Перед следующей версией
- [ ] **Ретроспектива v0.3.0** (через 3 дня после релиза)
  - [ ] Прочитать [archived/RETRO-RESULT.md](archived/RETRO-RESULT.md) (предыдущее ретро)
  - [ ] Проверить метрики из предыдущего ретро
  - [ ] Заполнить метрики в [retro-v0.3.0-questions.md](retro-v0.3.0-questions.md)
  - [ ] Ответить на вопросы (дублирование Mock, архивные каналы)
  - [ ] Проверить гипотезы (Research-First, краевые сценарии, Bugfix процесс)
  - [ ] Записать результаты в `archived/retro-v0.3.0-results.md`
- [ ] **Ревизия BACKLOG.md** — актуализировать после релиза
- [ ] **Планирование v0.4.0** — прочитать [v0.4.0-pipeline-integration-rfc.md](v0.4.0-pipeline-integration-rfc.md)

---

**v0.4.0 — Полный pipeline (планирование):**
- Прочитать RFC: [v0.4.0-pipeline-integration-rfc.md](v0.4.0-pipeline-integration-rfc.md)
- MessageSource → DigestOrchestrator интеграция
- BotNotifier реализация (Telegram Bot API)
- StateManager (timestamp JSON)
- E2E тест полного pipeline
- Retry logic (3x exponential backoff)

**Техдолг:**
- Thread Sanitizer анализ (отложено до macOS)

---

### ✅ SwiftPM Bug Investigation - Завершён (2025-12-05)

**Статус:** Регрессия локализована, отчёт отправлен, workaround применён

**Результаты тестирования:**
- ✅ Swift 6.2.1, 6.2, 6.1 → **зависают** на incremental builds (Planning build)
- ✅ Swift 6.0, 5.10 → **работают** корректно
- ✅ Регрессия между Swift 6.0 ↔ 6.1 (сентябрь-октябрь 2024)

**Отчёт мейнтейнеру:**
- **GitHub (1):** https://github.com/swiftlang/swift-package-manager/issues/9441#issuecomment-3616550867 (5 версий Swift)
- **GitHub (2):** https://github.com/swiftlang/swift-package-manager/issues/9441#issuecomment-3617201398 (Docker тест + объяснение CI gap)
- **Детали:** `.claude/archived/swiftpm-hang-testing-2025-12-05.md` (307 строк verbose логов)

**Workaround (применён):**
- Downgrade на Swift 6.0 на Linux
- Package.swift: `swift-tools-version: 6.0`
- Incremental builds: 2-3s (вместо зависания)

**Следующие шаги:**
- ✅ Мейнтейнер ответил (2025-12-05): скептически, считает environment-specific
- ✅ Репортер опроверг в Docker (issue OPEN, нет timeline fix)
- ⏳ Workaround (Swift 6.0) остаётся до upstream fix
- ⏳ Опубликовать решение на StackOverflow когда будет fix

---

### 2. Thread Sanitizer анализ [техдолг, низкий приоритет]

**Статус:**
- ✅ `swift build -c debug --sanitize=thread` работает на Linux
- ❌ `swift test --sanitize=thread` зависает (SwiftPM 6.2 bug)
- 📌 **Отложено до переезда на macOS** для отладки

**На macOS:**
```bash
swift test -c debug --sanitize=thread --filter TgClientUnitTests
```

---

## 🔄 Проверка гипотез ретро

_Раз в 1-3 дня. Результат записать в [RETRO-RESULT.md](archived/RETRO-RESULT.md)_

```
Дата: ____

## Метрики:
1. Race conditions (TSan): ___
2. Spike ДО реализации: ___ из ___ external APIs
3. Новые Mock >100 строк: ___
4. Закомментированные тесты: ___

## Инциденты:
- [ ] Все с regression тестом?

## Нарушения правил:
- Какие? Почему?

## Выводы:
- Работает:
- Не работает:
```

---

**Ссылки:**
- [MVP.md](MVP.md) — scope и статус MVP
- [BACKLOG.md](BACKLOG.md) — бэклог будущих фич
- [CHANGELOG.md](CHANGELOG.md) — история изменений
