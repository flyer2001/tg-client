import Foundation
import Testing
@testable import TDLibAdapter

/// Воспроизведение записанного трафика TDLib (контрактные тесты, testing-v1-plan.md И6).
///
/// Запись — `RecordingTDLibFFI` (`TG_TDLIB_RECORD`) → `scripts/tdlib-recording-anonymize.py` →
/// `Tests/Fixtures/tdlib/<name>.jsonl`. Данные — **как в жизни** (нетекстовые сообщения, форумы, отстающие счётчики),
/// а не как мы думаем, что ответит TDLib.
///
/// **Сопоставление:** запрос клиента ищется в записи по параметрам без `@extra` (порядок параллельных запросов не важен);
/// в ответ — updates, пришедшие в записи между этим запросом и ответом, затем сам ответ с новым `@extra`.
/// Незаписанный запрос — issue на строке создания (код пошёл не тем путём, что при записи) + TDLib-ошибка клиенту.
public final class ReplayTDLibFFI: TDLibFFI, @unchecked Sendable {
    private struct Segment {
        let key: String
        let request: [String: Any]
        var updates: [String] = []
        var response: String?
        var used = false
    }

    private let lock = NSLock()
    private var segments: [Segment] = []
    private var pending: [String] = []
    private var sent: [[String: Any]] = []
    private let createdAt: SourceLocation

    /// - Parameter fixture: имя файла в `Tests/Fixtures/tdlib/` без `.jsonl`.
    public init(fixture: String, sourceLocation: SourceLocation = #_sourceLocation) throws {
        createdAt = sourceLocation
        let url = Self.fixturesDir.appendingPathComponent("\(fixture).jsonl")
        var openByExtra: [String: Int] = [:]
        var lastOpen: Int?
        for line in try String(contentsOf: url, encoding: .utf8).split(separator: "\n") {
            guard let rec = try JSONSerialization.jsonObject(with: Data(line.utf8)) as? [String: Any],
                  let dir = rec["dir"] as? String, let json = rec["json"] as? [String: Any] else { continue }
            let extra = json["@extra"].map { "\($0)" }
            if dir == "send" {
                guard let extra else { continue }   // fire-and-forget (авторизация) не воспроизводим
                segments.append(Segment(key: Self.key(json), request: json))
                openByExtra[extra] = segments.count - 1
                lastOpen = segments.count - 1
            } else if let extra, let i = openByExtra.removeValue(forKey: extra) {
                segments[i].response = try Self.string(json)
            } else if extra == nil, let i = lastOpen, segments[i].response == nil {
                segments[i].updates.append(try Self.string(json))   // update пришёл, пока ждали ответ
            }
        }
    }

    /// Папка фикстур: рядом с исходниками тестов (тесты запускаются из дерева исходников).
    public static var fixturesDir: URL {
        URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("Fixtures/tdlib")
    }

    public func create() throws {}

    public func send(_ request: String) {
        lock.lock()
        defer { lock.unlock() }
        guard let json = try? JSONSerialization.jsonObject(with: Data(request.utf8)) as? [String: Any] else { return }
        sent.append(json)
        guard let extra = json["@extra"].map({ "\($0)" }) else { return }
        let key = Self.key(json)
        guard let i = segments.firstIndex(where: { !$0.used && $0.key == key }), let response = segments[i].response else {
            Issue.record(Comment(rawValue: "ReplayTDLibFFI: запроса нет в записи — \(key.prefix(300))"), sourceLocation: createdAt)
            pending.append(#"{"@type":"error","code":500,"message":"ReplayTDLibFFI: not recorded","@extra":"\#(extra)"}"#)
            return
        }
        segments[i].used = true
        pending += segments[i].updates
        pending.append(Self.replacingExtra(response, with: extra))
    }

    public func receive(timeout: Double) -> String? {
        lock.lock()
        if !pending.isEmpty {
            let next = pending.removeFirst()
            lock.unlock()
            return next   // без паузы: sendAndWait регистрирует waiter до ffi.send (30/30 прогонов без флейков)
        }
        lock.unlock()
        Thread.sleep(forTimeInterval: min(timeout, 0.001))
        return nil
    }

    // MARK: - Для проверок

    /// Отправленные клиентом запросы типа `type`.
    public func sentRequests(ofType type: String) -> [[String: Any]] {
        lock.lock()
        defer { lock.unlock() }
        return sent.filter { $0["@type"] as? String == type }
    }

    /// Самый новый id сообщения (любого типа) в записанных ответах на `type` для чата — то, до чего обязан дойти курсор.
    public func newestRecordedMessageId(type: String, chatId: Int64, extra: [String: Int64] = [:]) -> Int64? {
        lock.lock()
        defer { lock.unlock() }
        let ids = segments.filter { seg in
            seg.request["@type"] as? String == type && (seg.request["chat_id"] as? NSNumber)?.int64Value == chatId
                && extra.allSatisfy { (seg.request[$0.key] as? NSNumber)?.int64Value == $0.value }
        }.flatMap { seg -> [Int64] in
            guard let data = seg.response?.data(using: .utf8),
                  let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let messages = obj["messages"] as? [[String: Any]] else { return [] }
            return messages.compactMap { ($0["id"] as? NSNumber)?.int64Value }
        }
        return ids.max()
    }

    // MARK: - JSON

    private static func key(_ json: [String: Any]) -> String {
        var j = json
        j["@extra"] = nil
        j["@client_id"] = nil
        return (try? string(j)) ?? ""
    }

    private static func string(_ json: [String: Any]) throws -> String {
        String(decoding: try JSONSerialization.data(withJSONObject: json, options: [.sortedKeys]), as: UTF8.self)
    }

    private static func replacingExtra(_ response: String, with extra: String) -> String {
        guard var obj = try? JSONSerialization.jsonObject(with: Data(response.utf8)) as? [String: Any] else { return response }
        obj["@extra"] = extra
        return (try? string(obj)) ?? response
    }
}
