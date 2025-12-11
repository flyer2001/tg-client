# Generate Summary

Генерация краткого саммари для непрочитанных сообщений через OpenAI API.

## User Story

Как пользователь, я хочу получить краткое AI-саммари непрочитанных сообщений из Telegram каналов для быстрого ознакомления с важными темами.

**Ожидаемое поведение:**
- Успешный сценарий: AI-саммари в формате Telegram MarkdownV2 с группировкой по каналам
- Лимит длины: AI получает инструкцию генерировать до 3800 символов (резерв для Telegram лимита 4096)
- Ошибки: Явное сообщение об ошибке для каждого типа (unauthorized, rate limited, network error)

## Официальная документация

- [OpenAI Chat Completions API](https://platform.openai.com/docs/api-reference/chat) — генерация саммари через GPT модели
- [Telegram Bot API: MarkdownV2](https://core.telegram.org/bots/api#markdownv2-style) — формат вывода

## Предусловия

- Получены непрочитанные сообщения через `ChannelMessageSource.fetchUnreadMessages()`
- `.env` файл с `OPENAI_API_KEY` (см. `.env.example`)
- Доступен OpenAI API (не заблокирован, есть квота)

## Шаги

1. **Формирование промпта из непрочитанных сообщений**
   - **Результат:** Промпт с группировкой по каналам (channel title + messages)
   - **Формат:** System message (инструкция) + User message (контент)

2. **Отправка запроса к OpenAI API**
   - **Модель:** `gpt-3.5-turbo`
   - **Параметры:**
     - `max_tokens: 1000` — лимит токенов для ответа
     - System prompt с инструкцией: "Максимальная длина ответа: 3800 символов"
   - **Результат:** AI-саммари в формате Telegram MarkdownV2
   - **Ошибки:**
     - 401 Unauthorized → проверить `OPENAI_API_KEY`
     - 429 Rate Limited → ошибка, прерывание выполнения
     - 500/502/503 Server Error → ошибка, прерывание выполнения
     - Network timeout (60 сек) → ошибка, прерывание выполнения

3. **Возврат саммари**
   - **Результат:** Строка с AI-саммари (ожидается ≤ 3800 символов)

## Как проверить сценарий

**Ручной E2E тест:**

1. Подготовка:
   ```bash
   # Убедитесь что есть непрочитанные сообщения в каналах
   # Проверьте .env файл (OPENAI_API_KEY установлен)
   ```

2. Запуск:
   ```bash
   swift run tg-client
   ```

3. Ожидаемый результат:
   - Логи: "Generating summary for N messages"
   - Логи: "Generated summary: X characters"
   - Без ошибок: "Summary generated successfully"

**Component тесты:**

- <doc:DigestOrchestratorTests> — координация pipeline через SummaryGenerator
- <doc:OpenAISummaryGeneratorTests> — генерация саммари через OpenAI API

**Unit тесты моделей:**

- <doc:OpenAIModelsTests> — проверка Codable для OpenAI Request/Response

## Известные ограничения (v0.3.0)

- ✅ Поддерживается только текст (фото/видео игнорируются)
- ✅ Промпт на русском (для русскоязычных каналов)
- ⚠️ Лимит длины: AI получает инструкцию "до 3800 символов", но гарантии нет
- ⚠️ Нет retry strategy: ошибка API → прерывание выполнения
- ⚠️ Нет разбивки длинных саммари: если AI вернёт > 4096 символов → Telegram отклонит

## Безопасность и конфиденциальность

**Данные отправляемые в OpenAI:**
- Только текст сообщений из Telegram каналов
- **НЕ отправляются:** метаданные пользователя, номер телефона, личные чаты

**OpenAI API:**
- [Data Usage Policy](https://openai.com/policies/api-data-usage-policies) — OpenAI **не использует** данные из API для обучения моделей (с 1 марта 2023)
- Данные хранятся 30 дней для мониторинга abuse, затем удаляются

**Рекомендации:**
- Используйте отдельный OpenAI API key только для этого приложения
- Регулярно проверяйте usage через [OpenAI Dashboard](https://platform.openai.com/usage)
- Установите usage limits для защиты от неожиданных расходов
