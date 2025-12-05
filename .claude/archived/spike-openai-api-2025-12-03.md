# OpenAI API Spike - Результаты

> **Дата:** 2025-12-03
> **Статус:** ✅ Завершён
> **Цель:** Проверить реальное поведение OpenAI Chat API для SummaryGenerator

---

## ✅ Проверка подключения

### Тестовый запрос

```bash
curl -s https://api.openai.com/v1/chat/completions \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $OPENAI_API_KEY" \
  -d '{
    "model": "gpt-3.5-turbo",
    "messages": [
      {"role": "system", "content": "You are a helpful assistant that summarizes messages."},
      {"role": "user", "content": "Summarize this: Hello world"}
    ],
    "max_tokens": 100
  }'
```

### Реальный ответ

```json
{
  "id": "chatcmpl-CizWdyiMQHVXSLOmgJ9OOBTS8FZvi",
  "object": "chat.completion",
  "created": 1764838971,
  "model": "gpt-3.5-turbo-0125",
  "choices": [
    {
      "index": 0,
      "message": {
        "role": "assistant",
        "content": "The message says \"Hello world\".",
        "refusal": null
      },
      "finish_reason": "stop"
    }
  ],
  "usage": {
    "prompt_tokens": 27,
    "completion_tokens": 7,
    "total_tokens": 34
  }
}
```

---

## 🔍 Ключевые находки

### 1. Структура ответа (подтверждена)

**Извлечение результата:**
```swift
let summary = response.choices[0].message.content
```

**finish_reason:**
- `"stop"` - нормальное завершение
- `"length"` - достигнут лимит max_tokens
- `"content_filter"` - контент отфильтрован

### 2. Модель

**Реальная версия:** `gpt-3.5-turbo-0125` (OpenAI обновляет автоматически)

**Для запроса указываем:** `"gpt-3.5-turbo"` (алиас на последнюю версию)

### 3. Token usage

**Наш тест:**
- Prompt: 27 токенов (system + user messages)
- Completion: 7 токенов (ответ)
- **Total: 34 токена**

**Стоимость gpt-3.5-turbo:**
- Input: $0.0005 / 1K tokens
- Output: $0.0015 / 1K tokens

**Примерный расчёт для нашего кейса:**
- 100 сообщений × 200 символов = 20K символов ≈ 10K tokens (input)
- Саммари: ~500 tokens (output)
- **Стоимость за 1 дайджест: ~$0.006** (0.6 цента)

### 4. Промпт на русском работает ✅

**Проверено!** Результат отличный.

**Тестовый запрос:**
```bash
curl -s https://api.openai.com/v1/chat/completions \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $OPENAI_API_KEY" \
  -d '{
    "model": "gpt-3.5-turbo",
    "messages": [
      {
        "role": "system",
        "content": "Ты — ассистент для создания дайджестов сообщений из Telegram-каналов. Пиши кратко и по делу."
      },
      {
        "role": "user",
        "content": "Создай дайджест этих сообщений:\n\nКанал: TechNews\n- [https://t.me/tech/1] Вышла новая версия GPT-5\n- [https://t.me/tech/2] Обнаружена уязвимость в OpenSSL\n\nКанал: DevOps\n- Релиз Kubernetes 1.30"
      }
    ],
    "max_tokens": 300
  }'
```

**Реальный ответ:**
```
📰 **TechNews:**
1. [Вышла новая версия GPT-5](https://t.me/tech/1)
2. [Обнаружена уязвимость в OpenSSL](https://t.me/tech/2)

🔧 **DevOps:**
- Релиз Kubernetes 1.30
```

**Token usage:**
- Prompt: 132 токена
- Completion: 75 токенов
- **Total: 207 токенов**

**Выводы:**
- ✅ OpenAI отлично понимает русский язык
- ✅ Автоматически добавляет эмодзи (📰, 🔧)
- ✅ Сохраняет ссылки в правильном формате
- ✅ Группирует по каналам
- ✅ Markdown форматирование корректное

**Тестовый скрипт:** `.claude/archived/openai-russian-prompt-test.sh`

---

## 🎯 Решения для реализации

### Модели данных

```swift
// Request
struct ChatCompletionRequest: Encodable {
    let model: String                  // "gpt-3.5-turbo"
    let messages: [ChatMessage]
    let maxTokens: Int?                // max_tokens (опционально)
    let temperature: Double?           // 0.0-2.0 (опционально)

    enum CodingKeys: String, CodingKey {
        case model
        case messages
        case maxTokens = "max_tokens"
        case temperature
    }
}

struct ChatMessage: Encodable {
    let role: String                   // "system", "user", "assistant"
    let content: String
}

// Response
struct ChatCompletionResponse: Decodable {
    let id: String
    let choices: [Choice]
    let usage: Usage

    struct Choice: Decodable {
        let message: Message
        let finishReason: String       // "stop", "length", "content_filter"

        struct Message: Decodable {
            let content: String
        }

        enum CodingKeys: String, CodingKey {
            case message
            case finishReason = "finish_reason"
        }
    }

    struct Usage: Decodable {
        let promptTokens: Int
        let completionTokens: Int
        let totalTokens: Int

        enum CodingKeys: String, CodingKey {
            case promptTokens = "prompt_tokens"
            case completionTokens = "completion_tokens"
            case totalTokens = "total_tokens"
        }
    }
}
```

### HTTP клиент

```swift
func sendRequest(messages: [ChatMessage]) async throws -> String {
    let request = ChatCompletionRequest(
        model: "gpt-3.5-turbo",
        messages: messages,
        maxTokens: 1000,
        temperature: 0.7
    )

    var urlRequest = URLRequest(url: URL(string: "https://api.openai.com/v1/chat/completions")!)
    urlRequest.httpMethod = "POST"
    urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
    urlRequest.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
    urlRequest.httpBody = try JSONEncoder().encode(request)
    urlRequest.timeoutInterval = 60

    let (data, response) = try await URLSession.shared.data(for: urlRequest)

    guard let httpResponse = response as? HTTPURLResponse else {
        throw OpenAIError.invalidResponse
    }

    guard (200...299).contains(httpResponse.statusCode) else {
        throw OpenAIError.httpError(httpResponse.statusCode)
    }

    let chatResponse = try JSONDecoder().decode(ChatCompletionResponse.self, from: data)
    return chatResponse.choices[0].message.content
}
```

### System message (русский)

```swift
let systemMessage = ChatMessage(
    role: "system",
    content: """
    Ты — ассистент для создания дайджестов сообщений из Telegram-каналов.

    Правила:
    1. Группируй сообщения по каналам
    2. Для каждого канала: краткий обзор (1-2 предложения) + ключевые темы
    3. Добавляй ссылки на сообщения: [тема](t.me/c/...)
    4. Максимальная длина: 3800 символов
    5. Используй Telegram Markdown: *жирный*, _курсив_, `код`
    6. Пиши кратко и по делу, без воды

    Если контента слишком много, раздели на логические блоки по 3800 символов, разделяя "---NEXT---"
    """
)
```

---

## ⚠️ Edge cases (для тестов)

### 1. Ошибки HTTP

| Код | Причина | Обработка |
|-----|---------|-----------|
| 401 | Invalid API key | Fatal error, не ретраим |
| 429 | Rate limit | Retry с exponential backoff |
| 500-503 | Server error | Retry (max 3 попытки) |
| 504 | Timeout | Retry |

**JSON ошибки:**
```json
{
  "error": {
    "message": "Rate limit exceeded",
    "type": "rate_limit_error",
    "code": "rate_limit_exceeded"
  }
}
```

### 2. finish_reason = "length"

**Проблема:** ответ обрезан из-за max_tokens.

**Решение:**
- Увеличить max_tokens (1000 → 1500)
- Или добавить "... (продолжение обрезано)" к саммари

### 3. Пустой ответ

**Может быть:** `choices[0].message.content == ""`

**Обработка:** throw OpenAIError.emptyResponse

---

## ✅ Checklist готовности к реализации

- [x] API ключ работает
- [x] Структура request/response понятна
- [x] Модели данных спроектированы
- [x] System message на русском готов
- [x] Edge cases определены
- [ ] Тест с русским промптом (следующий шаг)
- [ ] Retry logic с backoff
- [ ] Structured logging

---

## 🎬 Следующие шаги

1. ✅ **Spike завершён** - переходим к реализации
2. **1.2. DocC документация** - описать User Story
3. **1.3. E2E тест (RED)** - сценарий с реальным API
4. **1.4. Протокол** - SummaryGeneratorProtocol
5. **1.5. Component тест (RED)** - реальный HTTP запрос
6. **1.6. Unit тесты** - форматирование промпта
7. **1.7. Implementation** → GREEN

**⚠️ Важно:** перед тестами убедиться что `OPENAI_API_KEY` загружен!
