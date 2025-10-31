# ``TgClient``

CLI-клиент Telegram для получения саммари непрочитанных сообщений через AI.

## Обзор

TgClient — это Swift-приложение, которое:
- Авторизуется в Telegram через TDLib
- Получает список непрочитанных сообщений из каналов
- Генерирует краткое саммари через внешний AI (OpenAI/Claude)
- Отправляет результат через Telegram Bot

**Цель:** Автоматизация просмотра большого количества каналов без необходимости читать всё вручную.

## Технологический стек

- **Swift 6** - язык программирования (async/await, Sendable, strict concurrency)
- **TDLib** - официальная библиотека Telegram для работы с API
- **Swift-Log** - структурированное логирование
- **Swift Testing** - современный фреймворк тестирования (не XCTest)

## Статус реализации

### ✅ Реализовано (MVP-1)

- **Авторизация в Telegram** - полный цикл через TDLib
  - Phone + код подтверждения
  - Двухфакторная аутентификация (2FA)
  - Обработка ошибок (неверный номер/код/пароль)
  - См. <doc:Authentication>

### 🚧 В разработке

- **Получение непрочитанных сообщений** - работа с каналами через TDLib
- **Интеграция с AI** - генерация саммари через OpenAI API
- **Отправка через бота** - публикация результата в Telegram

### 📋 Запланировано

- Периодический digest (по расписанию)
- Поддержка групп и личных сообщений
- Whitelist/Blacklist чатов
- Персонализация (tone, length, language)

## E2E Сценарии

Полные пользовательские сценарии с навигацией по компонентам:

- <doc:Authentication> - авторизация пользователя в Telegram

## Архитектура

### Core модули (MVP)

- **MessageSource** - получение сообщений из Telegram
- **SummaryGenerator** - генерация саммари через AI
- **BotNotifier** - отправка результатов через бота
- **StateManager** - управление состоянием приложения
- **DigestOrchestrator** - оркестрация всего процесса

### Адаптеры

- **TDLibAdapter** - низкоуровневая работа с TDLib C API
  - Авторизация
  - Получение чатов и сообщений
  - Отметка прочитанным

## Тестирование

Проект следует TDD (Test-Driven Development):
- **Unit тесты** - изолированное тестирование функций/классов
- **Component тесты** - интеграционное тестирование модулей
- **E2E тесты** - полный цикл с реальным TDLib (опционально)

**Принцип:** Тесты = источник правды о поведении системы и внешних API.

## Разработка

### Требования

- macOS 14+ или Linux (Ubuntu 24.04+)
- Swift 6.0+
- TDLib 1.8.6+

### Быстрый старт

```bash
# Сборка проекта
swift build

# Запуск тестов
swift test

# Запуск приложения
swift run tg-client
```

### Просмотр документации

```bash
# Локальный preview (macOS)
./scripts/preview-docs.sh

# Откроется в браузере:
# http://localhost:8000/documentation/tgclient
```

## Ссылки

- [GitHub репозиторий](https://github.com/flyer2001/tg-client)
- [TDLib API Documentation](https://core.telegram.org/tdlib/docs/)
- [Swift Testing Documentation](https://developer.apple.com/documentation/testing)

## Topics

### E2E Scenarios

- <doc:Authentication>

### Component Documentation

- Coming soon: TDLibAdapter, SummaryGenerator, BotNotifier
