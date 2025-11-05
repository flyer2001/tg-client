# Authentication

Полный цикл авторизации пользователя в Telegram через TDLib.

## Обзор

Авторизация в Telegram проходит через несколько состояний TDLib.
Приложение обрабатывает каждое состояние и запрашивает необходимые данные у пользователя.

TDLib отслеживает состояние авторизации на стороне клиента и уведомляет о каждом изменении через updates.

## E2E Сценарии

### Сценарий 1: Успешная авторизация (phone + code)

**Шаги:**

1. **Старт TDLib** → `authorizationStateWaitTdlibParameters`
   - Приложение устанавливает параметры (API ID, API Hash, database directory)

2. **Установка ключа БД** → `authorizationStateWaitEncryptionKey`
   - Приложение устанавливает encryption key (пустой для нового пользователя)

3. **Запрос номера** → `authorizationStateWaitPhoneNumber`
   - Пользователь вводит номер телефона (формат: `+1234567890`)

4. **Запрос кода** → `authorizationStateWaitCode`
   - Telegram отправляет SMS/код в приложение
   - Пользователь вводит код подтверждения

5. **Успешная авторизация** → `authorizationStateReady` ✅
   - Пользователь авторизован
   - Можно начинать работу с API

**Пример кода:**

```swift
// См. Sources/TDLibAdapter/TDLibAdapter.swift
let client = TDLibAdapter()
try await client.start()

// TDLib автоматически переходит через состояния
// Приложение реагирует на каждое через AuthorizationLoopActivity
```

### Сценарий 2: Авторизация с 2FA (phone + code + password)

**Шаги:**

1-4. (Как в сценарии 1)

5. **Запрос пароля 2FA** → `authorizationStateWaitPassword`
   - У пользователя включена двухфакторная аутентификация
   - Пользователь вводит пароль

6. **Успешная авторизация** → `authorizationStateReady` ✅

**Документация TDLib:** [Two-Step Verification](https://core.telegram.org/api/srp)

### Сценарий 3: Обработка ошибок

**Неверный номер телефона:**

```
Input: +123invalid
TDLib response: {"@type": "error", "code": 400, "message": "PHONE_NUMBER_INVALID"}
Action: Повторный запрос номера
```

**Неверный код подтверждения:**

```
Input: 00000
TDLib response: {"@type": "error", "code": 401, "message": "PHONE_CODE_INVALID"}
Action: Повторный запрос кода
```

**Неверный пароль 2FA:**

```
Input: wrong_password
TDLib response: {"@type": "error", "code": 401, "message": "PASSWORD_HASH_INVALID"}
Action: Повторный запрос пароля
```

## Используемые компоненты

### Component Level

- **TDLibAdapter** - низкоуровневая работа с TDLib C API
  - Управление состояниями авторизации
  - Отправка запросов (setAuthenticationPhoneNumber, checkAuthenticationCode, etc.)
  - Обработка updates от TDLib
  - См. `Tests/TgClientComponentTests/TDLibAdapter/AuthenticationFlowTests.swift` (TODO)

### Unit Level

**Модели состояний:**
- ``AuthorizationState`` - enum всех состояний авторизации
  - См. `Sources/TDLibAdapter/Models/AuthorizationState.swift`

**Request модели:**
- ``SetAuthenticationPhoneNumberRequest`` - установка номера телефона
  - См. `Sources/TDLibAdapter/TDLibCodableModels/Requests/SetAuthenticationPhoneNumberRequest.swift`
- ``CheckAuthenticationCodeRequest`` - проверка кода подтверждения
  - См. `Sources/TDLibAdapter/TDLibCodableModels/Requests/CheckAuthenticationCodeRequest.swift`
- ``CheckAuthenticationPasswordRequest`` - проверка пароля 2FA
  - См. `Sources/TDLibAdapter/TDLibCodableModels/Requests/CheckAuthenticationPasswordRequest.swift`

**Response модели:**
- ``AuthorizationStateUpdate`` - обёртка для updates авторизации
  - См. `Tests/TgClientUnitTests/TDLibAdapter/ResponseDecodingTests.swift`
- ``TDLibError`` - модель ошибок от TDLib
  - См. `Tests/TgClientUnitTests/TDLibAdapter/ResponseDecodingTests.swift`

## Таблица ошибок

| Код | Сообщение | Причина | Обработка |
|-----|-----------|---------|-----------|
| 400 | PHONE_NUMBER_INVALID | Неверный формат номера | Повторный запрос |
| 401 | PHONE_CODE_INVALID | Неверный код подтверждения | Повторный запрос |
| 401 | PASSWORD_HASH_INVALID | Неверный пароль 2FA | Повторный запрос |
| 429 | FLOOD_WAIT | Rate limit (слишком много попыток) | Ожидание N секунд |
| 500 | INTERNAL | Внутренняя ошибка TDLib/сервера | Повтор с exponential backoff |

## Внешние зависимости

- [TDLib Authorization States](https://core.telegram.org/tdlib/.claude/classtd_1_1td__api_1_1authorization_state.html)
- [TDLib Authentication Methods](https://core.telegram.org/tdlib/.claude/classtd_1_1td__api_1_1set_authentication_phone_number.html)
- [Telegram Two-Step Verification](https://core.telegram.org/api/srp)

## Диаграмма состояний

```
┌─────────────────────────────────────────────────────────────┐
│                    Authorization Flow                        │
└─────────────────────────────────────────────────────────────┘

    Start TDLib
         │
         ▼
  WaitTdlibParameters ──► SetTdlibParameters
         │
         ▼
  WaitEncryptionKey ──► SetDatabaseEncryptionKey
         │
         ▼
  WaitPhoneNumber ──► SetAuthenticationPhoneNumber
         │
         ▼
  WaitCode ──► CheckAuthenticationCode
         │
         ├─► Ready ✅ (если нет 2FA)
         │
         ├─► WaitPassword ──► CheckAuthenticationPassword
         │        │
         │        └─► Ready ✅
         │
         └─► Error ❌
              │
              └─► Повтор ввода (phone/code/password)
```

## См. также

- ``TDLibAdapter`` - основной адаптер для работы с TDLib
- ``AuthorizationLoopActivity`` - state machine авторизации
- `Tests/TgClientE2ETests/AuthenticationE2ETests.swift` - E2E тесты (TODO)
