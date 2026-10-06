// ВРЕМЕННЫЙ файл эксперимента HYP-057 №2 — удалить вместе с зависимостью ConcurrencyExtras.
import Foundation
import Testing
import ConcurrencyExtras
@testable import BotBridge

/// «Наивный» тест гонки: две команды одновременно (TaskGroup), без затвора.
/// Ожидание: ровно один ответ «Уже обрабатываю». Режим задаётся env `HYP057_SERIAL=1`.
@Suite("HYP-057 эксперимент 2", .serialized, .timeLimit(.minutes(1)))
struct HYP057Experiment2Tests {
    @Test("наивная гонка: две команды одновременно")
    func naiveRace() async throws {
        if ProcessInfo.processInfo.environment["HYP057_SERIAL"] == "1" {
            await withMainSerialExecutor { await Self.race() }
        } else {
            await Self.race()
        }
    }

    static func race() async {
        let http = GatedHTTPClient()
        await http.openGate()  // без затвора: только естественные точки приостановки
        let processor = CommandProcessorConcurrencyTests.makeProcessorForExperiment(http: http)
        await withTaskGroup(of: Void.self) { group in
            group.addTask { await processor.handle(message: .owner(1, text: "/test")) }
            group.addTask { await processor.handle(message: .owner(1, text: "/test")) }
        }
        let texts = await http.sentTexts
        #expect(texts.filter { $0.contains("Уже обрабатываю") }.count == 1)
    }
}

/// Вторая сторона границы: гонка данных БЕЗ точек приостановки (check-then-act на общем флаге).
/// `HYP057_LOCK=0` — мутант без замка. Ожидание: ровно один «вошёл» из двух параллельных задач.
final class BusyFlag: @unchecked Sendable {
    private var busy = false
    private let lock = NSLock()
    private let useLock = ProcessInfo.processInfo.environment["HYP057_LOCK"] != "0"

    func tryEnter() -> Bool {
        if useLock { lock.lock() }
        defer { if useLock { lock.unlock() } }
        if busy { return false }
        var spin = 0
        for i in 0..<200_000 { spin &+= i }  // окно между проверкой и записью (без await)
        _ = spin
        busy = true
        return true
    }
}

@Suite("HYP-057 эксперимент 2b: гонка данных", .serialized, .timeLimit(.minutes(1)))
struct HYP057Experiment2bTests {
    @Test("check-then-act из двух задач — входит ровно одна")
    func dataRace() async {
        if ProcessInfo.processInfo.environment["HYP057_SERIAL"] == "1" {
            await withMainSerialExecutor { await Self.race() }
        } else {
            await Self.race()
        }
    }

    static func race() async {
        let flag = BusyFlag()
        let entered = await withTaskGroup(of: Bool.self) { group in
            group.addTask { flag.tryEnter() }
            group.addTask { flag.tryEnter() }
            return await group.reduce(0) { $0 + ($1 ? 1 : 0) }
        }
        #expect(entered == 1)
    }
}
