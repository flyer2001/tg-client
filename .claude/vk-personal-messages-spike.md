# Spike: личные сообщения VK (2026-10-05)

> **Статус:** ✅ spike рабочий (чтение / markAsRead / send). Риск заморозки — не измерен (нужно наблюдение несколько дней).
> **Код:** `spikes/vk-web/spike.mjs` (Node + Playwright). Запуск — на ubuntu-home, НЕ на VDS.
> **Цель продукта:** ассистент читает личку TG / VK / Mattermost, делает сводку, по просьбе отправляет от имени владельца.

---

## Почему не официальный API (ресерч 2026-10-05)

| Путь | Итог |
|---|---|
| Свой Standalone app + `scope=messages` | Право `messages` новым приложениям не выдаётся (ограничение с 2019) |
| VK ID scopes | Только `vkid.personal_info`, `email`, `phone` — `messages` нет |
| Верификация / оплата (правила с 2026-09-07) | Даёт только лимит вызовов (10k/мес без верификации, 100M с ней), не права |
| Токены чужих клиентов (Kate Mobile, VK Admin, Маруся) | Заморозки аккаунтов 1–4 дня (июль 2026); 2026-09-08 Kate Mobile отрезан («flood control») |
| Mini Apps `VKWebAppGetAuthToken` | `messages` не поддерживается; `GetCommunityToken` — только токен сообщества |
| Бот сообщества (наш spike `BotBridge`) | Видит только сообщения сообществу — канал «владелец ↔ ассистент», не личка |
| Заявка на индивидуальное право | **Отказ 2026-10-06** (devsupport@corp.vk.com): «Использовать messages с личного профиля не получится… методы этой секции доступны только с ключом доступа сообщества». Заявлялось app `Personal Inbox Assistant` (VK ID, Web, id 54806805) |
| Email-уведомления VK | **Не годится** (проверено Sergey 2026-10-07): текст в письмах обрезан, это просто уведомления. Читаем через Playwright-скрипты |

## Как работает spike

Headless Chromium с persistent-профилем открывает `vk.com/im` и вызывает **внутренний API самого веб-клиента**
`window.vkApi.api(method, params)` — отдельный токен не нужен, методы те же, что в публичном API (`messages.*`).
Фолбэк в коде (перехват `access_token` из запросов к api.vk.com) не понадобился.

```bash
# ubuntu-home, ~/vk-web-spike (Node в ~/opt/node/bin)
node spike.mjs login                 # QR + код подтверждения нового устройства (см. ниже)
node spike.mjs probe                 # непрочитанные + 3 последних сообщения
node spike.mjs send <peer_id> <text> # peer_id = свой id → «Избранное»
node spike.mjs api <method> '<json>' # любой метод: getConversations / getHistory / markAsRead
```

Проверено 2026-10-05: `getConversations(filter=unread)`, `getHistory` (+ `reply_message` для контекста),
`markAsRead(peer_id, mark_conversation_as_read=1)`, `send` в «Избранное». Каждый вызов < 1 c.
`getHistory` НЕ помечает прочитанным — отметка только явным `markAsRead`.

**Логин (одноразово):** скрипт скриншотит экран входа каждые 5 c (на VDS зеркалим в `/srv/screenshots/<sid>/`),
владелец сканирует QR в приложении VK, VK показывает на телефоне код → кладём в `<VK_SHOTS_DIR>/code.txt`,
скрипт печатает его в поле. Скриншот QR удаляется после входа (QR = ключ входа).
Сессия живёт в `~/.local/share/vk-web-spike/profile` на ubuntu-home — это по сути пароль, из машины не выносить.

## Риски / открытые вопросы

- **Заморозка аккаунта** — главный неизвестный. Наблюдать: раз в день `probe`, смотреть жива ли сессия и нет ли предупреждений.
- ubuntu-home = dual-boot с Windows: пока загружена Windows, VK-канал недоступен.
- Хрупкость: `window.vkApi` — внутренний объект веб-клиента, VK может переименовать/убрать.
- Не делать частый polling: веб-клиент живого человека не дёргает API каждую минуту.

## Автоматизация без агента (идея, не реализовано)

Цель — агент не тратит контекст на «понять что происходит», работа детерминированная:

1. **Сбор** (cron, скрипт): `getConversations(unread)` + `getHistory` по каждому → нормализованный JSON
   (`{source:"vk", chat, sender, date, text, reply_to}`), тот же формат что из TG (`SourceMessage`).
2. **Саммари**: один LLM-вызов на весь JSON (уже есть `OpenAISummaryGenerator`) — без агентного цикла.
3. **Доставка**: дайджест через бота (TG `TelegramBotNotifier` / VK сообщество).
4. **markAsRead** — только после успешной доставки (тот же порядок, что целевой в TG: fetch → digest → send → markAsRead).
5. **Отправка от имени** — единственное место, где нужен агент/человек: по явной команде, с подтверждением текста.

Email-уведомления обрезаны (2026-10-07) — шаг 1 только через браузер. Цель: скрипты с JSON-выходом, агент проверяет лишь узловые точки.

---

Связанное: [TASKS.md](TASKS.md) · [vk-bot-bridge-rfc.md](vk-bot-bridge-rfc.md) (бот сообщества) ·
[v0.6.0-vk-bridge-tdd-rfc.md](v0.6.0-vk-bridge-tdd-rfc.md) · [ARCHITECTURE.md](ARCHITECTURE.md)
