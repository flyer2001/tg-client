# TDLibAdapter

Swift-обёртка над TDLib (Telegram Database Library) C API для взаимодействия с Telegram.

## Что такое TDLib?

TDLib — официальная кросс-платформенная библиотека от Telegram для создания Telegram-клиентов. Она предоставляет:

- Полный доступ к Telegram API
- Автоматическое управление сетевыми соединениями
- Локальное кэширование и базу данных
- Обработку медиа-файлов
- End-to-end шифрование для секретных чатов

## Архитектура модуля

Модуль состоит из трёх слоёв:

```
┌─────────────────────────────────────┐
│         TDLibClient                 │  ← Swift-обёртка с async/await
│  (Swift Concurrency + JSON API)    │
├─────────────────────────────────────┤
│          CTDLib                     │  ← System Library (module.modulemap)
│     (C Headers: shim.h)             │
├─────────────────────────────────────┤
│      TDLib C Library                │  ← Нативная библиотека (libtdjson)
│   (td_json_client.h, td_log.h)     │
└─────────────────────────────────────┘
```

### Компоненты

1. **TDConfig** - конфигурация для подключения к Telegram API
2. **TDLibClient** - основной класс для взаимодействия с TDLib
3. **CTDLib** - системная библиотека (см. `Sources/CTDLib/`)

## Получение API Credentials

Для работы с Telegram API нужно получить `api_id` и `api_hash`:

1. Перейдите на https://my.telegram.org/apps
2. Войдите через свой номер телефона
3. Создайте новое приложение (App title и Short name могут быть любыми)
4. Скопируйте **App api_id** и **App api_hash**

⚠️ **Важно:** НЕ коммитьте эти credentials в git! Храните их в переменных окружения.

## Использование

### Базовый пример

```swift
import TDLibAdapter
import Logging

// 1. Создаём logger
let logger = Logger(label: "telegram-client")

// 2. Создаём конфигурацию
let config = TDConfig(
    apiId: 12345,  // Ваш api_id
    apiHash: "your_api_hash",  // Ваш api_hash
    stateDir: "\(FileManager.default.homeDirectoryForCurrentUser.path)/.tdlib",
    logPath: "\(FileManager.default.homeDirectoryForCurrentUser.path)/.tdlib/tdlib.log"
)

// 3. Создаём клиент
let client = TDLibClient(logger: logger)

// 4. Запускаем авторизацию
await client.start(
    config: config,
    askPhone: {
        print("Enter phone number: ")
        return readLine() ?? ""
    },
    askCode: {
        print("Enter code: ")
        return readLine() ?? ""
    },
    askPassword: {
        print("Enter 2FA password: ")
        return readLine() ?? ""
    }
)

// 5. Клиент готов к использованию!
print("✅ Authorization complete")
```

### Отправка запросов

```swift
// Отправка запроса
client.send([
    "@type": "getMe"
])

// Получение ответа
if let response = client.receive(timeout: 5.0),
   let type = response["@type"] as? String {
    print("Received: \(type)")
}
```

## Коммуникация с TDLib

TDLib использует **JSON-based протокол**:

### Формат сообщений

Все сообщения (запросы и ответы) являются JSON-объектами с обязательным полем `@type`:

```json
{
  "@type": "getMe"
}
```

Ответ:
```json
{
  "@type": "user",
  "id": 123456789,
  "first_name": "John",
  "last_name": "Doe",
  "username": "johndoe"
}
```

### Процесс авторизации

TDLib использует **state machine** для авторизации:

```
authorizationStateWaitTdlibParameters
           ↓
authorizationStateWaitEncryptionKey
           ↓
authorizationStateWaitPhoneNumber
           ↓
authorizationStateWaitCode
           ↓
authorizationStateWaitPassword (если включен 2FA)
           ↓
authorizationStateReady ✅
```

`TDLibClient.start()` автоматически проходит все эти состояния, запрашивая у пользователя необходимые данные через колбэки.

## Thread Safety

`TDLibClient` помечен как `@unchecked Sendable` потому что:

- TDLib C API является **thread-safe** изначально
- Внутренний указатель `client` защищён через синхронный доступ
- Асинхронные операции обрабатываются через Swift Concurrency

## Директории и файлы

### Структура `stateDir`

```
~/.tdlib/
├── db/              # База данных TDLib (чаты, сообщения, пользователи)
├── files/           # Кэш медиа-файлов
└── tdlib.log        # Логи TDLib (по умолчанию отключены)
```

⚠️ **НЕ коммитьте директорию `.tdlib` в git!** Там хранится ваша сессия.

## Ссылки

- **TDLib Documentation:** https://core.telegram.org/tdlib/docs
- **TDLib GitHub:** https://github.com/tdlib/td
- **TDLib JSON API:** https://core.telegram.org/tdlib/docs/td__json__client_8h.html
- **Получение API credentials:** https://my.telegram.org/apps

## Лицензия

TDLib распространяется под лицензией Boost Software License 1.0.
