import Testing
import Foundation
@testable import FoundationExtensions

/// Unit-тесты транспорта службы: unix-сокет, один запрос (строка) → один ответ на соединение.
///
/// **Зачем:** CLI (`get-summary`/`read`) ходит к службе, владеющей сессией TDLib, не открывая её сам.
/// Права сокета 0600 — доступ только владельцу (папка `~/.tdlib` может быть шире).
@Suite("UnixSocket: сервер и клиент", .timeLimit(.minutes(1)), .serialized)
struct UnixSocketTests {

    private func tempPath() -> String {
        FileManager.default.temporaryDirectory.appendingPathComponent("tgc-\(UUID().uuidString.prefix(8)).sock").path
    }

    private func upper(_ data: Data) async -> Data {
        Data(String(decoding: data, as: UTF8.self).uppercased().utf8)
    }

    @Test("запрос → ответ, несколько соединений подряд")
    func roundtrip() throws {
        let path = tempPath()
        let server = try UnixSocket.Server(path: path)
        server.start(handler: upper)
        defer { server.stop() }

        #expect(try UnixSocket.request(path: path, Data("hello".utf8)) == Data("HELLO".utf8))
        #expect(try UnixSocket.request(path: path, Data(#"{"op":"read"}"#.utf8)) == Data(#"{"OP":"READ"}"#.utf8))
    }

    @Test("сокет создаётся с правами 0600, stop удаляет файл")
    func permissionsAndCleanup() throws {
        let path = tempPath()
        let server = try UnixSocket.Server(path: path)
        let perms = try FileManager.default.attributesOfItem(atPath: path)[.posixPermissions] as? Int
        #expect(perms == 0o600)
        server.stop()
        #expect(!FileManager.default.fileExists(atPath: path))
    }

    @Test("нет службы → unavailable")
    func unavailable() {
        do { _ = try UnixSocket.request(path: tempPath(), Data("x".utf8)) } catch UnixSocketError.unavailable {
            // ok
        } catch { Issue.record("ожидали unavailable, получили \(error)") }
    }

    @Test("оставшийся сокет (рестарт после падения) заменяется новым сервером")
    func replacesLeftoverSocket() throws {
        let path = tempPath()
        let old = try UnixSocket.Server(path: path)    // не остановлен — как после kill -9
        defer { old.stop() }
        let server = try UnixSocket.Server(path: path)
        server.start(handler: upper)
        defer { server.stop() }
        #expect(try UnixSocket.request(path: path, Data("ok".utf8)) == Data("OK".utf8))
    }

    @Test("на месте сокета обычный файл → ошибка, файл не трогаем")
    func refusesRegularFile() throws {
        let path = tempPath()
        try Data("keep".utf8).write(to: URL(fileURLWithPath: path))
        defer { try? FileManager.default.removeItem(atPath: path) }
        #expect(throws: UnixSocketError.self) { try UnixSocket.Server(path: path) }
        #expect(try Data(contentsOf: URL(fileURLWithPath: path)) == Data("keep".utf8))
    }
}
