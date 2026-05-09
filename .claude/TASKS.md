# Задачи проекта

> **Последнее обновление:** 2026-05-09
> **Текущая версия:** v0.3.0 (релиз) + ветка `feature/vk-bot-bridge` (🧪 spike, запушена)
> **На origin/main:** v0.4.0 (mark-as-read) + v0.5.0 in progress (TelegramBotNotifier)

---

## 🧪 SPIKE в feature/vk-bot-bridge (запушен 2026-05-09)

> **Статус:** РАБОТАЕТ как MVP в проде на VPS. Без TDD/тестов. Используется автором лично.
> **Назначение:** research artifact / боевой spike. **Не для merge в main как есть.**
> **Snapshot tag:** `spike/vk-bridge-2026-05-09`
> **Реальная реализация:** будет в отдельной ветке `feature/vk-bridge-tdd` от `origin/main` по полному TDD циклу (см. задачу #4 «Migration RFC v0.6.0» ниже).

### Что добавлено
- **Новый таргет `BotBridge`** (Hummingbird-based HTTP сервер, swift-tools 6.1)
- **VK Callback API webhook** на `https://cashflow-game.ru/vkWebHook` → `127.0.0.1:8082`
- **Service mode**: `tg-client service` — long-running, держит TDLib сессию
- **Команды в VK сообществе:**
  - `/test` — статус
  - `/digest` — меню непрочитанных (каналы / группы / ЛС)
  - `/get N` / `/get all` / `/get channels|groups|dm` — взять чаты из меню
  - `/last N [count]` — последние сообщения чата (включая прочитанные, итеративная подгрузка)
  - `/reply N <текст>` — ответить в чат N от твоего имени
  - `/to <username> <текст>` / `/to_alena <текст>` — отправить любому по @username
  - `/read N` — пометить чат как прочитанный

### Деплой (на текущем сервере)
- systemd: `/etc/systemd/system/tg-client.service`
- env: `/etc/tg-client.env` (mode 600, секреты VK + TDLib)
- nginx: `location /vkWebHook` в `/etc/nginx/sites-enabled/cashflow-game.ru`
- TDLib state: `/opt/tg-client/.tdlib/`
- Бинарь: `/opt/tg-client/tg-client` (release ~36 МБ)

### Технический долг этой ветки

| Проблема | Severity | Решение |
|---|---|---|
| **Нет тестов вообще** | 🔴 высокая | TDD пройти заново для всего BotBridge таргета |
| **TDLib SEGV** (continuation leak) | 🟡 средняя | Уже known issue в CLAUDE.md — лечить через ResponseWaiters |
| **markaread не автоматический** | 🟡 средняя | После `/get N` опционально пометить (флаг? отдельная команда?) |
| **TG entities → VK** игнорируется | 🟢 низкая | Конвертить в unicode bold/italic, ссылки как plain |
| **Медиа без caption** теряются | 🟢 низкая | Добавить маркеры `[🎵]`, `[🖼️]` |
| **CommandProcessor — не actor с протоколом** | 🟢 низкая | Извлечь интерфейс для тестирования |
| **Concurrent guard работает на одном owner** | 🟢 низкая | Нужно ли больше? |

### Решение про merge в main
- (a) **Подержать в feature** — погонять 1-2 недели в реальной нагрузке, потом переписать как продакшн (с тестами)
- (b) **Слить как есть** — рабочее, но нарушает TDD-правила проекта (в CLAUDE.md). Ветка станет "грязной" в истории main.

⚠️ **Решено пока подержать в feature.** Все коммиты атомарные, легко переиспользовать или cherry-pick после ревью.

---

---

## 🔄 НАПОМИНАНИЕ: Проверка ретро (2025-12-11)

**Статус:** ⏳ следующая проверка через 3 дня (2025-12-11)

**Что делать:**
1. Выполнить промпт: [TASKS.md#проверка-гипотез-ретро](#-проверка-гипотез-ретро)
2. Append результат в [RETRO-RESULT.md](archived/RETRO-RESULT.md)
3. Обновить эту дату на +3 дня

**История:**
- ✅ 2025-12-05 - первая проверка выполнена (инцидент: чуть не создали MockSummaryGenerator)
- ⏳ 2025-12-08 - пропущена (релиз), следующая 2025-12-11

---

## 📋 Текущие задачи

### 1. Ретроспектива v0.3.0

**Приоритет:** 🔥 Высокий (выполнить в течение 3 дней после релиза)

**Цель:** Проанализировать процесс разработки v0.3.0, зафиксировать инсайты.

**Шаги:**
1. Прочитать `.claude/retro-v0.3.0-questions.md` (подготовленные вопросы)
2. Заполнить метрики и ответить на вопросы
3. Проверить гипотезы (Research-First, Bugfix процесс, folder фильтрация)
4. Записать результаты в `.claude/archived/retro-v0.3.0-results.md`
5. Обновить RETRO-RESULT.md

---

### 2. Мониторинг SwiftPM Issue #9441

**Статус:** ⏳ Ожидание ответа

**Контекст:**
- GitHub Issue: https://github.com/swiftlang/swift-package-manager/issues/9441
- Swift Forums: https://forums.swift.org/t/83562
- Последний ответ: 2025-12-07 (lldb backtrace отправлен, flock() deadlock)

**Действия:**
- Проверять issue раз в неделю
- Если будет fix → тестировать Swift 6.2.1+ на Linux
- Если закроют без fix → остаёмся на Swift 6.0

---

### 3. Планирование v0.4.0: Отметка о прочтении

**Статус:** ✅ **Зарелизен в origin/main** (см. историю на GitHub).

В этой ветке локально закрыт через TDLib `viewMessages` (использован в `/read N` команде BotBridge spike), но это НЕ та реализация что в main — там полный TDD цикл с E2E.

---

### 4. Migration RFC v0.6.0 (VK Bridge → main по TDD)

**Приоритет:** 🎯 Следующая большая задача

**Контекст:** В origin/main уже появился `BotNotifierProtocol` + `TelegramBotNotifier` (v0.5.0 in progress) с полным набором тестов. Наш VK BotBridge spike нужно мигрировать на этот протокол с TDD, не как параллельный таргет.

**Цель:** Spike `feature/vk-bot-bridge` → production `feature/vk-bridge-tdd` (от `origin/main`).

**Подход:**
- MVP остаётся в `feature/vk-bot-bridge` как research artifact + работающий прод
- Новая ветка `feature/vk-bridge-tdd` от `origin/main`, с outside-in TDD по каждой user story
- Версия v0.6.0 (после v0.5.0 BotNotifier)
- На сервере MVP-binary продолжает крутиться до полной TDD-реализации

**Следующий шаг (отдельная сессия):**
1. Написать `.claude/v0.6.0-vk-bridge-tdd-rfc.md` со структурой:
   - Spike findings (что узнали из MVP в проде)
   - User Stories + Acceptance Criteria (7 stories)
   - Test Matrix (Story → E2E + Component + Unit)
   - Reuse Map (артефакты MVP → copy/inspire/discard)
   - Architecture v2 (`VKBotNotifier: BotNotifierProtocol` + `VKWebhookServer`)
   - TDD Pipeline (outside-in по story)
   - Phasing (3 фазы: infra → notifier+digest → остальные команды)
   - Versioning (v0.6.0 release plan)
   - Acceptance Criteria для merge в main
   - Risks (TDLib SEGV, диск, SwiftPM #9441, миграция systemd)

**После RFC:** Phase 1 — `Hummingbird` infra + config + VKModels + smoke E2E.

---

### 5. Деплой v0.4.0/v0.5.0 на сервер?

**Открытый вопрос:** на сервере крутится spike-binary без mark-as-read из main и без `TelegramBotNotifier`. Нужно ли подтягивать последние main-изменения в production до завершения TDD-миграции?

**Варианты:**
- (a) Не трогать прод до v0.6.0 (минимум хаоса)
- (b) Параллельный деплой main-binary рядом для дайджестов, spike оставить только для VK команд
- (c) Что-то ещё

Решение принять при работе над Migration RFC.

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
- [v0.3.0 Release](https://github.com/flyer2001/tg-client/releases/tag/v0.3.0)
