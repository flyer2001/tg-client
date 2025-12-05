# Задачи проекта

> **Последнее обновление:** 2025-12-05 (сессия завершена)
> **Текущая версия:** v0.3.0 (в разработке)

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

## 🚨 ПРИОРИТЕТ #1: Переезд на Swift 6.0 на macOS

**Статус:** Linux ✅ завершён | macOS ⏳ ожидает

**Linux (завершено):**
- ✅ Swift 6.2 → 6.0 downgrade
- ✅ Package.swift: `swift-tools-version: 6.0`
- ✅ Проверено: сборка, тесты, incremental builds работают
- ✅ Отчёт SwiftPM мейнтейнеру: https://github.com/swiftlang/swift-package-manager/issues/9441#issuecomment-3616550867

**macOS (TODO на следующей сессии):**
1. Установить Swift 6.0 toolchain на macOS
2. Проверить сборку и тесты
3. Запустить E2E тест `SummaryGenerationE2ETests` (отложен с Linux)
4. Проверить TSan на macOS (отложен с Linux)

**Причина:** SwiftPM 6.1/6.2 зависает на incremental builds на Linux (регрессия между 6.0↔6.1).

**Детали:** см. `.claude/archived/swiftpm-hang-testing-2025-12-05.md`

---

## 📋 Текущая задача

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

**v0.3.0 — ГОТОВ К РЕЛИЗУ:**
- ✅ DigestOrchestrator Component тесты
- ✅ E2E тест включён и работает
- ⏳ Коммиты + CHANGELOG.md
- ⏳ Git push

**v0.4.0 — Полный pipeline (планирование):**
- MessageSource → DigestOrchestrator интеграция
- BotNotifier реализация (Telegram Bot API)
- StateManager (timestamp JSON)
- E2E тест полного pipeline
- Retry logic (3x exponential backoff)

**Техдолг:**
- Документация: обновить CLAUDE.md (убрать упоминания про обязательность build-clean.sh на Linux, т.к. Swift 6.0 fix)
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
