import TgClientModels
import TGClientInterfaces
import Foundation
import Logging
import Testing
@testable import DigestCore

/// Unit-тесты для полной выгрузки истории чата в JSONL.
///
/// **Scope:** пагинация до самого первого сообщения, дедупликация, формат строки.
@Suite("Unit: ChatHistoryDumper")
struct ChatHistoryDumperTests {

    private static func noopLogger() -> Logger {
        Logger(label: "test") { _ in SwiftLogNoOpLogHandler() }
    }

    private static func tempURL() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("dump-\(UUID().uuidString).jsonl")
    }

    private static func message(id: Int64, date: Int32, text: String?) -> Message {
        Message(
            id: id,
            chatId: 42,
            date: date,
            content: text.map { .text(FormattedText(text: $0, entities: nil)) } ?? .unsupported,
            senderId: 7,
            isOutgoing: id % 2 == 0
        )
    }

    /// Пагинация идёт до пустого ответа, а не до фиксированного лимита попыток.
    ///
    /// **Given:** 250 сообщений, страница = 100 (3 полных запроса + пустой)
    /// **When:** dumpChatHistory()
    /// **Then:** выгружены все 250, диапазон дат от первого до последнего
    @Test("Пагинация до самого первого сообщения")
    func paginatesToBeginning() async throws {
        let url = Self.tempURL()
        defer { try? FileManager.default.removeItem(at: url) }

        // newest-first, id 250...1
        let all = (1...250).reversed().map { Self.message(id: Int64($0), date: Int32(1_700_000_000 + $0), text: "m\($0)") }

        let stats = try await dumpChatHistory(
            chatId: 42,
            to: url,
            pageSize: 100,
            logger: Self.noopLogger()
        ) { fromMessageId, limit in
            let startIndex: Int
            if fromMessageId == 0 {
                startIndex = 0
            } else if let idx = all.firstIndex(where: { $0.id == fromMessageId }) {
                startIndex = idx + 1
            } else {
                return []
            }
            guard startIndex < all.count else { return [] }
            return Array(all[startIndex..<min(startIndex + Int(limit), all.count)])
        }

        #expect(stats.messageCount == 250)
        #expect(stats.textCount == 250)
        #expect(stats.pages == 4)
        #expect(stats.oldestDate == 1_700_000_001)
        #expect(stats.newestDate == 1_700_000_250)

        let lines = try String(contentsOf: url, encoding: .utf8)
            .split(separator: "\n", omittingEmptySubsequences: true)
        #expect(lines.count == 250)
    }

    /// Дедупликация: TDLib может отдать пересекающиеся страницы — цикл не должен зациклиться.
    @Test("Повтор той же страницы останавливает цикл")
    func stopsOnDuplicatePage() async throws {
        let url = Self.tempURL()
        defer { try? FileManager.default.removeItem(at: url) }

        let page = [Self.message(id: 2, date: 100, text: "b"), Self.message(id: 1, date: 99, text: "a")]

        let stats = try await dumpChatHistory(
            chatId: 42,
            to: url,
            pageSize: 100,
            logger: Self.noopLogger()
        ) { _, _ in page }

        #expect(stats.messageCount == 2)
        #expect(stats.pages == 2)
    }

    /// Нетекстовые сообщения не выбрасываются, а пишутся плейсхолдером.
    @Test("Нетекстовое сообщение попадает в выгрузку как type=other")
    func keepsNonTextMessages() async throws {
        let url = Self.tempURL()
        defer { try? FileManager.default.removeItem(at: url) }

        let page = [
            Self.message(id: 2, date: 100, text: nil),
            Self.message(id: 1, date: 99, text: "привет"),
        ]
        var served = false

        let stats = try await dumpChatHistory(
            chatId: 42,
            to: url,
            pageSize: 100,
            logger: Self.noopLogger()
        ) { _, _ in
            defer { served = true }
            return served ? [] : page
        }

        #expect(stats.messageCount == 2)
        #expect(stats.textCount == 1)
        #expect(stats.otherCount == 1)

        let lines = try String(contentsOf: url, encoding: .utf8)
            .split(separator: "\n", omittingEmptySubsequences: true)
        #expect(lines.count == 2)
        #expect(lines[0].contains("\"type\":\"other\""))
        #expect(lines[1].contains("\"type\":\"text\""))
        #expect(lines[1].contains("\"is_outgoing\":false"))
    }
}
