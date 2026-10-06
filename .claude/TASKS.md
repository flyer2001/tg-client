# Задачи проекта

> **Последнее обновление:** 2026-10-06
> **Текущая версия:** v0.5.0 (тег запушен 2026-10-06), сервис — systemd `tg-client` на ubuntu-home (TDLib через tinyproxy VDS:8388)
> **На origin/main:** v0.4.0 + TelegramBotNotifier (заготовка, не подключена — уходит в v0.6.0)
> **Разработка:** сборка/тесты на ubuntu-home (Swift 6.4, TDLib 1.8.67), git — на VDS

Только открытые задачи. Сделанное — [CHANGELOG.md](CHANGELOG.md).

---

## 📋 Текущие задачи

### 1. Релиз v0.5.0

- [ ] GitHub Release для тега `v0.5.0` (тег и main запушены 2026-10-06): текст — `scratchpad`/CHANGELOG; Sergey создаёт в UI или авторизовать `gh` на VDS
- [ ] **CI Documentation упал** на шаге «Generate Documentation» (Swift 6.4, run 37520397268); Linux Build and Test — ✅. Логи без авторизации не достать → воспроизвести `swift package generate-documentation` на ubuntu-home (подозрение: старый swift-docc-plugin 1.4.3 / битые `<doc:>` ссылки), починить, проверить страницу VKBridge на GitHub Pages
- [ ] Анонс в TG-канал (@aidigestcreator): текст и промпт картинки готовы в сессии 2026-10-06

### 2. Хвосты после сессии 2026-08-19 (dump/send)

- [ ] Актуализировать DEPLOY.md: прод-сервера 45.8.145.191 не существует, машина = supervisor-VDS 194.59.245.243; нет `/root/tg-client`, `/opt/tg-client`, `tg-client.service`; TDLib на VDS — 1.8.66 (`/usr/local`), на ubuntu-home — 1.8.67 (master `42e6a5259`); где жить сервису VK Bridge

### 3. Личные сообщения VK (spike 2026-10-05) — [vk-personal-messages-spike.md](vk-personal-messages-spike.md)

- [ ] Наблюдать заморозку аккаунта: `probe` раз в день на ubuntu-home ~неделю (до ~2026-10-12)
- [ ] Проверить email-уведомления VK: полный ли текст, беседы, приходят ли когда онлайн → решить, читать ли из почты

### 4. v0.6.0 — сводка агенту / в бота (следующая фича)

- [ ] Груминг: CLI-команды для агента (`unread --json`, `history`, `read`, `send`) vs доставка в TG-бота (новый бот после компрометации `@private_digest_summary_bot`); порядок fetch → digest → send → markAsRead

### 5. TDLib

- [ ] **Баг (найден 2026-10-06):** `updateAuthorizationState`, пришедший до регистрации ожидающего в `ResponseWaiters`, теряется → цикл авторизации может зависнуть (в тестах воспроизводится; в проде пока спасает медленный TDLib). Тест-первым: буферизовать последнее состояние авторизации

- [ ] Политика обновления: коммит сборки — в DEPLOY.md; перед деплоем на VDS собрать тот же коммит (сейчас 1.8.66 vs 1.8.67); обновлять раз в квартал или по ошибке версии

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
