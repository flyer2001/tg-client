# TDLibAdapter: Процесс авторизации (High-Level API)

## Описание

Component-тесты для авторизации через TDLib с использованием high-level API.

Эти тесты проверяют полный flow авторизации с типобезопасным API,
используя MockTDLibClient для изоляции от реального TDLib.

**Scope:**
- Авторизация по номеру телефона + код
- Авторизация с 2FA (пароль)
- Обработка ошибок (неверный код, неверный пароль)

**Related:**
- Unit-тесты моделей: `ResponseDecodingTests` (декодирование AuthorizationStateUpdateResponse)
- E2E тест: `scripts/manual_e2e_auth.sh` (реальный TDLib)
- TDLib docs: https://core.telegram.org/tdlib/.claude/classtd_1_1td__api_1_1set_authentication_phone_number.html

**Тип теста:** Компонентный

**Исходный код:** [`Tests/TgClientComponentTests/TDLibAdapter/AuthenticationFlowTests.swift`](https://github.com/flyer2001/tg-client/blob/main/Tests/TgClientComponentTests/TDLibAdapter/AuthenticationFlowTests.swift)

## Тестовые сценарии

### Успешная авторизация: телефон + код

Тест успешной авторизации: phone → code → ready.

**TDLib flow:**
1. `setAuthenticationPhoneNumber("+1234567890")` → `authorizationStateWaitCode`
2. `checkAuthenticationCode("12345")` → `authorizationStateReady`

**Docs:** https://core.telegram.org/tdlib/.claude/classtd_1_1td__api_1_1authorization_state.html

Given: Mock client который эмулирует успешную авторизацию

Настраиваем mock ответы для каждого шага авторизации

Шаг 1: <doc:SetAuthenticationPhoneNumberRequestTests> → <doc:AuthorizationStateUpdateResponseTests> (waitCode)

Шаг 2: <doc:CheckAuthenticationCodeRequestTests> → <doc:AuthorizationStateUpdateResponseTests> (ready)

When: Отправляем номер телефона

Then: Получаем состояние "ждём код"

When: Отправляем код подтверждения

Then: Авторизация успешна

---

### Обработка ошибок: неверный код авторизации + логирование

Тест обработки ошибки TDLib: неверный код авторизации.

**TDLib error:**
```json
{
"@type": "error",
"code": 400,
"message": "PHONE_CODE_INVALID"
}
```

**Проверяем:**
- Ошибка пробрасывается как TDLibErrorResponse
- Ошибка логируется в формате "TDLib error [code]: message"

Given: Mock logger для перехвата логов

Mock client с логгером

Настраиваем mock: код неверный → ошибка

<doc:CheckAuthenticationCodeRequestTests> → <doc:TDLibErrorResponseTests> (PHONE_CODE_INVALID)

When: Отправляем неверный код → ожидаем <doc:TDLibErrorResponseTests>

Then: Проверяем что ошибка была залогирована

---


## Topics

### Связанная документация

- <doc:TgClient>
- <doc:Authentication>

### Unit-тесты используемых моделей

- <doc:AuthorizationStateUpdateResponseTests>
- <doc:CheckAuthenticationCodeRequestTests>
- <doc:SetAuthenticationPhoneNumberRequestTests>
- <doc:TDLibErrorResponseTests>
