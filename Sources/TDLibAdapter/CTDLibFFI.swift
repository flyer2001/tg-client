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

    func send(_ request: String) {
        guard let client else {
            preconditionFailure("CTDLibFFI: client not created")
        }

        // JSON уже содержит @extra (сгенерированный TDLibClient)
        td_json_client_send(client, request)
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
