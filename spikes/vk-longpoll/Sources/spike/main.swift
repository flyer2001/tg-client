// Throwaway spike — НЕ продакшен. Отвечает на вопросы:
// 1) реальная форма ответов getLongPollServer / a_check (updates, failed=1/2/3);
// 2) отменяется ли async URLSession.data(for:) на Linux, и как быстро;
// 3) живой JSON message_new для unit-тестов.
// Запуск: swift run spike  (читает ../../.env: VK_BOT_TOKEN, VK_BOT_GROUP_ID)
import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

func loadEnv() -> [String: String] {
    let path = FileManager.default.currentDirectoryPath + "/../../.env"
    let text = (try? String(contentsOfFile: path, encoding: .utf8)) ?? ""
    var env: [String: String] = [:]
    for line in text.split(separator: "\n") where !line.hasPrefix("#") {
        let parts = line.split(separator: "=", maxSplits: 1)
        if parts.count == 2 { env[String(parts[0])] = String(parts[1]) }
    }
    return env
}

let env = loadEnv()
guard let token = env["VK_BOT_TOKEN"], let groupId = env["VK_BOT_GROUP_ID"] else { fatalError("no VK env") }
let session = URLSession(configuration: .ephemeral)

func redact(_ s: String) -> String {
    s.replacingOccurrences(of: #""key"\s*:\s*"[^"]+""#, with: #""key":"<KEY>""#, options: .regularExpression)
}

func get(_ url: String) async throws -> (String, TimeInterval) {
    let start = Date()
    let (data, _) = try await session.data(from: URL(string: url)!)
    return (String(decoding: data, as: UTF8.self), Date().timeIntervalSince(start))
}

func section(_ title: String) { print("\n===== \(title)") }

// 1. getLongPollServer
section("groups.getLongPollServer")
let (srvRaw, _) = try await get("https://api.vk.com/method/groups.getLongPollServer?group_id=\(groupId)&access_token=\(token)&v=5.199")
print(redact(srvRaw))
struct Srv: Decodable { let response: R; struct R: Decodable { let server: String; let key: String; let ts: String } }
let srv = try JSONDecoder().decode(Srv.self, from: Data(srvRaw.utf8)).response

// 2. a_check с текущим ts (wait=3) — обычно пустые updates
section("a_check ts=current wait=3")
let (empty, t1) = try await get("\(srv.server)?act=a_check&key=\(srv.key)&ts=\(srv.ts)&wait=3")
print(empty, String(format: "(%.1fs)", t1))

// 3. a_check с ts=1 — история / failed=1?
section("a_check ts=1 wait=1")
let (old, _) = try await get("\(srv.server)?act=a_check&key=\(srv.key)&ts=1&wait=1")
print(String(old.prefix(3000)))

// 4. битый key — failed=2?
section("a_check key=bogus")
let (bogus, _) = try await get("\(srv.server)?act=a_check&key=bogus&ts=\(srv.ts)&wait=1")
print(bogus)

// 5. живое событие: ждём сообщение от владельца до 60 c
section("a_check live wait=25 (x5, ~110s) — напиши в сообщество")
var ts = srv.ts
for _ in 0..<5 {
    let (live, t) = try await get("\(srv.server)?act=a_check&key=\(srv.key)&ts=\(ts)&wait=25")
    print(live, String(format: "(%.1fs)", t))
    if let next = try? JSONDecoder().decode([String: AnyCodableTs].self, from: Data(live.utf8))["ts"]?.value { ts = next }
    if live.contains("message_new") { break }
}
struct AnyCodableTs: Decodable {
    let value: String
    init(from d: Decoder) throws {
        let c = try d.singleValueContainer()
        if let s = try? c.decode(String.self) { value = s } else { value = String(try c.decode(Int.self)) }
    }
}

// 6. отмена: long poll wait=25, cancel через 2 c
section("cancellation: wait=25, cancel after 2s")
let started = Date()
let task = Task { try await get("\(srv.server)?act=a_check&key=\(srv.key)&ts=\(ts)&wait=25") }
try await Task.sleep(for: .seconds(2))
task.cancel()
do {
    let (r, _) = try await task.value
    print("NOT cancelled, got response after \(String(format: "%.1f", Date().timeIntervalSince(started)))s: \(r)")
} catch {
    print("cancelled after \(String(format: "%.2f", Date().timeIntervalSince(started)))s → \(type(of: error)): \(error)")
}
