import Foundation
import CTDLib

/// Реальная реализация TDLibFFI через CTDLib C-библиотеку.
///
/// Управляет жизненным циклом TDLib клиента:
/// - `create()` создаёт клиент через `td_json_client_create()`
/// - `deinit` уничтожает клиент через `td_json_client_destroy()`
final class CTDLibFFI: TDLibFFI {

    private var client: UnsafeMutableRawPointer?

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
            fatalError("CTDLibFFI.send(): client not created (call create() first)")
        }
        td_json_client_send(client, request)
    }

    func receive(timeout: Double) -> String? {
        guard let client else {
            fatalError("CTDLibFFI.receive(): client not created (call create() first)")
        }
        guard let cstr = td_json_client_receive(client, timeout) else {
            return nil
        }
        return String(cString: cstr)
    }
}
