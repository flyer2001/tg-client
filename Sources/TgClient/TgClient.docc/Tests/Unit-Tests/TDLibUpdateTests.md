# Парсинг TDLib обновлений

## Описание

Unit-тесты для TDLibUpdate (обёртка для парсинга ответов TDLib).

Проверяют:
- Корректное определение типа по полю @type
- Декодирование в соответствующий case
- Обработку unknown типов
- Error handling (missing @type, invalid JSON)

**Тип теста:** Юнит

**Исходный код:** [`Tests/TgClientUnitTests/TDLibAdapter/TDLibUpdateTests.swift`](https://github.com/flyer2001/tg-client/blob/main/Tests/TgClientUnitTests/TDLibAdapter/TDLibUpdateTests.swift)

## Тестовые сценарии

### Parse updateAuthorizationState



Given

When

Then

---

### Parse updateAuthorizationState - waitPhoneNumber



Given

When

Then

---

### Parse error response



Given

When

Then

---

### Parse error response - auth failed



Given

When

Then

---

### Parse unknown type - fallback to .unknown



Given

When

Then

---

### Parse ok response



Given

When

Then

---

### Parse fails on missing @type field



Given

Then

---

### Parse fails on invalid structure



Given - @type есть, но структура не соответствует error

Then

---

### Parse fails on empty JSON



Given

Then

---


## Topics

### Связанная документация

- <doc:TgClient>
