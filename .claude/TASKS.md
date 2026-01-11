# Задачи проекта

> **Текущая версия:** v0.4.0 ✅
> **В разработке:** TBD (см. задачи ниже)

---

## 📋 Текущие задачи

### 1. ✅ SwiftPM Issue #9441 — РЕШЕНО (2025-12-24)

**Статус:** ✅ **ПРОТЕСТИРОВАНО И ПОДТВЕРЖДЕНО**

**Фикс:** PR #9493 — фикс deadlock в incremental builds на KVM
**Merged:** https://github.com/swiftlang/swift-package-manager/pull/9493#event-21526083511

**Результаты тестирования:**
- [x] **Мониторить merge** PR #9493 в ветку `main` или `6.3` ✅ MERGED (2025-12-12)
- [x] **Проверить доступность snapshot** ✅ READY (2025-12-15)
- [x] **Протестировать на Linux (UFO Hosting KVM):** ✅ УСПЕШНО (2025-12-24)
  - Установлен snapshot: `swift-DEVELOPMENT-SNAPSHOT-2025-12-19-a`
  - Clean build: ~50s ✅
  - Incremental build #1: 2.96s ✅ (раньше: зависание)
  - Incremental build #2: 3.04s ✅ (раньше: зависание)
  - build-clean.sh workaround больше НЕ нужен ✅
- [x] **Отчёты подготовлены и отправлены:** ✅ DONE (2025-12-24)
  - GitHub Issue #9441 ✅
  - Swift Forums ✅
  - StackOverflow ✅

**Swift на production сервере:**
- Версия: Swift 6.3-dev (swift-DEVELOPMENT-SNAPSHOT-2025-12-19-a)
- Incremental builds работают нормально (~2-3 сек)
- Workaround скрипты удалены

**Ссылки:**
- GitHub Issue: https://github.com/swiftlang/swift-package-manager/issues/9441
- Swift Forums: https://forums.swift.org/t/swiftpm-hangs-at-planning-build-on-every-incremental-build-swift-6-2-linux/83562/7
- StackOverflow: https://stackoverflow.com/questions/79837922/swift-package-manager-hangs-on-incremental-builds-swift-6-2-linux-ubuntu-24-04

---

### 2. BotNotifier v0.5.0 🎯 TDD В ПРОЦЕССЕ

**Статус:** ✅ **Component тесты GREEN** (2025-12-18) → DigestOrchestrator integration следующий шаг

**Scope:**
- BotNotifier — Telegram Bot API интеграция (send-only, plain text)
- Plain text формат (БЕЗ parse_mode)
- Fail-fast если message >4096 chars
- Retry: withRetry + withTimeout (переиспользуем FoundationExtensions)
- HTTP: HTTPClientProtocol + URLSessionHTTPClient + MockHTTPClient

**Документы:**
- ✅ Spike research: `.claude/archived/spike-telegram-bot-api-2025-12-15.md`
- ✅ Architecture Design: `.claude/archived/architecture-v0.5.0-botnotifier-2025-12-16.md`
- ✅ User Story: `Sources/TgClient/TgClient.docc/E2E-Scenarios/BotNotifier.md`

**TDD Progress (Outside-In):**
- ✅ User Story документ (BotNotifier.md)
- ✅ E2E тест (RED) — `Tests/TgClientE2ETests/BotNotifierE2ETests.swift` (disabled, будет реализован позже)
- ✅ Протокол BotNotifierProtocol — `Sources/DigestCore/Notifiers/BotNotifierProtocol.swift`
- ✅ JSONEncoder/Decoder.telegramBot() extension — `Sources/FoundationExtensions/JSONCoding.swift`
- ✅ Unit Tests для extension — `Tests/TgClientUnitTests/FoundationExtensions/JSONCodingTests.swift` (9 тестов, GREEN)
- ✅ Unit Tests для моделей — `Tests/TgClientUnitTests/DigestCore/TelegramBotAPIModelsTests.swift` (12 тестов, GREEN)
- ✅ Models → GREEN:
  - `Sources/DigestCore/Models/TelegramBotAPI/BotAPIError.swift`
  - `Sources/DigestCore/Models/TelegramBotAPI/SendMessageRequest.swift`
  - `Sources/DigestCore/Models/TelegramBotAPI/SendMessageResponse.swift` (+ Message, User, Chat)
- ✅ **Component тесты (9 тестов, GREEN)** — `Tests/TgClientComponentTests/DigestCore/TelegramBotNotifierTests.swift`
  - Happy path: успешная отправка plain text (проверка URL/headers/body)
  - Edge cases: >4096 chars (fail-fast), 4096 chars (граница), 400/401/404 (fail-fast), 429/500 (retry), retry exhausted (3 попытки)
- ✅ **Implementation → GREEN** — `Sources/DigestCore/Notifiers/TelegramBotNotifier.swift`
  - Actor isolation, retry 3x (exponential backoff: 1s, 2s, 4s), timeout 30s
  - Переиспользование: withRetry, HTTPClientProtocol
- ✅ **MockHTTPClient улучшен** — добавлено `sentRequests: [URLRequest]` для проверки URL/body
- ✅ **OpenAISummaryGeneratorTests улучшен** — проверка request (URL + Authorization header)
- [ ] DigestOrchestrator integration — добавить BotNotifier в pipeline
- [ ] E2E manual test с реальным ботом

**Важные решения (2025-12-18):**
- **MockHTTPClient sentRequests:** Выбран паттерн `sentRequests: [URLRequest]` (queue) вместо словаря [Request: Response]
  - **Причина:** Component тесты = 1 endpoint, Queue достаточно для retry сценариев
  - URLRequest НЕ Hashable → сложность без выигрыша
- **Codable оптимизация:** НЕ нужна для MVP (проанализирована [Habr статья](https://habr.com/ru/companies/tbank/articles/977694/))
  - Т-Банк: 200k моделей, 2x speedup → наш проект: ~30 моделей, CLI service
  - Триггер для пересмотра: профилирование покажет >10% CPU на JSON parsing
  - Trade-off: несовместимость с автогенерацией TDLib/Bot API моделей
- **Профилирование и мониторинг:** Добавлена секция в MVP.md "Перед выпуском v1.0 в production"
  - Performance baseline metrics, Prometheus/Grafana, Alerting через Telegram

**Инциденты (записаны в retro-v0.5.0.md):**
- Инцидент #4: User Story создан в DocC комментариях вместо MD файла (исправлено)
- Инцидент #5: JSONEncoder/Decoder extension БЕЗ unit тестов + избыточные тесты для v0.6.0 (исправлено)

**Следующий шаг:**
1. **Code Review** вчерашних и сегодняшних изменений (ОБЯЗАТЕЛЬНО перед продолжением!)
2. DigestOrchestrator integration — добавить BotNotifier в pipeline (fetch → digest → **BotNotifier** → markAsRead)

---

### 3. Настройка Swift субагентов (HYP-001) 🤖 НОВАЯ ЗАДАЧА

**Приоритет:** 🟢 Высокий (новая фича Claude Code)

**Источник:** HYP-001 из Obsidian vault (проверенная гипотеза)

**Цель:** Настроить субагентов для экономии токенов и специализации по задачам

**Релевантность для telegram-client:**
- ✅ Research-First workflow уже используется (WebFetch TDLib docs)
- ✅ Длинные логи сборки (~50 сек) → нужен анализ
- ✅ Swift Concurrency диагностика → специализированный агент

**Задачи:**

1. **Глобальные Swift агенты** (`~/.claude/agents/swift/`):
   - [x] `diagnostics-swift.md` — 5-фазный workflow для поиска багов ✅ СОЗДАНО (2025-01-11)
     - Фаза 1: Статический анализ (Swift Concurrency, SwiftUI, retain cycles)
     - Фаза 2: Build & Test (xcodebuild, swift test)
     - Фаза 3: Runtime анализ (Instruments, debug prints)
     - Фаза 4: Root cause analysis
     - Фаза 5: Fix proposal
   - [ ] `test-swift.md` — XCTest/Swift Testing best practices
   - [ ] `security-ios.md` — OWASP чеклист для iOS

2. **Локальный агент для telegram-client** (`.claude/agents/`):
   - [x] `tdlib-integration.md` — TDLib async/await integration expert ✅ СОЗДАНО (2025-01-11)
     - Research TDLib docs (core.telegram.org)
     - Swift Concurrency patterns для TDLib updates
     - Known issues и workarounds

3. **Документация:**
   - [x] `SUBAGENTS-GUIDE.md` — гайд по использованию субагентов ✅ СОЗДАНО (2025-01-11)
   - [x] `ROLES-SUBAGENTS-ARCHITECTURE.md` — архитектура ролей ↔ субагентов ✅ СОЗДАНО (2025-01-11)

4. **Тестирование:**
   - [ ] Протестировать `diagnostics-swift` на реальной задаче
   - [ ] Протестировать `tdlib-integration` (например, research getChatHistory)
   - [ ] Сравнить с текущим WebFetch подходом

**Структура агента (2-уровневая):**
- **MD файл** — статические правила агента (name, model, execution rules, workflow phases)
- **JSON prompt** — динамическая задача (goal, inputs, constraints, deliverables, done_when)

**Правило явной индикации (КРИТИЧНО!):**

При работе с субагентом **ВСЕГДА** указывать:
```
🤖 СУБАГЕНТ: [name]
🎭 РОЛЬ: [role из ROLES.md или НЕТ]
🧠 МОДЕЛЬ: [sonnet/haiku/opus]
---
```

**Архитектура ролей ↔ субагентов:**
- **Роль** (ROLES.md) = **КАК думать** (образ мышления, чек-листы)
- **Субагент** (.claude/agents/) = **ЧТО делать** (workflow, инструменты)
- **Комбинация:** "swift-diagnostics + Bugfix Specialist" = 5-фазный workflow + баг-фикс мышление

Детали: `.claude/ROLES-SUBAGENTS-ARCHITECTURE.md`

**Ссылки:**
- HYP-001: `~/Library/Mobile Documents/iCloud~md~obsidian/Documents/MyRep/_project-hub/hypotheses/active/HYP-001-subagents-perplexity.md`
- Kotlin reference: https://github.com/AlexGladkov/claude-code-agents
- Архитектура: `.claude/ROLES-SUBAGENTS-ARCHITECTURE.md`

---

### 4. Проверка гипотез ретро v0.5.0 🔍 РЕГУЛЯРНАЯ ЗАДАЧА

**Приоритет:** 🟡 Средний (раз в 1-3 дня)

**Цель:** Отслеживание метрик v0.5.0 для оценки эффективности новых правил

**Инструкция:**
Прочитать `.claude/archived/retro-v0.5.0.md` и выполнить промпт для сбора лога метрик.

**Метрики для отслеживания:**
1. Research-First: 100% External APIs ✅
2. Mock только boundaries: 100% соблюдений ✅
3. TSan: race conditions найдены ДО production ✅
4. Code Review: 100% (когда промпт содержит "Code Review") 🆕
5. User Story + spike research ДО TDD: 100% 🆕
6. Модели через Unit Test ДО Component Test: 100% 🆕
7. Правило 0 применено (наблюдение) 🆕

**Частота:** Раз в 1-3 дня (или перед началом новой задачи)

---

**Ссылки:**
- [MVP.md](MVP.md) — scope и статус MVP
- [BACKLOG.md](BACKLOG.md) — бэклог будущих фич
- [CHANGELOG.md](CHANGELOG.md) — история изменений

---

## 🚀 Промпт для следующей сессии

```
Architecture-First: TelegramBotNotifier для v0.5.0

Роль: Senior Swift Architect

Контекст:
- ✅ Spike research DONE: .claude/archived/spike-telegram-bot-api-2025-12-15.md
- ✅ Live эксперимент выполнен (10 тестов, реальные JSON)
- ✅ Решение: HTTP calls (URLSession) без библиотеки
- ✅ Scope: send-only (sendMessage, БЕЗ getUpdates/команд)
- ✅ 2 инцидента записаны в retro-v0.5.0.md

Следующий шаг: Architecture-First анализ (7 блоков)

1. Прочитать файлы:
   - ROLES.md → Senior Swift Architect (чеклист 7 блоков)
   - .claude/archived/spike-telegram-bot-api-2025-12-15.md
   - Секция "Live Experiment Results" (критичные находки)

2. Architecture-First (7 блоков для TelegramBotNotifier):

   1. Concurrency: Actor? Retry sequential? Thread-safety?
   2. Performance: Rate limits (30 msg/sec). Backpressure нужен?
   3. Memory: 4096 chars limit. Truncate или split?
   4. Failure handling: Retry (429, 5xx). Fail-fast (400, 401). Timeout?
   5. Pipeline: fetch → digest → BotNotifier → markAsRead (sequential)
   6. Observability: Логи (начало, успех, ошибки, retry attempts)
   7. Testing: MockHTTPClient, edge cases (4096 limit, MarkdownV2 escape, retry)

3. Критичные находки из spike (учесть):
   - ⚠️ MarkdownV2 escape ОБЯЗАТЕЛЕН → функция escapeMarkdownV2()
   - ⚠️ Response содержит `entities` поле (НЕ в docs, найдено в live)
   - ✅ 4096 chars = точный лимит (не байты)
   - ✅ Error: {"ok": false, "error_code": 400, "description": "..."}

4. Вопросы для обсуждения:
   - MarkdownV2 escape: где? (SummaryGenerator ИЛИ BotNotifier?)
   - Message >4096: truncate ИЛИ split?
   - HTTPClient: переиспользовать из OpenAISummaryGenerator?

5. Результат:
   - Ответы на 7 блоков (кратко, 2-3 строки)
   - Решения по критичным находкам
   - Готово к TDD → передать Testing Architect

⚠️ НЕ писать код! Только архитектурный анализ.

Давай начнём!
```
