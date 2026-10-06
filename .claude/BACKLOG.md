# Бэклог

> **Последнее обновление:** 2025-12-02

## 📑 Навигация

- [Кандидаты для следующей версии](#-кандидаты-для-следующей-версии)
- [Продуктовые идеи](#-продуктовые-идеи) — фичи для пользователя
- [Технические улучшения](#-технические-улучшения)
  - [Developer Experience](#developer-experience) — удобство разработки
  - [Инфраструктура](#инфраструктура) — деплой и мониторинг
- [Исследования](#-исследования) — эксперименты и оптимизации

---

## 🗂 Отложенное из TASKS (ревизия 2026-10-06)

- **Ретроспектива v0.3.0** (с декабря 2025): вопросы в `.claude/retro-v0.3.0-questions.md`, результат — `.claude/archived/retro-v0.3.0-results.md` + RETRO-RESULT.md. Перенесено: без done-signal'а и без срока, v0.4/v0.5 уже прошли.

## 🎯 Кандидаты для следующей версии

_Выбрать 1-2 задачи для груминга. Процесс: [TASKS.md](TASKS.md) → "Груминг следующей фичи"_

| Задача | Тип | Ценность |
|--------|-----|----------|
| Realtime мониторинг | Product | Реакция на события без cron |
| Группы и чаты | Product | Больше источников контента |
| Управление через бота | Product | Удобство настройки |

---

## 🎨 Продуктовые идеи

### Realtime мониторинг (альтернатива cron)

**Проблема:** MVP работает по расписанию, нет realtime реакции.

**Решение:** Long-running процесс с UpdatesHandler.

**Use cases:**
- Работать постоянно, не по крону
- Реагировать на важные события (VIP, ключевые слова)
- Дайджесты по триггерам (> 50 непрочитанных)
- Бот команда `/unread now`

**Компоненты (в git истории):** `ChannelCache` actor — коммит `00c9f3f`

---

### Группы и чаты

**Проблема:** MVP — только каналы.

**Решения:**
- `GroupChatMessageSource` — с поддержкой threading
- `PrivateChatMessageSource` — с whitelist контактов

---

### Управление через бота

- `/channels list|enable|disable` — whitelist/blacklist
- `/schedule show|set` — настройка расписания

---

### Обработка медиа

- Фото: captions + OCR
- Голосовые: транскрипция (Whisper API)
- Ссылки: Open Graph превью

**Информирование о пропущенных сообщениях:**
- Если среди непрочитанных есть неподдерживаемые типы (фото/видео/стикеры) → добавить в дайджест информацию
- Формат: "⚠️ Пропущено 3 сообщения (2 фото, 1 видео)"
- Мотивация: пользователь должен знать что часть контента не попала в саммари

---

### Персонализация

- Тон саммари (formal/casual/technical)
- Длина (brief/medium/detailed)
- Теги и категории каналов

---

### Улучшение генерации ссылок на сообщения

**Проблема:** OpenAI не всегда включает ссылки на сообщения в дайджест (зависит от промпта/модели).

**Возможные решения:**
1. **Улучшить промпт:** добавить explicit инструкции про ссылки в системный промпт
2. **Саммари per chat:** генерировать отдельный саммари для каждого чата, самим добавлять ссылки
3. **Post-processing:** парсить дайджест и добавлять ссылки через regex/markdown манипуляции

**Контекст:** v0.3.0 E2E тест показал нестабильное поведение — иногда ссылки есть, иногда нет.

**Рекомендация:** начать с варианта 2 (саммари per chat) — проще контролировать формат.

---

### Интеграции (далёкое будущее)

- Email, RSS, Notion, Obsidian, Slack/Discord
- Multi-user поддержка

---

## 🔧 Технические улучшения

> **Паттерны устойчивости** (Circuit Breaker, Graceful Shutdown) — см. [ARCHITECTURE.md](ARCHITECTURE.md#паттерны-устойчивости-для-обдумывания)

### Developer Experience

#### SwiftLint через pre-commit
Build Plugin закомментирован (тормозит сборку). Нужен `.git/hooks/pre-commit`.

#### Кодогенерация из TL схемы
Ручная типизация TDLib API не масштабируется. Генератор из `td_api.tl`.

#### Thread Sanitizer (TSan) учения + Swift 6.2 concurrency флаги

**Проблема:** TSan по умолчанию выключен, нет практического опыта отладки concurrency ошибок.

**Цель:** Получить доверие к TSan как инструменту обнаружения race conditions.

**План учений:**
1. Сознательно написать плохой код с известными проблемами:
   - Race condition (одновременная запись в shared state)
   - Deadlock (взаимная блокировка двух actors)
   - Livelock (бесконечное переключение состояний)
2. Запустить `swift test --sanitize=thread`
3. Проверить что TSan ловит **все** проблемы
4. Зафиксировать примеры в документации

**Дополнительно: Swift 6.2 concurrency флаги** (источник: [massicotte.org/what-settings](https://www.massicotte.org/blog/what-settings/))
- [ ] Проверить `NonisolatedNonsendingByDefault` — меняет дефолт для nonisolated методов
- [ ] Проверить `InferIsolatedConformances` — автовывод изоляции для conformances
- [ ] Оценить влияние на наш код с actors (TDLibClient, DigestOrchestrator)

**Когда:** v0.4.0 (перед реализацией mark-as-read с параллелизмом)

**Метрика успеха:** 3/3 намеренных ошибок обнаружены TSan

**Связь с ретро:** Гипотеза 1.4 из retro-2024-11-analysis.md переходит в "Проверена"

#### Retry Strategy (Best Practice)

**Проблема:** TDLib/network вызовы могут временно падать (timeout, rate limit, transient errors). Сейчас fail-fast → снижает надёжность.

**Цель:** Централизованная retry логика с best practices.

**Research вопросы:**
1. **Какие ошибки retry?**
   - ✅ Timeout, network errors, rate limits (429)
   - ❌ Authentication errors, invalid parameters (400)
2. **Exponential backoff:**
   - Стандартная схема: 1s, 2s, 4s (max 3 attempts)
   - Jitter: добавить случайность (±20%) → избежать thundering herd
3. **Idempotency:**
   - Проверить что TDLib методы идемпотентны (viewMessages, getChatHistory)
4. **Влияние на pipeline:**
   - Retry внутри TaskGroup → не блокирует другие tasks
   - Timeout per attempt (не total timeout)
5. **Testing:**
   - Mock transient errors → проверить retry
   - TSan: нет data races в retry логике
6. **Observability:**
   - Логировать каждую попытку (attempt 1/3)

**Архитектура (варианты):**

a) **Централизованный (в TDLibClient.sendAndWait)**
```swift
extension TDLibClient {
    func sendAndWait<T>(..., retryPolicy: RetryPolicy = .noRetry) async throws -> T
}
```
**Плюсы:** Переиспользование
**Минусы:** Не все методы нужно retry

b) **Локальный (в каждом сервисе)**
```swift
func markAsRead(...) async throws {
    try await retry(maxAttempts: 3) {
        try await client.sendAndWait(...)
    }
}
```
**Плюсы:** Контроль где применяется
**Минусы:** Дублирование

c) **Hybrid:** `RetryPolicy` protocol + extension
```swift
protocol RetryPolicy {
    func shouldRetry(error: Error, attempt: Int) -> Bool
    func delay(for attempt: Int) -> Duration
}

extension TDLibClient {
    func sendAndWaitWithRetry<T>(..., policy: RetryPolicy) async throws -> T
}
```

**Когда:** После v0.4.0 MVP (не блокирует mark-as-read).

**Estimate:** ~1-2 дня (research + design + implementation + testing).

**Метрика успеха:**
- 3+ TDLib методов покрыты retry
- TSan: 0 data races
- Component тесты: transient error → успех после retry
- **Edge case тесты для timeout/cancellation:**
  - `MarkAsReadService`: timeout для viewMessages, Task.cancel в середине TaskGroup
  - `ChannelMessageSource`: timeout для getChatHistory параллельных запросов

**Риски:**
- Deadlock если retry блокирует actor re-entrancy
- Бесконечные зависания если timeout некорректен
- Thundering herd без jitter

**Prerequisite для edge case тестов:**
- Требуется механизм мокирования timeout/delay в MockTDLibFFI
- Без этого edge case тесты будут слишком медленными или ненадёжными

#### CI/CD
- GitHub Actions: автоматические релизы
- Semantic versioning + auto CHANGELOG
- Dependabot

---

### Инфраструктура

- **Docker образ** — проще деплой
- **Prometheus/Grafana** — метрики и дашборды

---

## 🧪 Исследования

- AI провайдеры: Claude API, локальные модели
- Параллельная обработка каналов
- Batch запросы к OpenAI
- Адаптивная pagination для loadChats

#### Swift Server Meetup #7 - видео анализ

**Задача:** Просмотреть видео "What's New in Swift Server" (декабрь 2024) для актуальных best practices.

**Контекст:**
- Транскрипция скачана: `/tmp/swift-server-full.txt`
- Основные темы: AWS Lambda deployment, Swift 6.0.2, performance, packaging

**Релевантность:** Средняя (больше про serverless, меньше про CLI/daemon)

**Когда:** После MVP (низкий приоритет)

#### swift-configuration 1.0

**Задача:** Оценить применимость swift-configuration для multi-platform CLI приложения.

**Контекст:**
- Сейчас: EnvFileLoader (простые .env файлы)
- swift-configuration: typed configs, validation, multi-environment support

**Вопрос:** Нужна ли миграция для CLI с простыми env vars?

**Когда:** Пересмотреть после MVP (если появятся сложные конфигурации)

**Ссылка:** https://www.swift.org/blog/swift-configuration-1.0-released/

#### Cupertino MCP Server

**Задача:** Установить Cupertino MCP сервер для offline доступа к Swift документации.

**Описание:**
- 302k+ страниц документации (Swift.org, Apple Developer, Swift Evolution)
- SQLite база, offline доступ
- Полезен для всех Swift проектов (не только UI)

**Когда:** После MVP

**Ссылка:** https://apptractor.ru/info/github/cupertino.html

#### Валидация и документация TDLIB_DATABASE_ENCRYPTION_KEY

**Проблема:** Некорректный encryption key (не кратный 16 байтам для AES) вызывает "Wrong padding length" ошибку. Требование не документировано.

**Инцидент:** 2025-12-11 — E2E spike тест зависал на авторизации из-за ключа длиной 23 байта.

**Задачи:**
1. **Документация:**
   - [ ] `.env.example` — добавить пример валидного ключа (hex 32 bytes)
   - [ ] Комментарий: "Must be 16, 32, 48, or 64 hex characters (AES)"
   - [ ] `DEPLOY.md` — секция про encryption key требования
   - [ ] `README.md` — упомянуть в quick start

2. **Валидация:**
   - [ ] `TDConfig.forTesting()` — проверить длину ключа при старте
   - [ ] Выбросить понятную ошибку: "Invalid encryption key length: X (expected 16/32/48/64 hex chars)"
   - [ ] Unit тест для валидации

3. **Генерация ключа:**
   - [ ] Добавить команду в README: `openssl rand -hex 32`

4. **Troubleshooting (вместо функционала):**
   - [ ] `TROUBLESHOOTING.md` — секция "Wrong database encryption key"
   - [ ] Объяснить: ключ изменён после создания базы → база нечитаема
   - [ ] Решение: удалить `~/.tdlib/` и заново авторизоваться
   - [ ] Команда: `rm -rf ~/.tdlib && swift run tg-client`
   - [ ] **РЕШЕНИЕ:** Документация вместо кода (сценарий редкий, автоматика не нужна)

**Приоритет:** 🟡 Средний (блокирует E2E тесты для новых разработчиков, но TROUBLESHOOTING можно добавить быстро)

**Когда:** После v0.4.0 (не критично для MVP)

**Связь:** retro-v0.4.0-questions.md — инцидент 2025-12-11


---

### Skip Previously Sent Chats (State Management)

**Проблема:** Если `markAsRead()` частично упал (N чатов failed), при следующем запуске:
- Digest включает эти чаты снова (они остались unread в TDLib)
- Пользователь получит дубль summary для этих чатов

**Решение (v0.6.0+):**
- StateManager хранит список chatIds уже отправленных digest
- `fetchUnreadMessages()` фильтрует эти чаты (skip)
- TTL: 24 часа (после этого чат снова включается в digest)

**Компоненты:**
```swift
actor StateManager {
    func markAsSent(chatId: Int64) async
    func wasSentRecently(chatId: Int64) async -> Bool
    func cleanupOldEntries() async  // TTL cleanup
}
```

**Формат хранения:**
- JSON файл: `{"version": 1, "sentChats": [{"chatId": 123, "timestamp": "2025-12-12T10:00:00Z"}]}`
- Атомарная запись: write to temp + rename
- Валидация при загрузке: не старше 24 часов

**Trade-offs:**
- ✅ Нет дублей digest при partial failure
- ⚠️ Усложняет: нужен StateManager + TTL cleanup
- ⚠️ Риск: StateManager может потерять данные (file corruption)

**Альтернативы:**
- Option A: Не делать ничего (простое решение, дубли редки)
- Option B: Retry для markAsRead (не решает проблему полностью)
- Option C: StateManager (рекомендовано для production)

**Приоритет:** 🟡 Средний (проблема редкая, но раздражающая)

**Связано с:**
- v0.4.0: MarkAsReadService (partial failure handling)
- v0.5.0: BotNotifier integration

