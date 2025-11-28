import Foundation
import CTDLib
import Logging

/// Реальная реализация TDLibFFI через CTDLib C-библиотеку.
///
/// Управляет жизненным циклом TDLib клиента:
/// - `create()` создаёт клиент через `td_json_client_create()`
/// - `deinit` уничтожает клиент через `td_json_client_destroy()`
///
/// ## Thread Safety
///
/// - **send()** thread-safe (можно вызывать из разных потоков)
/// - **receive()** ДОЛЖЕН вызываться только из одного потока (serial DispatchQueue)
///
/// При первом вызове `receive()` запоминается текущий pthread, последующие вызовы
/// проверяют что поток не изменился (через `precondition`).
final class CTDLibFFI: TDLibFFI {

    private var client: UnsafeMutableRawPointer?

    /// Logger для ошибок FFI слоя.
    private let logger = Logger(label: "com.tg-client.tdlib.ffi")

    /// Поток, на котором был первый вызов receive().
    /// Используется для проверки thread safety.
    private var expectedThread: pthread_t?

    /// Уникальный ID сессии FFI клиента.
    private let sessionId = UUID().uuidString.prefix(8)

    /// Счётчик для генерации уникального @extra.
    private var extraCounter: UInt64 = 0

    /// Lock для thread-safe инкремента extraCounter.
    private let counterLock = NSLock()

    init() {}

    func create() throws {
        guard let c = td_json_client_create() else {
            throw TDLibFFIError.failedToCreateClient
        }
        self.client = c
    }

    deinit {
        if let c = client {
            td_json_client_destroy(c)
        }
    }

    @discardableResult
    func send(_ request: String) -> String {
        guard let client else {
            preconditionFailure("CTDLibFFI: client not created")
        }

        // Парсим JSON (должен быть валидным от TDLibRequestEncoder)
        guard let data = request.data(using: .utf8),
              var dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            fatalError("CTDLibFFI.send(): invalid JSON from encoder: \(request)")
        }

        // Генерируем @extra
        counterLock.lock()
        extraCounter &+= 1
        let extra = "\(sessionId)_\(extraCounter)"
        counterLock.unlock()

        // Добавляем @extra
        dict["@extra"] = extra

        // Re-encode (не должен упасть)
        guard let newData = try? JSONSerialization.data(withJSONObject: dict),
              let jsonWithExtra = String(data: newData, encoding: .utf8) else {
            fatalError("CTDLibFFI.send(): failed to encode with @extra")
        }

        td_json_client_send(client, jsonWithExtra)
        return extra
    }

    func receive(timeout: Double) -> String? {
        guard let client else {
            fatalError("CTDLibFFI.receive(): client not created (call create() first)")
        }

        // Проверка thread safety: receive() ДОЛЖЕН вызываться только из одного потока (serial DispatchQueue)
        let currentThread = pthread_self()
        if let expected = expectedThread {
            precondition(
                pthread_equal(currentThread, expected) != 0,
                "CTDLibFFI.receive() вызван из другого потока! Ожидался: \(expected), получен: \(currentThread)"
            )
        } else {
            // Первый вызов: запоминаем поток
            expectedThread = currentThread
        }

        guard let cstr = td_json_client_receive(client, timeout) else {
            return nil
        }
        return String(cString: cstr)
    }
}
