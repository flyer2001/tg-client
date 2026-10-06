# Spike: VK Bots Long Poll (2026-10-06)

Throwaway-код Research-First перед TDD `VKLongPollClient` (v0.5.0). Сообщество — TG Bridge (club242065128).
Запуск на ubuntu-home: `swift run spike`, `./live.sh` (читают `../../.env`).

## Что узнали (реальное поведение, Linux, Swift 6.4)

| Вопрос | Ответ |
|---|---|
| `groups.getLongPollServer` | `{"response":{"key":"<JWT-подобная строка>","server":"https://lp.vk.com/whp/<group_id>","ts":"1"}}` — **ts строкой** |
| пустой `a_check` | `{"ts":"1","updates":[]}` |
| `wait=25` | ответ через **~21.9 c** (не 25) → таймаут запроса ставить заметно больше `wait` |
| битый `key` | `{"failed":2}` — без `ts` |
| `failed:1` / `failed:3` | не воспроизведены, берём из документации (`failed:1` приходит с новым `ts`) |
| **отмена `URLSession.data(from:)` на Linux** | **работает**: `Task.cancel()` → через 2.00 c `URLError -999 cancelled`. Graceful shutdown = отмена Task |
| `message_new` | `fixtures/message_new.json` — живое событие: `updates[].object.message.{from_id, peer_id, text, attachments, date, id}`, `event_id`, `v` |
| события до первого слушателя | «привет», отправленный до первого `a_check`, в очередь не попал: `ts` стал `"2"` только на следующем сообщении |
| задержка доставки | сообщение → событие: секунды |

## Решения для реализации

- `ts` моделируем `String`, `failed` — `Int?`; ответ декодируем в один тип с опциональными `updates`/`failed`/`ts`.
- Таймаут HTTP-запроса = `wait + 10 c`.
- Остановка: отмена `Task` цикла, отдельный флаг не нужен.
- Повтор при сетевой ошибке — с растущей задержкой (ось «время» HYP-057: инъекция `Clock`).
