# Стратегия тестирования

> 📋 **Обновлено:** 2025-10-28

## ⚠️ Неснимаемое правило

**Все тесты пишутся ТОЛЬКО на Swift Testing фреймворке (НЕ XCTest).**

**Документация:** https://developer.apple.com/documentation/testing

---

## Уровни тестирования

### Unit-тесты
- Изолированное тестирование функций/классов
- Моки для всех зависимостей
- Быстрые, детерминированные
- Примеры: TDLibRequestEncoder, TDLibUpdate, модели

### Component-тесты
- Тестирование модулей с реальными зависимостями
- Без внешней сети
- Моки только для C API и сетевых вызовов
- Примеры: TDLibClient (с мок TDLib), авторизация

### E2E-тесты
- Интеграционные тесты с реальным TDLib
- Требуют credentials
- Медленные, опционально в CI
- Примеры: полный цикл авторизации

## TDD Workflow

RED → GREEN → REFACTOR

### Документация через тесты

**Принцип:** Тесты — источник правды о том, как работают внешние API.

#### Где документировать что

**✅ В тестах:**
- Ссылки на документацию внешних API (TDLib, OpenAI, Telegram Bot API)
- Примеры реальных JSON ответов
- Описание поведения внешних систем
- Edge cases внешних API

**✅ В коде:**
- Документация внутренних абстракций (протоколы, интерфейсы)
- Контракты наших модулей (что принимает, что возвращает)
- Бизнес-логика (почему принято такое решение)

#### Пример

```swift
// Tests/TDLibAdapterTests/TDLibCodableModels/Responses/ChatTests.swift

/// Тесты для модели Chat
///
/// **TDLib API:** https://core.telegram.org/tdlib/docs/classtd_1_1td__api_1_1chat.html
///
/// TDLib отслеживает прочитанность на стороне сервера:
/// - `unread_count` обновляется автоматически при новых сообщениях
/// - `last_read_inbox_message_id` обновляется при вызове viewMessages
/// - Возвращает JSON в snake_case формате
@Suite("Chat model decoding")
struct ChatTests {
    @Test("Decode channel with unread messages")
    func decodeChannelWithUnread() throws {
        // Пример реального ответа TDLib
        let json = """
        {
            "id": 123456789,
            "type": { "@type": "chatTypeChannel" },
            "title": "Tech News",
            "unread_count": 5,
            "last_read_inbox_message_id": 100
        }
        """

        let chat = try JSONDecoder().decode(Chat.self, from: json)

        #expect(chat.unreadCount == 5)  // snake_case → camelCase
        #expect(chat.lastReadInboxMessageId == 100)
    }
}

// Sources/TDLibAdapter/TDLibCodableModels/Responses/Chat.swift

/// Модель чата для внутреннего использования
///
/// Используется в `ChannelMessageSource` для получения списка каналов
/// и отслеживания непрочитанных сообщений.
struct Chat: Codable, Sendable, Equatable {
    let id: Int64
    let unreadCount: Int
    let lastReadInboxMessageId: Int64

    enum CodingKeys: String, CodingKey {
        case id
        case unreadCount = "unread_count"
        case lastReadInboxMessageId = "last_read_inbox_message_id"
    }
}
```

#### Почему это важно

1. **Тесты читаются чаще** — когда разбираешься как работает внешний API
2. **Тесты = executable documentation** — примеры реальных JSON с проверкой
3. **Код остаётся чистым** — фокус на внутренней логике
4. **Легче менять реализацию** — документация в тестах, код можно переписать

#### Применение в проекте

| Модуль | Внешний API | Документация в тестах | Документация в коде |
|--------|-------------|----------------------|---------------------|
| TDLibAdapter | TDLib C API | Примеры JSON ответов | `TDLibClientProtocol` |
| OpenAISummaryGenerator | OpenAI API | HTTP responses | `SummaryGeneratorProtocol` |
| TelegramBotNotifier | Telegram Bot API | API examples | `BotNotifierProtocol` |

## Coverage Requirements

Минимальный coverage для PR: **TODO**

## Инфраструктура

- Swift Testing framework (Swift 6)
- CI интеграция
- Coverage отчёты

---

**См. также:**
- [TASKS.md](TASKS.md) - задача 5.1
- [CONTRIBUTING.md](CONTRIBUTING.md) - правила разработки
