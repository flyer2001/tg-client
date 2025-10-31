# tg-client

CLI-клиент Telegram для получения саммари непрочитанных сообщений через AI.

## 🎯 Описание

TgClient автоматизирует просмотр большого количества Telegram каналов:
- Авторизуется в Telegram через TDLib
- Получает список непрочитанных сообщений
- Генерирует краткое саммари через AI (OpenAI/Claude)
- Отправляет результат через Telegram Bot

## 🚀 Быстрый старт

```bash
# Клонировать репозиторий
git clone https://github.com/flyer2001/tg-client.git
cd tg-client

# Собрать проект
swift build

# Запустить тесты
swift test

# Запустить приложение
swift run tg-client
```

## 📋 Требования

- Swift 6.0+
- TDLib 1.8.6+
- macOS 14+ или Linux (Ubuntu 24.04+)

## 📖 Документация

**Полная документация доступна онлайн:**
👉 [https://flyer2001.github.io/tg-client/documentation/tgclient](https://flyer2001.github.io/tg-client/documentation/tgclient)

**Локальный preview (только macOS):**
```bash
./scripts/preview-docs.sh
```

Документация включает:
- E2E сценарии (авторизация, получение сообщений, etc.)
- Компонентную документацию (TDLibAdapter, SummaryGenerator, etc.)
- Unit-тесты с примерами JSON и ссылками на внешние API

## 🛠️ Разработка

- [SETUP.md](docs/SETUP.md) - Настройка окружения
- [CONTRIBUTING.md](docs/CONTRIBUTING.md) - Правила разработки
- [TESTING.md](docs/TESTING.md) - Стратегия тестирования
- [ARCHITECTURE.md](docs/ARCHITECTURE.md) - Архитектура проекта
- [TASKS.md](docs/TASKS.md) - Текущие задачи

## 📝 Статус проекта

**✅ Реализовано:**
- Авторизация в Telegram (phone + code + 2FA)
- Типизация TDLib API (requests/responses)
- Unit-тесты для базовых компонентов

**🚧 В разработке (MVP-1):**
- Получение непрочитанных сообщений из каналов
- Интеграция с AI для генерации саммари
- Отправка результата через Telegram Bot

## 📄 Лицензия

MIT
