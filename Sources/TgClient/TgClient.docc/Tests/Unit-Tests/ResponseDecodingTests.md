# Декодирование Response моделей

## Описание

Unit-тесты для декодирования Response моделей TDLib.

Проверяют корректность декодирования JSON ответов от TDLib:
- Правильный snake_case маппинг (snake_case → camelCase)
- Корректная обработка вложенных структур
- Обработка ошибок

**Тип теста:** Юнит

**Исходный код:** [`Tests/TgClientUnitTests/TDLibAdapter/ResponseDecodingTests.swift`](https://github.com/flyer2001/tg-client/blob/main/Tests/TgClientUnitTests/TDLibAdapter/ResponseDecodingTests.swift)

## Тестовые сценарии

### Декодирование AuthorizationStateUpdate - waitTdlibParameters



Given

When

Then

---

### Декодирование AuthorizationStateUpdate - waitPhoneNumber



Given

When

Then

---

### Декодирование AuthorizationStateUpdate - waitCode



Given

When

Then

---

### Декодирование AuthorizationStateUpdate - waitPassword



Given

When

Then

---

### Декодирование AuthorizationStateUpdate - ready



Given

When

Then

---

### Декодирование TDLibError



Given

When

Then

---

### Декодирование TDLibError - network timeout



Given

When

Then

---

### Декодирование TDLibError - auth failed



Given

When

Then

---

### Декодирование падает на невалидном JSON



Given

Then

---

### Декодирование падает на отсутствующем обязательном поле



Given - missing authorization_state

Then

---


## Topics

### Связанная документация

- <doc:TgClient>
