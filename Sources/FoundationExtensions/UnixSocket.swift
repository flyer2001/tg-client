import Foundation
#if canImport(Glibc)
import Glibc
private let streamType = Int32(SOCK_STREAM.rawValue)
private let noSignal = Int32(MSG_NOSIGNAL)
#else
import Darwin
private let streamType = SOCK_STREAM
private let noSignal: Int32 = 0
#endif

public enum UnixSocketError: Error, Equatable {
    /// Нет слушателя по пути (служба не запущена) — повтор после старта службы.
    case unavailable(String)
    case io(String)
}

/// Локальный транспорт службы: на соединение — один запрос (байты до `\n`/EOF) и один ответ (до EOF).
///
/// POSIX вместо SwiftNIO: одна точка, без новых зависимостей.
public enum UnixSocket {
    /// Лимит запроса: курсор на тысячи чатов укладывается с запасом.
    static let maxRequestBytes = 1 << 20

    public final class Server: @unchecked Sendable {
        private let path: String
        private let fd: Int32

        /// Создаёт и слушает сокет с правами 0600. Оставшийся сокет (падение службы) заменяется,
        /// любой другой файл на этом пути — ошибка (не удаляем чужое).
        public init(path: String) throws {
            var st = stat()
            if lstat(path, &st) == 0 {
                guard (st.st_mode & mode_t(S_IFMT)) == mode_t(S_IFSOCK) else { throw UnixSocketError.io("\(path): не сокет, не трогаю") }
                unlink(path)
            }
            let fd = socket(AF_UNIX, streamType, 0)
            guard fd >= 0 else { throw UnixSocketError.io("socket: \(errnoText())") }
            var addr = try UnixSocket.address(path)
            let bound = withUnsafePointer(to: &addr) {
                $0.withMemoryRebound(to: sockaddr.self, capacity: 1) { bind(fd, $0, socklen_t(MemoryLayout<sockaddr_un>.size)) }
            }
            // ponytail: chmod после bind — окно в микросекунды; umask процесса глобален, трогать его хуже
            guard bound == 0, chmod(path, 0o600) == 0, listen(fd, 8) == 0 else {
                let text = errnoText()
                close(fd)
                throw UnixSocketError.io("bind/listen \(path): \(text)")
            }
            self.path = path
            self.fd = fd
        }

        /// Цикл приёма на отдельном потоке. Соединения обрабатываются строго по одному:
        /// служба держит одну сессию TDLib, параллельные обходы чатов только множат FLOOD_WAIT.
        // ponytail: get-summary блокирует read на время обхода; очередь с приоритетом — если станет мешать
        public func start(handler: @escaping @Sendable (Data) async -> Data) {
            let fd = self.fd
            Thread.detachNewThread {
                while true {
                    let conn = accept(fd, nil, nil)
                    if conn < 0 {
                        if errno == EINTR { continue }
                        return   // stop(): слушающий сокет закрыт
                    }
                    UnixSocket.setTimeout(conn, seconds: 5)
                    if let request = try? UnixSocket.readAll(conn, untilNewline: true) {
                        let box = ResponseBox()
                        let done = DispatchSemaphore(value: 0)
                        Task { box.data = await handler(request); done.signal() }
                        done.wait()
                        _ = try? UnixSocket.writeAll(conn, box.data)
                    }
                    close(conn)
                }
            }
        }

        public func stop() {
            shutdown(fd, Int32(SHUT_RDWR))   // будит accept на Linux
            close(fd)
            var st = stat()
            if lstat(path, &st) == 0, (st.st_mode & mode_t(S_IFMT)) == mode_t(S_IFSOCK) { unlink(path) }
        }
    }

    /// Клиент: отправить запрос, дождаться ответа. `timeout` — на ожидание ответа (обход чатов долгий).
    public static func request(path: String, _ body: Data, timeout: Int = 600) throws -> Data {
        let fd = socket(AF_UNIX, streamType, 0)
        guard fd >= 0 else { throw UnixSocketError.io("socket: \(errnoText())") }
        defer { close(fd) }
        var addr = try address(path)
        let connected = withUnsafePointer(to: &addr) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) { connect(fd, $0, socklen_t(MemoryLayout<sockaddr_un>.size)) }
        }
        guard connected == 0 else {
            let code = errno
            if code == ENOENT || code == ECONNREFUSED { throw UnixSocketError.unavailable("\(path): \(errnoText())") }
            throw UnixSocketError.io("connect \(path): \(errnoText())")
        }
        setTimeout(fd, seconds: timeout)
        try writeAll(fd, body + Data("\n".utf8))
        shutdown(fd, Int32(SHUT_WR))
        return try readAll(fd, untilNewline: false)
    }

    // MARK: - POSIX

    private final class ResponseBox: @unchecked Sendable { var data = Data() }

    private static func address(_ path: String) throws -> sockaddr_un {
        var addr = sockaddr_un()
        addr.sun_family = sa_family_t(AF_UNIX)
        let bytes = Array(path.utf8)
        let capacity = MemoryLayout.size(ofValue: addr.sun_path)
        guard bytes.count < capacity else { throw UnixSocketError.io("путь сокета длиннее \(capacity - 1) байт: \(path)") }
        withUnsafeMutableBytes(of: &addr.sun_path) { raw in
            raw.copyBytes(from: bytes)
            raw[bytes.count] = 0
        }
        return addr
    }

    private static func setTimeout(_ fd: Int32, seconds: Int) {
        var tv = timeval(tv_sec: seconds, tv_usec: 0)
        setsockopt(fd, SOL_SOCKET, SO_RCVTIMEO, &tv, socklen_t(MemoryLayout<timeval>.size))
        setsockopt(fd, SOL_SOCKET, SO_SNDTIMEO, &tv, socklen_t(MemoryLayout<timeval>.size))
        #if !canImport(Glibc)
        var one: Int32 = 1
        setsockopt(fd, SOL_SOCKET, SO_NOSIGPIPE, &one, socklen_t(MemoryLayout<Int32>.size))
        #endif
    }

    private static func readAll(_ fd: Int32, untilNewline: Bool) throws -> Data {
        var out = Data()
        var buf = [UInt8](repeating: 0, count: 64 * 1024)
        while true {
            let n = read(fd, &buf, buf.count)
            if n < 0 {
                if errno == EINTR { continue }
                throw UnixSocketError.io("read: \(errnoText())")
            }
            if n == 0 { break }
            out.append(contentsOf: buf[0..<n])
            if untilNewline, out.count > maxRequestBytes { throw UnixSocketError.io("запрос больше \(maxRequestBytes) байт") }
            if untilNewline, let i = out.firstIndex(of: UInt8(ascii: "\n")) { return out[out.startIndex..<i] }
        }
        return out
    }

    private static func writeAll(_ fd: Int32, _ data: Data) throws {
        try data.withUnsafeBytes { raw in
            var sent = 0
            while sent < raw.count {
                let n = send(fd, raw.baseAddress! + sent, raw.count - sent, noSignal)
                if n < 0 {
                    if errno == EINTR { continue }
                    throw UnixSocketError.io("write: \(errnoText())")
                }
                sent += n
            }
        }
    }

    private static func errnoText() -> String { String(cString: strerror(errno)) }
}
