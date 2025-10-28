# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

---

**🚀 НАЧАЛО НОВОЙ СЕССИИ:**
Прочитай [TASKS.md](docs/TASKS.md) и предложи продолжить работу над задачами.

**⚠️ ФОКУС НА MVP:**
Все новые задачи направлены на достижение MVP. Детали scope — по требованию в [MVP.md](docs/MVP.md).

---

## Цель проекта

CLI-клиент Telegram: логин → чтение непрочитанных → саммари через внешний AI → отправка результата через бота

## Неснимаемые правила

- **Пишем код по TDD** (детали в [TESTING.md](docs/TESTING.md)). Сборка на Linux обязательна.
- Swift 6; зависимости ≤ 6 мес.; минимум внешних библиотек.
- Логи на каждом внешнем вызове (Telegram, AI, Bot). Секреты только из env.
- Изменения > 2 файлов или смена архитектуры — сначала план/RFC.

## Правила для ассистента

- Нужны деплой/SSH/env? Иди в документы ниже. Секреты в код не добавлять.
- Публичные контракты не менять без тестов. Если правок много — сначала план.
- По умолчанию отвечай кратко (6–10 строк); разворачивай детали только по запросу.
- **Git коммиты**: строго следуй [CONTRIBUTING.md](docs/CONTRIBUTING.md) (на русском, БЕЗ "Co-Authored-By: Claude").
- **Перед коммитом**: актуализируй TASKS.md и предложи добавить запись в CHANGELOG.md (prepend через bash). Если критичный контекст — обнови DEPLOY/SETUP/ARCHITECTURE/TROUBLESHOOTING.
- **Использование токенов**: отслеживай token usage в system warnings и предупреждай пользователя при достижении 90% (180k из 200k токенов), чтобы успеть завершить работу.

## Архитектура MVP

5 core модулей: MessageSource, SummaryGenerator, BotNotifier, StateManager, DigestOrchestrator.

Детали: [MVP.md](docs/MVP.md), [ARCHITECTURE.md](docs/ARCHITECTURE.md)

## Быстрые команды (для активной разработки)

```bash
swift build          # Сборка проекта
swift test           # Запуск всех тестов
swift run tg-client  # Запуск приложения
```

Подробнее см. [SETUP.md](docs/SETUP.md)

## Документация

Вся документация находится в папке `docs/` (читать только по требованию):

- **[TASKS.md](docs/TASKS.md)** - текущие задачи (читать в начале сессии)
- **[MVP.md](docs/MVP.md)** - цели и scope MVP
- **[IDEAS.md](docs/IDEAS.md)** - бэклог для версий после MVP
- **[CHANGELOG.md](docs/CHANGELOG.md)** - история сессий (⚠️ только prepend через bash)
- **[CONTRIBUTING.md](docs/CONTRIBUTING.md)** - правила разработки (git коммиты, TDD, стиль кода)
- **[TESTING.md](docs/TESTING.md)** - стратегия тестирования, TDD workflow
- **[ARCHITECTURE.md](docs/ARCHITECTURE.md)** - архитектура, модули, паттерны
- **[SETUP.md](docs/SETUP.md)** / **[CREDENTIALS.md](docs/CREDENTIALS.md)** / **[DEPLOY.md](docs/DEPLOY.md)** - инфраструктура
- **[TROUBLESHOOTING.md](docs/TROUBLESHOOTING.md)** - частые проблемы
