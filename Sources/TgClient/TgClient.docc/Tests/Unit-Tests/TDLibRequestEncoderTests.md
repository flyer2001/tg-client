# Кодирование TDLib запросов

## Описание

Unit-тесты для TDLibRequestEncoder.

Проверяют корректность сериализации запросов в JSON формат TDLib:
- Наличие поля `@type`
- Правильный snake_case маппинг (camelCase → snake_case)
- Корректные типы данных

**Тип теста:** Юнит

**Исходный код:** [`Tests/TgClientUnitTests/TDLibAdapter/TDLibRequestEncoderTests.swift`](https://github.com/flyer2001/tg-client/blob/main/Tests/TgClientUnitTests/TDLibAdapter/TDLibRequestEncoderTests.swift)

## Тестовые сценарии

### Encode GetMeRequest - простой запрос без параметров



Given

When

Then

---

### Encode SetTdlibParametersRequest - сложный запрос с snake_case маппингом



Given

When

Then

Проверка @type

Проверка snake_case маппинга

Проверка отсутствия camelCase ключей

---

### Encode SetAuthenticationPhoneNumberRequest



Given

When

Then

Проверка отсутствия camelCase

---

### Encode CheckAuthenticationCodeRequest



Given

When

Then

---

### Encode CheckAuthenticationPasswordRequest



Given

When

Then

---

### Encoded JSON is valid format



Given

When

Then - должно быть валидным JSON

---

### Encoded data is not empty



Given

When

Then

---


## Topics

### Связанная документация

- <doc:TgClient>
