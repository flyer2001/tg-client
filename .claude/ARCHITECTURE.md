# Архитектура проекта

## Целевая архитектура

```
┌─────────────────────────────────────────────────┐
│              CLI App (main.swift)               │
│         Точка входа, env, консольные промпты    │
└─────────────────────┬───────────────────────────┘
                      │
┌─────────────────────▼───────────────────────────┐
│            DigestOrchestrator                   │
│      Координирует весь pipeline дайджеста       │
└─────────────────────┬───────────────────────────┘
                      │
    ┌─────────┬───────┼───────┬─────────┐
    ▼         ▼       ▼       ▼         ▼
┌───────┐ ┌───────┐ ┌─────┐ ┌───────┐ ┌───────┐
│Message│ │Summary│ │ Bot │ │ State │ │TDLib  │
│Source │ │Gener. │ │Notif│ │Manager│ │Client │
└───┬───┘ └───┬───┘ └──┬──┘ └───┬───┘ └───┬───┘
    │         │        │       │         │
    ▼         ▼        ▼       ▼         ▼
┌───────┐ ┌───────┐ ┌─────┐ ┌───────┐ ┌───────┐
│TDLib  │ │AI API │ │Bot  │ │File   │ │TDLib  │
│(чаты) │ │OpenAI │ │API  │ │System │ │C API  │
└───────┘ └───────┘ └─────┘ └───────┘ └───────┘
```

### Слои

| Слой | Назначение | Примеры |
|------|------------|---------|
| **App** | Точка входа, CLI, env | main.swift |
| **Orchestration** | Координация pipeline | DigestOrchestrator |
| **Domain** | Бизнес-логика | MessageSource, SummaryGenerator, BotNotifier, StateManager |
| **Infrastructure** | Внешние сервисы | TDLibClient, AI API, Bot API, FileSystem |

> **Примечание:** Слои — логическая абстракция для понимания зависимостей. Физически код в одном таргете, без отдельных папок/модулей.

---

## Pipeline Flow & Error Handling

### Sequential Pipeline (v0.4.0 → v0.5.0)

```
main.swift:
  1. TDLib auth ────────────────► fail-fast ✗
  2. getMe() ───────────────────► fail-fast ✗
  3. fetchUnreadMessages() ─────► partial success ⚠ (внутри)
                                  fail-fast ✗ (если 0 сообщений)
  4. generateDigest() ──────────► retry 3x ↻ (1s, 2s, 4s)
                                  fail-fast ✗ (после retry)
  5. [v0.5.0] BotNotifier.send()► fail-fast ✗
  6. markAsRead() ──────────────► partial success ⚠
                                  graceful degradation
```

**Легенда:**
- ✗ Fail-fast (ошибка → exit(1), НЕ помечаем прочитанным)
- ⚠ Partial success (продолжаем при частичных ошибках)
- ↻ Retry (exponential backoff)

### Error Handling Strategies

| Этап | Стратегия | Обоснование |
|------|-----------|-------------|
| **Auth/getMe** | Fail-fast | Критично для всего pipeline |
| **fetchUnreadMessages** | Partial success (внутри)<br>Fail-fast (наружу) | Один канал упал → продолжаем с остальными<br>0 сообщений → нет смысла продолжать |
| **generateDigest** | Retry 3x → Fail-fast | AI может временно упасть (rate limit, 5xx)<br>Retry увеличивает reliability |
| **BotNotifier.send** | Fail-fast (v0.5.0) | Пользователь должен получить digest |
| **markAsRead** | Partial success | Digest уже отправлен → не критично<br>Упавшие чаты логируем |

### Ключевые решения

**Retry для AI, но НЕ для TDLib:**
- OpenAI: временные ошибки (429 rate limit, 5xx) → retry помогает
- TDLib: partial success достаточен (упавший чат → попадёт в следующий запуск)

**markAsRead ПОСЛЕ BotNotifier:**
- v0.4.0 временно: после generateDigest (BotNotifier ещё не реализован)
- v0.5.0 цель: fetch → digest → **send** → markAsRead

**Детали реализации:** См. `.claude/TASKS.md` § Pipeline Architecture v0.4.0

---

## Модули MVP

| Модуль | Ответственность |
|--------|-----------------|
| **MessageSource** | Получение непрочитанных сообщений из Telegram |
| **SummaryGenerator** | Формирование саммари через AI API |
| **BotNotifier** | Отправка результата через Telegram Bot |
| **StateManager** | Хранение прогресса (last processed chat) |
| **DigestOrchestrator** | Координация всего pipeline |

Вспомогательные: **TDLibClient** (адаптер к TDLib), **Logger** (swift-log)

---

## Принципы проектирования

### Обязательные

- **SOLID** — Single Responsibility, Open/Closed, Liskov, Interface Segregation, Dependency Inversion
- **Dependency Injection** — зависимости через `init`, не создаём внутри
- **Protocol-Oriented** — протоколы для тестируемости (моки)
- **Swift Structured Concurrency** — async/await, actors для thread-safe state. Исключения: стык с C-библиотеками (TDLib) может требовать другие подходы

### Кроссплатформенность

- **#if os()** — избегать. Если неизбежно → тестировать оба варианта (macOS + Linux)
- **Linux сборка обязательна** перед мержем

### JSON Encoding (TDLib)

- Использовать `.tdlib()` factory — НЕ создавать `JSONEncoder()`/`JSONDecoder()` напрямую
- Реализация: `Sources/Shared/JSONCoding.swift`

### Подход к паттернам

Используем best practices, применимые к проекту:
- Исследовать паттерны из опыта высоконагруженных приложений
- Применять GoF (Gang of Four) где уместно
- Изучать решения из open-source проектов схожей архитектуры
- **Не ограничиваем себя** — если паттерн решает проблему, применяем

---

## Критическая оценка решений

При проектировании компонента **обязательно** проверяй:

| Аспект | Вопросы | Пример проблемы |
|--------|---------|-----------------|
| **Память** | Сколько объектов в памяти? Нужна пагинация? | 1000 чатов × 100 сообщений = 100MB |
| **Производительность** | Последовательно или параллельно? Latency? | 50 запросов × 1 сек = 50 сек |
| **Отказоустойчивость** | Что если один запрос упал? Partial success? | getChatHistory упал → пропустить канал |
| **Масштабирование** | Что при 10× нагрузке? Rate limits? | API throttling, memory pressure |

### Чеклист перед реализацией

- [ ] Оценил memory footprint (сколько данных держим)
- [ ] Выбрал стратегию (sequential vs parallel)
- [ ] Определил поведение при ошибках (fail fast vs partial success)
- [ ] Продумал логирование критичных точек

---

## Обязательное логирование

Логируй в этих местах:

| Место | Что логировать | Уровень |
|-------|----------------|---------|
| **External API calls** | request/response/error (TDLib, AI, Bot) | info/error |
| **catch блоки** | все ошибки с context (chatId, operation) | error |
| **guard let / if let с else** | unexpected nil с context | warning/error |
| **Начало/конец операций** | для трейсинга и измерения duration | info |
| **Retry attempts** | номер попытки, причина retry | warning |

---

## Политика зависимостей

### Принципы

- **Минимум внешних библиотек** — только необходимое
- **Валидация перед добавлением** — см. чеклист ниже
- **Приоритет stdlib** — если можно решить средствами Swift, не тянем библиотеку

### Чеклист валидации новой зависимости

- [ ] **Сборка**: инкрементальная < 30 сек на macOS
- [ ] **Платформы**: macOS + Linux
- [ ] **Swift 6**: полная совместимость
- [ ] **Structured Concurrency**: async/await, actors
- [ ] **Поддержка**: commits за последние 6 месяцев
- [ ] **Лицензия**: совместима с проектом

### Пример проблемы

`swift-docc-plugin` добавил +60 сек к каждой сборке → вынесен в отдельный workflow CI.

---

## Known Limitations

Извлечено из опыта разработки (см. [archived/ADR.md](archived/ADR.md)):

| Ограничение | Контекст | Workaround |
|-------------|----------|------------|
| **Continuation leaked** | Параллельные TDLib запросы одного типа | Использовать `@extra` для request_id |
| **Нет request timeout** | getChatHistory/loadChats могут зависнуть | TODO: добавить timeout |
| **SwiftPM на Linux зависает** | Инкрементальная сборка | Использовать `./scripts/build-clean.sh` |
| **swift test + pipe = SIGPIPE** | `swift test \| head` убивает процесс | Не использовать pipe с swift test |

---

## Категории ошибок

| Категория | Описание | Действие |
|-----------|----------|----------|
| **Recoverable** | Временные (network timeout, rate limit 429) | Retry с exponential backoff |
| **Unrecoverable** | Критичные (SESSION_REVOKED, USER_DEACTIVATED) | Graceful shutdown, уведомить |
| **Partial failure** | Один из N запросов упал | Логировать, продолжить с остальными |

---

## Паттерны устойчивости (для обдумывания)

При реализации DigestOrchestrator, StateManager и long-running режима — оценить необходимость:

### Circuit Breaker

**Когда понадобится:** Retry логика + внешние сервисы (TDLib, OpenAI, Bot API).

**Проблема:** Unrecoverable ошибка → retry → опять ошибка → бесконечный loop.

**Решение:** После N ошибок подряд → "открыть circuit", остановиться, уведомить.

**Вопросы при проектировании:**
- Сколько ошибок подряд допустимо? (3? 5?)
- Раздельные счётчики для TDLib/OpenAI/Bot?
- Как уведомлять? (лог, telegram alert, exit code)

### Graceful Shutdown

**Когда понадобится:** StateManager + обработка большого числа чатов.

**Проблема:** Падение на 50 чате из 100 → прогресс потерян → при рестарте дубли.

**Решение:** Checkpoint (last processed chat_id) + resume при рестарте.

**Вопросы при проектировании:**
- Формат checkpoint? (JSON с version, timestamp)
- Атомарность записи? (write to temp + rename)
- Валидация при загрузке? (не старше N часов?)
- Graceful cleanup? (закрыть TDLib, flush логи)

