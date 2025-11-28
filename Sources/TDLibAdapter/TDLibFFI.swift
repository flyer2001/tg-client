import TgClientModels
import Foundation

enum TDLibFFIError: Error {
    case failedToCreateClient
}

/// Протокол для низкоуровневого FFI слоя TDLib (Foreign Function Interface).
///
/// Абстрагирует работу с C-функциями TDLib (`td_json_client_*`), позволяя:
/// - Тестировать TDLibClient с Mock реализацией
/// - Изолировать unsafe C interop от основного кода
///
/// ## Реализации
///
/// - **CTDLibFFI** — реальная обёртка над `CTDLib` (td_json_client_create/send/receive/destroy)
/// - **MockTDLibFFI** — mock для Unit-тестов (работает с моделями вместо TDLib)
///
/// ## Поток данных
///
/// ```
/// TDLibClient
///   ↓ send(_ request: TDLibRequest)
///   ↓ encode → JSON String
/// TDLibFFI.send(_ json: String)
///   ↓ (CTDLibFFI: td_json_client_send)
///   ↓ (MockTDLibFFI: парсит и мокирует)
///
/// TDLibFFI.receive(timeout) → JSON String?
///   ↑ (CTDLibFFI: td_json_client_receive)
///   ↑ (MockTDLibFFI: возвращает замоканный JSON)
///   ↑ parse → TDLibJSON
/// TDLibClient
/// ```
///
/// ## Клиент хранится внутри реализации
///
/// Реализации сами управляют жизненным циклом клиента:
/// - `init()` создаёт клиент (CTDLibFFI: td_json_client_create)
/// - `deinit` уничтожает клиент (CTDLibFFI: td_json_client_destroy)
///
/// **TDLib docs:** https://core.telegram.org/tdlib/docs/classtd_1_1_client_manager.html
protocol TDLibFFI {
    /// Создаёт TDLib клиент (вызывается в TDLibClient.start).
    ///
    /// **CTDLibFFI:** вызывает `td_json_client_create()`
    ///
    /// **MockTDLibFFI:** пустая реализация (клиент уже готов)
    ///
    /// - Throws: `TDLibFFIError.failedToCreateClient` если TDLib не смог создать клиент
    func create() throws

    /// Отправляет JSON запрос в TDLib, генерирует @extra и возвращает его.
    ///
    /// - Parameter request: JSON строка запроса с полями "@type"
    /// - Returns: Сгенерированный уникальный @extra ID для матчинга response
    ///
    /// **CTDLibFFI:** добавляет @extra в JSON, вызывает `td_json_client_send(client, request)`
    ///
    /// **MockTDLibFFI:** парсит JSON, генерирует @extra, находит замоканный ответ по @type
    ///
    /// **@discardableResult:** Для fire-and-forget запросов (authentication) return можно игнорировать.
    @discardableResult
    func send(_ request: String) -> String

    /// Получает JSON ответ от TDLib (блокирующий вызов).
    ///
    /// - Parameter timeout: Максимальное время ожидания в секундах
    /// - Returns: JSON строка ответа с полями "@type" и "@extra", или `nil` при timeout
    ///
    /// **CTDLibFFI:** вызывает `td_json_client_receive(client, timeout)`
    ///
    /// **MockTDLibFFI:** возвращает замоканный JSON из очереди pending responses
    func receive(timeout: Double) -> String?
}
