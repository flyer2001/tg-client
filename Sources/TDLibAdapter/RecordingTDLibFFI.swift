import Foundation

/// Запись трафика TDLib в JSONL для контрактных тестов (testing-v1-plan.md, И6): каждая строка —
/// `{"dir":"send"|"recv","json":<объект TDLib>}`. Включается `TG_TDLIB_RECORD=<путь>`.
///
/// **Сырые записи содержат личные сообщения** — только локально; в репозиторий — после
/// `scripts/tdlib-recording-anonymize.py`.
final class RecordingTDLibFFI: TDLibFFI, @unchecked Sendable {
    private let inner: TDLibFFI
    private let handle: FileHandle
    private let lock = NSLock()

    init?(inner: TDLibFFI, path: String) {
        FileManager.default.createFile(atPath: path, contents: nil, attributes: [.posixPermissions: 0o600])
        guard let handle = FileHandle(forWritingAtPath: path) else { return nil }
        self.inner = inner
        self.handle = handle
    }

    func create() throws { try inner.create() }

    func send(_ request: String) {
        write("send", request)
        inner.send(request)
    }

    func receive(timeout: Double) -> String? {
        let response = inner.receive(timeout: timeout)
        if let response { write("recv", response) }
        return response
    }

    private func write(_ dir: String, _ json: String) {
        lock.lock()
        defer { lock.unlock() }
        handle.write(Data(#"{"dir":"\#(dir)","json":\#(json)}"#.utf8) + Data("\n".utf8))
    }
}
