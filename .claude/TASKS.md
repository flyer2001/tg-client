# Задачи проекта

> **Текущая версия:** v0.4.0 ✅
> **В разработке:** TBD (см. задачи ниже)

---

## 📋 Текущие задачи

### 1. Мониторинг SwiftPM Issue #9441 🎯 КРИТИЧНО

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

### 2. BotNotifier v0.5.0 🎯 TDD READY

**Статус:** ✅ Architecture Design DONE (2025-12-16) → готово к TDD

**Scope:**
- BotNotifier — Telegram Bot API интеграция (send-only, plain text)
- Plain text формат (БЕЗ parse_mode)
- Fail-fast если message >4096 chars
- Retry: withRetry + withTimeout (переиспользуем FoundationExtensions)
- HTTP: HTTPClientProtocol + URLSessionHTTPClient + MockHTTPClient

**Документы для TDD:**
- ✅ Spike research: `.claude/archived/spike-telegram-bot-api-2025-12-15.md`
- ✅ **Architecture Design: `.claude/archived/architecture-v0.5.0-botnotifier-2025-12-16.md`**

**Следующий шаг:** Outside-In TDD следуя Architecture Design документу

---

### 3. Проверка гипотез ретро v0.5.0 🔍 РЕГУЛЯРНАЯ ЗАДАЧА

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
