# Задачи проекта

> **Текущая версия:** v0.3.0 ✅
> **В разработке:** v0.4.0 (mark-as-read)

---

## 🔄 НАПОМИНАНИЕ: Проверка метрик v0.4.0 (раз в 1-3 дня)

**Статус:** ⏳ следующая проверка _TBD_ (начать после первого коммита v0.4.0)

**Что делать:**
1. Скопировать промпт из [retro-v0.4.0-questions.md](archived/retro-v0.4.0-questions.md#-промпт-для-регулярного-отслеживания-раз-в-1-3-дня)
2. Запустить промпт в новой сессии
3. Append результат в [retro-v0.4.0-questions.md](archived/retro-v0.4.0-questions.md) (секция "Логи метрик")
4. Обновить эту дату на +1-3 дня

**Целевые метрики v0.4.0:**
- Research-First: 100% (было 25% в v0.3.0)
- Mock только boundaries: 100% (было 0% в v0.3.0)
- Дубликаты типов: 0% (было 16% в v0.3.0)
- Code Review: 100% дней с коммитами (новое)
- Concurrency: 0 рефакторингов из-за ошибок (новое)

---

## 📋 Текущие задачи

### 0. Генерация DocC документации 📝 ОПЦИОНАЛЬНО

**Приоритет:** 🟢 Низкий (не блокирует разработку)

**Задачи:**
- [ ] Сгенерировать DocC: `swift package generate-documentation`
- [ ] Проверить что все 4 E2E сценария видны

---

### 1. Реализация v0.4.0: Mark as Read ✅ ЗАВЕРШЕНО (2025-12-12)

**RFC:** [MVP.md § v0.4.0](MVP.md#v040-mark-as-read)

**Контекст:**
- Spike test viewMessages успешен → Response = OkResponse, идемпотентен
- E2E тест создан: Tests/TgClientE2ETests/MarkAsReadE2ETests.swift
- Временная модель ViewMessagesRequest в E2E тесте (нужно переместить в Sources/)

**Следующие шаги (TDD: Outside-In):**

1. [x] **Component Test (RED)** — MarkAsReadFlowTests happy path ✅
2. [x] **Models + Unit Tests** — ViewMessagesRequest: Codable ✅
3. [x] **MarkAsReadService implementation** → Component Test GREEN ✅
4. [x] **Component Tests (edge cases)** — empty, partial failure, large batch ✅ (timeout/cancellation → retry task)
5. [x] **TSan validation** — `swift test --sanitize=thread` ✅ (216 тестов CLEAN, MockLogger race fixed)
   - ⚠️ `swift run --sanitize=thread` несовместим с TDLib (uninstrumented C++ library → false positive)
   - ✅ Component-level TSan достаточно (покрывает весь Swift concurrency код)
6. [x] **main.swift integration** — добавлен MarkAsReadService в pipeline ✅
7. [x] **Retry strategy для DigestOrchestrator** ✅ (добавлено в v0.4.0)
   - RetryHelpers с exponential backoff (1s, 2s, 4s)
   - TSan проверка (CLEAN)
   - 6 component тестов для retry логики
   - `baseDelay` параметризация для быстрых тестов (0.1s)
   - Детали: Sources/FoundationExtensions/RetryHelpers.swift
8. [x] **E2E validation + Spike Test** — ✅ **ЗАВЕРШЕНО** (2025-12-12)

   **Результат spike research:**
   - ✅ viewMessages([maxMessageId], forceRead=true) РАБОТАЕТ **БЕЗ** openChat/closeChat!
   - ✅ Spike test: **100% success rate** (5/5 чатов помечены прочитанными)
   - ✅ Manual UI verification: badge исчез во всех тестовых каналах
   - ✅ unreadCount обновляется асинхронно через updateChatReadInbox event

   **Root Cause найден:**
   - ❌ ПРОБЛЕМА: getChatHistory(fromMessageId=lastRead, offset=-N) возвращал УЖЕ прочитанные сообщения
   - ✅ РЕШЕНИЕ: getChatHistory(fromMessageId=0) - получает последние N сообщений

   **Что сделано:**
   - ✅ ChannelMessageSource: фикс getChatHistory(fromMessageId=0)
   - ✅ MarkAsReadService: viewMessages([max(messageIds)])
   - ✅ Unsupported сообщения возвращаются с content="" (тоже помечаются прочитанными)
   - ✅ Production логирование (info level) для troubleshooting

9. [x] **Cleanup spike кода** — ✅ **ЗАВЕРШЕНО** (2025-12-12)
   - ✅ Удалены openChat/closeChat из TDLibClient+HighLevelAPI.swift
   - ✅ Удалены openChat/closeChat из TDLibClientProtocol.swift
   - ✅ Удалён spike verification блок из main.swift
   - ✅ Удалены временные модели из MarkAsReadE2ETests.swift

10. [x] **Media Support** — ✅ **ЗАВЕРШЕНО** (2025-12-12)
    - ✅ MessageContent расширен: photo/video/voice/audio с caption
    - ✅ ChannelMessageSource: извлечение caption из всех типов
    - ✅ 12 Unit тестов (MessageContentTests.swift) — все прошли
    - ✅ 1 Component тест (fetchUnreadMessagesMixedContentTypes) — прошёл

11. [x] **Plan Mode + Release** — ✅ **ЗАВЕРШЕНО** (2025-12-12)
    - ✅ E2E тест: badge исчез, markAsRead работает
    - ✅ TSan: 248 тестов CLEAN (0 data races)
    - ✅ swift run: photo с caption → OpenAI digest → markAsRead успешен

**Acceptance Criteria:** ✅ Все критерии выполнены (см. [MVP.md § v0.4.0](MVP.md#v040-mark-as-read))

**Метрики v0.4.0:**
- Research-First: 100% (viewMessages, getChatHistory, OpenAI API)
- Mock только boundaries: 100% (MockTDLibFFI, MockHTTPClient)
- Дубликаты типов: 0%
- TSan: 0 data races, 1 race condition найден и исправлен (MockLogger)
- Code Review: 100% дней с коммитами

**Документация:**
- ARCHITECTURE.md: Pipeline Flow & Error Handling актуализирован
- MVP.md: v0.4.0 + v0.5.0 + v0.7.0 roadmap
- TASKS.md: финальный статус ✅ ЗАВЕРШЕНО
- CHANGELOG.md: релизные ноты v0.4.0 (prepend)

---

### 2. TSan учения 🔧 ТЕХ ДОЛГ

**Статус:** ✅ **ВЫПОЛНЕНО** (2025-12-12)

**Результат:** TSan успешно обнаружил race condition в реальном коде при тестировании v0.4.0

**Что произошло:**
- Запущен `swift test --sanitize=thread --filter MarkAsReadFlowTests`
- TSan обнаружил concurrent access к `MockLogger.messages` array
- Исправлено: добавлен NSLock для защиты shared mutable state
- Проверка: TSan clean (0 warnings)

**Выводы:**
- TSan эффективен для обнаружения data races
- Проблема НЕ видна без TSan (проект собирался, тесты проходили)
- Race condition в MockLogger появился при параллельных запросах (50 чатов в TaskGroup)

**Файлы:**
- Исправление: Tests/TgClientComponentTests/Mocks/MockLogger.swift
- Тесты: MarkAsReadFlowTests.swift (4 component tests)

**Детали:** [BACKLOG.md#thread-sanitizer-tsan-учения](BACKLOG.md#thread-sanitizer-tsan-учения)

---

### 3. Research: Retry Strategy 🧪 ИССЛЕДОВАНИЕ

**Статус:** ✅ **ВЫПОЛНЕНО** (2025-12-12)

**Результат:** Реализован retry механизм для DigestOrchestrator с exponential backoff

**Что сделано:**
- ✅ Plan Mode: исследование Swift retry best practices (Medium, Swift by Sundell, AWS SDK)
- ✅ ARCHITECTURE.md: секция "Pipeline Flow & Error Handling" с retry стратегиями
- ✅ RetryHelpers: `withRetry()` + `withTimeout()` в Sources/FoundationExtensions
- ✅ Unit тесты: 11 тестов для RetryHelpers (RED → GREEN)
- ✅ TSan validation: CLEAN (thread-safe счётчики через actors)
- ✅ OpenAIError.is5xx helper: 7 unit тестов
- ✅ DigestOrchestrator retry: 6 component тестов (500→success, 429→success, exhausted retries)
- ✅ MockHTTPClient: queue-based stubbing для retry тестов
- ✅ Параметризация задержек: `baseDelay` для быстрых тестов (100ms вместо 1s)

**Файлы:**
- Sources/FoundationExtensions/RetryHelpers.swift
- Tests/TgClientUnitTests/FoundationExtensions/RetryHelpersTests.swift
- Tests/TgClientUnitTests/FoundationExtensions/TestHelpers/{CallCounter,DelayRecorder,BoolFlag}.swift
- Sources/DigestCore/Orchestrators/DigestOrchestrator.swift (добавлен retry)
- Tests/TgClientComponentTests/DigestCore/DigestOrchestratorTests.swift (6 retry тестов)
- Tests/TestHelpers/MockHTTPClient.swift (callCount + queue-based stubbing)

**Ретро-вопрос добавлен:**
- "Оптимизация тестовых задержек — почему не предложено автоматически?" (retro-v0.4.0-questions.md)

**Детали:** [План в .claude/plans/crispy-zooming-sedgewick.md]

---

### 4. Документация: ARCHITECTURE.md Pipeline Diagram 📝 ТЕХ ДОЛГ

**Приоритет:** 🟢 Низкий (часть v0.4.0, но не блокирует)

**Цель:** Обновить ARCHITECTURE.md с диаграммой нового pipeline (параллельное выполнение)

**Когда:** После завершения задачи #1 (когда pipeline реализован).

---

### 5. Swift 6.2 Concurrency Flags 🔧 ТЕХ ДОЛГ

**Приоритет:** 🟢 Низкий (nice to have)

**Цель:** Проверить новые concurrency флаги Swift 6.2

**Флаги:**
- `NonisolatedNonsendingByDefault`
- `InferIsolatedConformances`

**Детали:** [BACKLOG.md#thread-sanitizer-tsan-учения](BACKLOG.md#thread-sanitizer-tsan-учения)

---

### 6. Мониторинг SwiftPM Issue #9441 🎯 КРИТИЧНО

**Статус:** ✅ **PR #9493 MERGED** (2025-12-12) 🎉

**Фикс:** PR #9493 — фикс deadlock в incremental builds на KVM
**Merged:** https://github.com/swiftlang/swift-package-manager/pull/9493#event-21526083511

**План тестирования:**
- [x] **Мониторить merge** PR #9493 в ветку `main` или `6.3` ✅ MERGED
- [ ] **Скачать development snapshot** с https://www.swift.org/install/linux/ (ожидать появление snapshot с фиксом)
- [ ] **Протестировать на Linux (UFO Hosting KVM):**
  - Установить snapshot
  - Запустить clean build
  - Запустить incremental build (должна работать за 1-3 сек, не зависать)
  - Проверить что НЕ нужен workaround build-clean.sh
- [ ] **Отписаться в issue** с результатами тестирования
- [ ] **Закрыть issue #9441** после успешной проверки
- [ ] **Обновить StackOverflow** (отметить решение)
- [ ] **Обновить Swift Forums** (отметить решение)

**Следующий шаг:** Дождаться появления development snapshot (обычно 1-2 дня после merge)

**Команда для проверки snapshot:**
```bash
# Проверить доступность нового snapshot
curl -s https://download.swift.org/development/ubuntu2204/latest-build.yml | grep date
```

---

### 7. Ретроспектива v0.4.0 🔍 СЛЕДУЮЩАЯ ЗАДАЧА

**Приоритет:** 🔥 Высокий (после релиза)

**Цель:** Провести ретроспективу релиза v0.4.0 для анализа процесса и выводов

**План:**
- [ ] **Code review на свежую голову** (утром после релиза)
- [ ] **Проверка метрик** из `.claude/archived/retro-v0.4.0-questions.md`:
  - Research-First: 100%?
  - Mock только boundaries: 100%?
  - Дубликаты типов: 0%?
  - TSan: сколько race conditions найдено?
  - Преждевременное завершение дебага: 0 попыток?
- [ ] **Анализ инцидентов:**
  - Инцидент #1: viewMessages без openChat (spike research успешен)
  - Инцидент #2: MockLogger race condition (TSan обнаружил)
  - Что ещё пошло не так?
- [ ] **Что улучшить в v0.5.0:**
  - Процесс TDD
  - Research-First workflow
  - Code review timing
- [ ] **Обновить `.claude/archived/retro-v0.4.0-questions.md`** с финальными выводами
- [ ] **Append в `.claude/archived/RETRO-RESULT.md`** (дата 2025-12-12)

**Триггер:** После финализации v0.4.0 релиза (коммиты созданы, перед push)

**Документы:**
- `.claude/archived/retro-v0.4.0-questions.md` — гипотезы и вопросы
- `.claude/archived/RETRO-RESULT.md` — история ретроспектив

---

**Ссылки:**
- [MVP.md](MVP.md) — scope и статус MVP
- [BACKLOG.md](BACKLOG.md) — бэклог будущих фич
- [CHANGELOG.md](CHANGELOG.md) — история изменений
