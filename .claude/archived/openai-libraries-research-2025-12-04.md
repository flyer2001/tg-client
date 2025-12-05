# OpenAI Swift Libraries - Research

> **Дата:** 2025-12-04
> **Цель:** Изучение best practices для HTTP client, error handling, retry logic, streaming

Исследование для реализации SummaryGenerator (v0.3.0). Использовать как reference для будущих улучшений.

---

## 📚 Изученные библиотеки

### 1. ChatGPTSwift (⭐ Best practices)
**Repo:** https://github.com/alfianlosari/ChatGPTSwift

**HTTP клиент:**
- **Абстракция Transport:** OpenAPI Runtime с platform-specific реализациями
  ```swift
  #if os(Linux)
      clientTransport = AsyncHTTPClientTransport()
  #else
      clientTransport = URLSessionTransport()
  #endif
  ```

**Error handling:**
- Explicit status code mapping:
  ```swift
  switch response {
  case .ok(let body): // 200
  case .undocumented(let statusCode, let payload):
      throw getError(statusCode: statusCode, payload: payload)
  }
  ```
- **Human-readable errors** для каждого статуса:
  - **401**: "Invalid Authentication. Check your OpenAI API Key..."
  - **403**: "Country, region, or territory not supported..."
  - **429**: "Rate limit reached for requests..."

**Streaming:** `AsyncThrowingStream` для потоковой передачи

**✅ Применимо:** explicit errors, Data не опциональная

---

### 2. OpenAISwift
**Repo:** https://github.com/adamrushy/OpenAISwift

**HTTP клиент:**
- Простой wrapper над `URLSession.dataTask`
- ❌ **НЕ валидирует HTTP status code!**
- Ошибки обнаруживаются только при декодировании JSON

**❌ Не рекомендуется:** отсутствие валидации status code

---

### 3. FuturraGroup/OpenAI (OpenAIKit)
**Repo:** https://github.com/FuturraGroup/OpenAI

**Security:**
- SSL certificate pinning для защиты API ключей
- Custom timeout intervals

**✅ Применимо:** SSL pinning для production

---

### 4. SwiftGPT
**Repo:** https://github.com/DobbyWanKenoby/SwiftGPT

**Архитектура:**
- Full Swift Concurrency integration
- Протокол `APIKeyProvider` для гибкого управления ключами

**✅ Применимо:** async throws (уже используем)

---

## 🎯 Финальный дизайн HTTPClientProtocol

```swift
public enum HTTPError: Error {
    case clientError(statusCode: Int, data: Data)  // 4xx
    case serverError(statusCode: Int, data: Data)  // 5xx
    case invalidResponse
}

public protocol HTTPClientProtocol: Sendable {
    func send(request: URLRequest) async throws -> Data
}
```

**Обоснование:**
1. **Data не опциональная** (как в ChatGPTSwift) - может быть пустая
2. **Explicit validation HTTP status** (в отличие от OpenAISwift)
3. **Error содержит statusCode + data** для логирования

---

## 📋 Для будущих версий

- **Retry logic:** exponential backoff для 429/5xx
- **Streaming:** `AsyncThrowingStream` для real-time генерации
- **SSL Pinning:** для production
- **APIKeyProvider:** ротация ключей

---

## 🔗 Ссылки

- OpenAI Error Codes: https://platform.openai.com/docs/guides/error-codes
- Rate Limits: https://platform.openai.com/docs/guides/rate-limits
