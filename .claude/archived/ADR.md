# Architecture Decision Records (ADR)

Архив архитектурных решений проекта. Содержит контекст и обоснование ключевых решений.

---

## ADR-001: ChannelMessageSource.fetchUnreadMessages() (2025-11-17)

**Контекст:** Реализация получения непрочитанных сообщений из Telegram каналов.

### Решения:

**1. Производительность:**
- TaskGroup для параллельного getChatHistory() (50 каналов × 1 сек → 3-5 сек)

**2. Память:**
- Пагинация loadChats реализована (цикл до 404)
- getChatHistory limit=100 (ограничение TDLib)
- ~5 MB на 100 каналов × 10 сообщений

**3. Отказоустойчивость:**
- Partial success: если 1 канал упал → логируем, пропускаем, продолжаем

**4. Логирование:**
- Начало/конец операции, ошибки getChatHistory с context

**Статус:** ✅ Реализовано

---

## ADR-002: TDLib Unified Background Loop (2025-11-19)

**Контекст:** Race condition при вызове `td_json_client_receive()` из двух мест (authorization + updates loop).

**Проблема:** Deadlock — authorization loop ждёт state, который получил updates loop.

### Решения:

**1. Производительность:**
- Единый background loop — ТОЛЬКО он вызывает receive()
- NSLock вместо DispatchQueue (~50ns vs ~1μs)
- CheckedContinuation для zero-copy передачи

**2. Память:**
- ResponseWaiters: Dictionary с ~5-10 waiters (<1 KB)

**3. Отказоустойчивость:**
- Error handling через resumeWaiterWithError()
- Cancellation в deinit
- Authorization timeout (300 сек)

### Архитектурная диаграмма:

```
┌─────────────────────────────────────────────┐
│ Background Loop (ЕДИНСТВЕННЫЙ)              │
│  while !Task.isCancelled {                  │
│    guard let obj = receive(timeout: 0.1)    │  ← ТОЛЬКО ЗДЕСЬ receive()
│    switch obj["@type"] {                    │
│      case "error": resumeWaiterWithError()  │
│      case "update*": AsyncStream.yield()    │
│      case "ok", "user", ...: resumeWaiter() │
│    }                                        │
│  }                                          │
└─────────────────────────────────────────────┘
```

**Ключевое решение:** Никто КРОМЕ background loop НЕ вызывает receive() → race condition устранён.

**Статус:** ✅ Реализовано (2025-11-19)

### Известные ограничения (извлечены в ARCHITECTURE.md → Known Limitations):
- Continuation leaked при параллельных запросах одного типа → нужен @extra
- Нет request timeout для getChatHistory/loadChats
