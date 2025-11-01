# Рефакторинг TDLibAdapter: High-Level API

**Дата создания:** 2025-11-01
**Статус:** План для следующей сессии
**Приоритет:** 🔥 Высокий (блокирует написание новых фич и component-тестов)

---

## 🎯 Цель рефакторинга

Перевести TDLibAdapter с низкоуровневого `send/receive` API на высокоуровневый типобезопасный API с методами вида:

```swift
try await setAuthenticationPhoneNumber("+123") -> Result<AuthorizationStateUpdate, TDLibError>
```

Это упростит:
- ✅ Написание component-тестов (mock конкретных методов, а не JSON)
- ✅ Читаемость кода авторизации
- ✅ Типобезопасность (компилятор проверяет типы запросов/ответов)
- ✅ Дальнейшую разработку новых фич (получение сообщений, отправка и т.д.)

---

## 📊 Текущая архитектура (проблемы)

### Код сейчас:

```swift
// Низкоуровневый API
class TDLibClient {
    func send(_ request: TDLibRequest)  // fire-and-forget
    func receive(timeout: Double) -> [String: Any]?  // poll для любых событий
}

// Использование в processAuthorizationStates():
send(SetAuthenticationPhoneNumberRequest(phoneNumber: phone))
while let obj = receive(timeout: 1.0) {
    guard let type = obj["@type"] as? String else { continue }
    if type == "updateAuthorizationState" {
        // Парсим JSON вручную
        if let authState = obj["authorization_state"] as? [String: Any] {
            // Обрабатываем состояние...
        }
    }
}
```

### Проблемы:

1. **Сложно тестировать:**
   - Нужно мокать JSON строки и Dictionary
   - В unit-тестах проверяем только парсинг моделей
   - Component-тесты невозможны без реального TDLib

2. **Отсутствие типобезопасности:**
   - `receive()` возвращает `[String: Any]?` - любой JSON
   - Вручную парсим `@type`, приводим типы
   - Легко сделать ошибку (опечатка в ключе, неверный тип)

3. **Сложная логика цикла авторизации:**
   - В `processAuthorizationStates()` вручную опрашиваем receive()
   - Смешаны concerns: отправка запросов + парсинг + state machine
   - ~150 строк кода в одном методе

4. **Параллельные события:**
   - Во время авторизации могут прийти `updateNewMessage`, `updateConnectionState` и т.д.
   - Сейчас просто пропускаем их (`continue`)
   - В будущем нужен механизм обработки фоновых событий

5. **Блокирует разработку:**
   - Для написания component-тестов нужен MockTDLibClient
   - Для мока нужен протокол TDLibClientProtocol
   - Но текущий send/receive API неудобен для моков

---

## 🎨 Целевая архитектура (решение)

### High-Level API:

```swift
protocol TDLibClientProtocol {
    // Авторизация
    func setAuthenticationPhoneNumber(_ phone: String) async throws -> AuthorizationStateUpdate
    func checkAuthenticationCode(_ code: String) async throws -> AuthorizationStateUpdate
    func checkAuthenticationPassword(_ password: String) async throws -> AuthorizationStateUpdate

    // В будущем: получение сообщений
    func getChats(limit: Int) async throws -> ChatsResponse
    func getChatHistory(chatId: Int64, limit: Int) async throws -> MessagesResponse
}

class TDLibClient: TDLibClientProtocol {
    // Внутри инкапсулируем send + receive loop
}
```

### Как работает высокоуровневый метод:

```swift
func setAuthenticationPhoneNumber(_ phone: String) async throws -> AuthorizationStateUpdate {
    // 1. Отправляем запрос
    send(SetAuthenticationPhoneNumberRequest(phoneNumber: phone))

    // 2. Ждём updateAuthorizationState в event loop
    return try await waitForAuthorizationUpdate()
}

private func waitForAuthorizationUpdate() async throws -> AuthorizationStateUpdate {
    while let obj = receive(timeout: 1.0) {
        let update = try TDLibUpdate(from: obj)  // Используем существующий TDLibUpdate enum!

        switch update {
        case .authorizationState(let authUpdate):
            return authUpdate  // Нашли нужное событие
        case .error(let error):
            throw error  // TDLib вернул ошибку
        case .unknown:
            continue  // Пропускаем неизвестные события
        }
    }
    throw TDLibError.timeout
}
```

### Преимущества:

✅ **Простой MockTDLibClient для тестов:**

```swift
class MockTDLibClient: TDLibClientProtocol {
    private var responses: [String: Result<AuthorizationStateUpdate, TDLibError>] = [:]

    func stub(
        method: String,
        result: Result<AuthorizationStateUpdate, TDLibError>
    ) {
        responses[method] = result
    }

    func setAuthenticationPhoneNumber(_ phone: String) async throws -> AuthorizationStateUpdate {
        guard let result = responses["setAuthenticationPhoneNumber"] else {
            fatalError("Не настроен stub для setAuthenticationPhoneNumber")
        }
        return try result.get()
    }
}
```

✅ **Читаемый код авторизации:**

```swift
// Было:
send(SetAuthenticationPhoneNumberRequest(phoneNumber: phone))
while let obj = receive(timeout: 1.0) { /* 20 строк парсинга */ }

// Стало:
let update = try await setAuthenticationPhoneNumber(phone)
// Компилятор гарантирует что получили AuthorizationStateUpdate
```

✅ **Типобезопасность:**
- Компилятор проверяет типы аргументов и возвращаемых значений
- Невозможно перепутать типы запросов/ответов
- Автодополнение в IDE работает корректно

---

## 📋 Подробный план рефакторинга (TDD)

### Фаза 1: Протокол и Mock (1-2 часа)

**Зачем:** Подготовить инфраструктуру для тестирования

#### 1.1 RED: Написать component-тест с желаемым API

**Файл:** `Tests/TgClientComponentTests/TDLibAdapter/AuthenticationFlowTests.swift`

```swift
@Test("Authenticate with phone and code")
func authenticateWithPhoneAndCode() async throws {
    // Given: MockTDLibClient с предопределёнными ответами
    let mockClient = MockTDLibClient()

    // Настраиваем stubs для методов
    mockClient.stub(
        method: "setAuthenticationPhoneNumber",
        result: .success(AuthorizationStateUpdate(
            authorizationState: .init(type: "authorizationStateWaitCode")
        ))
    )

    mockClient.stub(
        method: "checkAuthenticationCode",
        result: .success(AuthorizationStateUpdate(
            authorizationState: .init(type: "authorizationStateReady")
        ))
    )

    let mockLogger = MockLogger()

    // When: Запускаем авторизацию
    let client = TDLibClient(
        tdlibClient: mockClient,
        appLogger: mockLogger.logger
    )

    let phoneUpdate = try await client.setAuthenticationPhoneNumber("+1234567890")
    #expect(phoneUpdate.authorizationState.type == "authorizationStateWaitCode")

    let codeUpdate = try await client.checkAuthenticationCode("12345")
    #expect(codeUpdate.authorizationState.type == "authorizationStateReady")

    // Then: Проверяем логи
    let logs = mockLogger.getLogs()
    #expect(logs.contains { $0.message.contains("Setting phone number") })
}
```

**Ожидаемый результат:** Тест не компилируется (нет протокола, нет MockTDLibClient, нет высокоуровневых методов)

#### 1.2 GREEN: Создать минимальный протокол и Mock

**Файл:** `Sources/TDLibAdapter/TDLibClientProtocol.swift`

```swift
/// Протокол для абстракции TDLib клиента.
///
/// Позволяет подменять реальный TDLib на mock в тестах.
public protocol TDLibClientProtocol: Sendable {
    /// Отправить номер телефона для авторизации
    func setAuthenticationPhoneNumber(_ phone: String) async throws -> AuthorizationStateUpdate

    /// Проверить код подтверждения
    func checkAuthenticationCode(_ code: String) async throws -> AuthorizationStateUpdate

    /// Проверить пароль 2FA
    func checkAuthenticationPassword(_ password: String) async throws -> AuthorizationStateUpdate

    /// TODO: В будущем добавить методы для получения сообщений
    // func getChats(limit: Int) async throws -> ChatsResponse
    // func getChatHistory(chatId: Int64, limit: Int) async throws -> MessagesResponse
}
```

**Файл:** `Tests/TgClientComponentTests/Mocks/MockTDLibClient.swift`

```swift
/// Mock реализация TDLibClientProtocol для component-тестов.
///
/// Позволяет настраивать предопределённые ответы для каждого метода.
final class MockTDLibClient: TDLibClientProtocol, @unchecked Sendable {
    private var responses: [String: Result<AuthorizationStateUpdate, TDLibError>] = [:]
    private let lock = NSLock()

    /// Настроить stub для метода авторизации
    func stub(
        method: String,
        result: Result<AuthorizationStateUpdate, TDLibError>
    ) {
        lock.lock()
        defer { lock.unlock() }
        responses[method] = result
    }

    func setAuthenticationPhoneNumber(_ phone: String) async throws -> AuthorizationStateUpdate {
        // Имитируем асинхронность
        try await Task.sleep(nanoseconds: 10_000_000) // 10ms

        lock.lock()
        defer { lock.unlock() }

        guard let result = responses["setAuthenticationPhoneNumber"] else {
            fatalError("Stub not configured for setAuthenticationPhoneNumber")
        }

        return try result.get()
    }

    func checkAuthenticationCode(_ code: String) async throws -> AuthorizationStateUpdate {
        try await Task.sleep(nanoseconds: 10_000_000)

        lock.lock()
        defer { lock.unlock() }

        guard let result = responses["checkAuthenticationCode"] else {
            fatalError("Stub not configured for checkAuthenticationCode")
        }

        return try result.get()
    }

    func checkAuthenticationPassword(_ password: String) async throws -> AuthorizationStateUpdate {
        try await Task.sleep(nanoseconds: 10_000_000)

        lock.lock()
        defer { lock.unlock() }

        guard let result = responses["checkAuthenticationPassword"] else {
            fatalError("Stub not configured for checkAuthenticationPassword")
        }

        return try result.get()
    }
}
```

**Файл:** `Tests/TgClientComponentTests/Mocks/MockLogger.swift`

```swift
/// Mock реализация Logger для проверки логирования в тестах.
final class MockLogger: @unchecked Sendable {
    private var logs: [(level: Logger.Level, message: String)] = []
    private let lock = NSLock()

    /// Swift Logging Logger который записывает в этот мок
    lazy var logger: Logger = {
        // TODO: Настроить custom LogHandler
        var logger = Logger(label: "test-logger")
        return logger
    }()

    func log(level: Logger.Level, message: String) {
        lock.lock()
        defer { lock.unlock() }
        logs.append((level, message))
    }

    func getLogs() -> [(level: Logger.Level, message: String)] {
        lock.lock()
        defer { lock.unlock() }
        return logs
    }
}
```

**Ожидаемый результат:** Тест компилируется, но падает (TDLibClient не реализует протокол)

#### 1.3 REFACTOR: Внедрить протокол в TDLibClient

**Изменения в TDLibClient.swift:**

1. Добавить conformance к протоколу:
```swift
public final class TDLibClient: TDLibClientProtocol, @unchecked Sendable { ... }
```

2. Реализовать высокоуровневые методы (stub implementation):
```swift
public func setAuthenticationPhoneNumber(_ phone: String) async throws -> AuthorizationStateUpdate {
    fatalError("Not implemented yet")
}

public func checkAuthenticationCode(_ code: String) async throws -> AuthorizationStateUpdate {
    fatalError("Not implemented yet")
}

public func checkAuthenticationPassword(_ password: String) async throws -> AuthorizationStateUpdate {
    fatalError("Not implemented yet")
}
```

**Ожидаемый результат:** Тест компилируется, но падает на fatalError

---

### Фаза 2: Реализация высокоуровневых методов (2-3 часа)

**Зачем:** Инкапсулировать send + receive loop в высокоуровневые методы

#### 2.1 GREEN: Реализовать `waitForAuthorizationUpdate()`

**Внутренний helper для ожидания события авторизации:**

```swift
private func waitForAuthorizationUpdate(timeout: TimeInterval = 30) async throws -> AuthorizationStateUpdate {
    let startTime = Date()

    while Date().timeIntervalSince(startTime) < timeout {
        guard let obj = receive(timeout: authorizationPollTimeout) else {
            await Task.yield()
            continue
        }

        // Используем существующий TDLibUpdate enum для type-safe парсинга
        let update = try TDLibUpdate(from: obj)

        switch update {
        case .authorizationState(let authUpdate):
            appLogger.info("Received authorization state: \(authUpdate.authorizationState.type)")
            return authUpdate

        case .error(let error):
            appLogger.error("TDLib error: \(error.message)")
            throw error

        case .unknown(let type):
            appLogger.debug("Skipping unknown event: \(type)")
            continue
        }
    }

    throw TDLibError(code: -1, message: "Timeout waiting for authorization update")
}
```

#### 2.2 GREEN: Реализовать `setAuthenticationPhoneNumber()`

```swift
public func setAuthenticationPhoneNumber(_ phone: String) async throws -> AuthorizationStateUpdate {
    appLogger.info("Setting phone number...")

    let request = SetAuthenticationPhoneNumberRequest(phoneNumber: phone)
    send(request)

    appLogger.info("Phone number sent, waiting for response...")
    return try await waitForAuthorizationUpdate()
}
```

#### 2.3 GREEN: Реализовать остальные методы

Аналогично для:
- `checkAuthenticationCode()`
- `checkAuthenticationPassword()`

#### 2.4 REFACTOR: Обновить `processAuthorizationStates()`

**Было:** Цикл с вручную парсингом JSON и switch по состояниям

**Стало:** Используем высокоуровневые методы

```swift
private func processAuthorizationStates(
    config: TDConfig,
    promptFor: @escaping @Sendable (AuthenticationPrompt) async -> String,
    onReady: @escaping @Sendable () -> Void
) async {
    do {
        // 1. Ждём waitTdlibParameters
        var update = try await waitForAuthorizationUpdate()

        if update.authorizationState.type == "authorizationStateWaitTdlibParameters" {
            appLogger.info("Setting TDLib parameters...")
            send(SetTdlibParametersRequest(...))
            update = try await waitForAuthorizationUpdate()
        }

        // 2. Ждём waitPhoneNumber
        if update.authorizationState.type == "authorizationStateWaitPhoneNumber" {
            let phone = await promptFor(.phoneNumber)
            update = try await setAuthenticationPhoneNumber(phone)
        }

        // 3. Ждём waitCode
        if update.authorizationState.type == "authorizationStateWaitCode" {
            let code = await promptFor(.verificationCode)
            update = try await checkAuthenticationCode(code)
        }

        // 4. Если нужен пароль 2FA
        if update.authorizationState.type == "authorizationStateWaitPassword" {
            let password = await promptFor(.twoFactorPassword)
            update = try await checkAuthenticationPassword(password)
        }

        // 5. Проверяем Ready
        if update.authorizationState.type == "authorizationStateReady" {
            appLogger.info("Authorization complete!")
            onReady()
        }

    } catch {
        appLogger.error("Authorization failed: \(error)")
    }
}
```

**Результат:** Код стал на 50% короче и читаемее

---

### Фаза 3: Обработка фоновых событий (опционально, 1 час)

**Проблема:** Во время авторизации могут прийти `updateConnectionState`, `updateNewMessage` и т.д.

**Решение:** Event dispatcher для фоновых событий

```swift
actor TDLibEventDispatcher {
    private var handlers: [String: (TDLibUpdate) async -> Void] = [:]

    func register(type: String, handler: @escaping (TDLibUpdate) async -> Void) {
        handlers[type] = handler
    }

    func dispatch(_ update: TDLibUpdate) async {
        switch update {
        case .authorizationState:
            break // Обрабатывается в waitForAuthorizationUpdate()
        case .unknown(let type):
            if let handler = handlers[type] {
                await handler(update)
            }
        default:
            break
        }
    }
}
```

**Примечание:** Это можно сделать позже, когда появится реальная необходимость

---

## 📝 Чеклист выполнения

### Фаза 1: Протокол и Mock
- [ ] **1.1** Написать component-тест `AuthenticationFlowTests.swift` (RED)
- [ ] **1.2** Создать `TDLibClientProtocol.swift` с высокоуровневыми методами
- [ ] **1.3** Создать `MockTDLibClient.swift` для тестов
- [ ] **1.4** Создать `MockLogger.swift` для проверки логов
- [ ] **1.5** Добавить conformance `TDLibClient: TDLibClientProtocol` (stub methods)
- [ ] **1.6** Проверить что тест компилируется

### Фаза 2: Реализация
- [ ] **2.1** Реализовать `waitForAuthorizationUpdate()` helper
- [ ] **2.2** Реализовать `setAuthenticationPhoneNumber()`
- [ ] **2.3** Реализовать `checkAuthenticationCode()`
- [ ] **2.4** Реализовать `checkAuthenticationPassword()`
- [ ] **2.5** Запустить тесты → GREEN
- [ ] **2.6** Рефакторинг `processAuthorizationStates()` с использованием новых методов
- [ ] **2.7** Запустить все тесты (unit + component)
- [ ] **2.8** Проверить E2E тест `scripts/manual_e2e_auth.sh`

### Фаза 3: Документация
- [ ] **3.1** Обновить `TDLibAdapter/README.md` с примерами нового API
- [ ] **3.2** Добавить doc comments к высокоуровневым методам
- [ ] **3.3** Обновить `ARCHITECTURE.md` с диаграммой нового API
- [ ] **3.4** Актуализировать `TESTING.md` про component-тесты

### Фаза 4: Очистка
- [ ] **4.1** Удалить устаревший код (если есть dead code)
- [ ] **4.2** Проверить сборку на Linux (`swift build && swift test`)
- [ ] **4.3** Закоммитить изменения (по частям: протокол, mock, реализация, docs)

---

## 🤔 Обоснование архитектурных решений

### Почему не прямой `send() async throws -> Response`?

**Альтернатива:**
```swift
let response = try await send(SetAuthenticationPhoneNumberRequest())
```

**Проблема:** TDLib работает event-driven, а не request-response:
- Отправили `setAuthenticationPhoneNumber` → ответ приходит отдельно через `receive()`
- Между запросом и ответом могут прийти другие события
- Невозможно напрямую связать запрос с ответом

**Решение:** Высокоуровневые методы инкапсулируют send + receive loop

---

### Почему Result<T, Error> а не throws?

**Оба варианта работают:**

```swift
// Вариант A: throws
func setAuthenticationPhoneNumber(_ phone: String) async throws -> AuthorizationStateUpdate

// Вариант B: Result
func setAuthenticationPhoneNumber(_ phone: String) async -> Result<AuthorizationStateUpdate, TDLibError>
```

**Выбор:** Используем `async throws` (вариант A) потому что:
- ✅ Стандартный Swift подход
- ✅ Интеграция с do-catch
- ✅ Проще композиция async/await кода

`Result` полезен для sync кода или когда нужно хранить результат. Здесь не наш случай.

---

### Почему TDLibUpdate enum остаётся?

**TDLibUpdate** - это type-safe обёртка над сырым JSON от TDLib.

Высокоуровневые методы используют его внутри:
```swift
let update = try TDLibUpdate(from: obj)  // Парсинг JSON
switch update {
    case .authorizationState(let authUpdate):
        return authUpdate  // Возвращаем типизированный результат
}
```

В будущем при кодогенерации из `td_api.tl` добавим больше case в TDLibUpdate.

---

## 🔗 Связь с другими задачами

### Блокирует:
- **DEV-1.4** Component тест AuthenticationFlowTests (нужен MockTDLibClient)
- **MVP-1** ChannelMessageSource (нужны методы `getChats()`, `getChatHistory()`)

### Разблокирует:
- ✅ Написание всех component-тестов
- ✅ Простое добавление новых TDLib методов
- ✅ Возможность stubbing в E2E тестах

---

## 📚 Ресурсы

- [TDLib Getting Started](https://core.telegram.org/tdlib/getting-started)
- [TDLib API Methods](https://core.telegram.org/tdlib/docs/annotated.html)
- [Swift Concurrency](https://docs.swift.org/swift-book/LanguageGuide/Concurrency.html)
- Наш `TDLibAdapter/README.md` - текущая документация

---

## 📌 Примечания для следующей сессии

1. **Начать с Фазы 1.1** - написать RED тест
2. **Проверить существующие unit-тесты** - они не должны сломаться
3. **Коммиты делать маленькими:**
   - `feat: добавить TDLibClientProtocol`
   - `test: добавить MockTDLibClient для component-тестов`
   - `feat: реализовать высокоуровневые методы авторизации`
   - `refactor: упростить processAuthorizationStates с новым API`
   - `docs: обновить документацию TDLibAdapter`

4. **После рефакторинга:**
   - Запустить весь test suite
   - Проверить E2E тест
   - Обновить TASKS.md (отметить DEV-1.4 как разблокированную)

---

**Ожидаемое время:** 3-5 часов (включая тесты и документацию)

**Следующий шаг:** Фаза 1.1 - написать RED тест в `AuthenticationFlowTests.swift`
