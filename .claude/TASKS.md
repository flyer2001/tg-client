# Задачи проекта

> **Последнее обновление:** 2026-10-15 (проект переехал в `/root/projects/comms/tg-client`, зонтик `comms`)
> **Текущая версия:** v0.5.0 (тег запушен 2026-10-06), сервис — systemd `tg-client` на ubuntu-home (TDLib через tinyproxy VDS:8388)
> **На origin/main:** v0.4.0 + TelegramBotNotifier (заготовка, не подключена — уходит в v0.6.0)
> **Разработка:** сборка/тесты на ubuntu-home (Swift 6.4, TDLib 1.8.67), git — на VDS

Только открытые задачи. Сделанное — [CHANGELOG.md](CHANGELOG.md).

---

## 📋 Текущие задачи

### 1. CLI-обвязка → финальный шаг к v1.0.0 (СЛЕДУЮЩЕЕ)

`get-summary`/`read` работают через сокет службы (вариант (b)), контракт Factor 4 есть — см. docc GetSummary.

- [ ] **Тестовая архитектура к v1** — итерации И0–И7 по [testing-v1-plan.md](testing-v1-plan.md) (И0 спайки сделаны; дальше И1 документы → И2 → И3 DSL → форумы → И4 H-PF → И5 время → И6 запись/воспроизведение → И7 E2E)
- [ ] **Форумы (чаты с темами)** — `read` не помечает темы, `get-summary` теряет форум после частичной пометки (E2E 2026-10-15, Podlodka AI Crew). Спайк 2026-10-16 (`scripts/spikes/forum_spike.py <chat_id> [--mark <topic>|auto]`, при остановленной службе): `viewMessages(last_message темы, source=messageSourceForumTopicHistory, force_read)` → `unread` темы 0, остальные не тронуты; чатовый `unread_count` = сумма тем, обновляется с задержкой. **До TDD — дочитать доку:** `core.telegram.org/api/forum`, `message.topic_id`, поведение `getChatHistory` в форуме, семантика чатового `unread_count`/`last_read` у форума. Дальше TDD: сбор по темам (`getForumTopics`/`getForumTopicHistory`), курсор `{chat_id, forum_topic_id, up_to_message_id}`, `read` по темам
- [ ] Лимит 100 сообщений в сводке: `read` метит весь чат (граница прочитанного), включая не попавшее в сводку (Podlodka iOS Crew: 846 непрочитанных, в сводке 100). Решить: не метить неполные чаты или поднять лимит
- [ ] Проверить одновременный `get-summary` через сокет и команду бота VK: оба ходят в один `ChannelMessageSource`, сериализация есть только внутри сокета
- [ ] Через неделю (≈2026-10-22) убрать `read --cursor` (оставить `--input-json` и файл по умолчанию)
- [ ] После обвязки: актуализировать README под «руки агенту», **выпустить v1.0.0**, один анонс (мост VK + руки агенту + прокси). MVP-критерии — .claude/MVP.md

### 2. Релиз v0.5.0 (хвост, за Sergey)

- [ ] GitHub Release для тега v0.5.0 (текст: .claude/release-v0.5.0-notes.md) + анонс в @aidigestcreator (текст и промпт картинки — CHANGELOG 2026-10-06)

### 3. После v1.0.0

- [ ] Обогащение get-summary для дневника: `from_name`/`date`/медиа/`reply_to` (см. BACKLOG)
- [ ] Отправка от агента — НЕ в tg-client: отдельный проект send-gate (подтверждение с телефона, whitelist). Решить судьбу `runSend` в CLI (убрать или увести под send-gate)
- [ ] Агент-обвязка в assistant: сводка из Telegram → потом Mattermost

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
