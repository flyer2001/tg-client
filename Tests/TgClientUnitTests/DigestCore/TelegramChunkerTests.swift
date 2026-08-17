import Foundation
import Testing
@testable import DigestCore

/// Unit-тесты для нарезки документа на Telegram-сообщения.
@Suite("Unit: TelegramChunker")
struct TelegramChunkerTests {

    /// Блоки разделены строкой `===`; короткие блоки идут как есть, по одному сообщению.
    @Test("Блоки через === → отдельные сообщения")
    func splitsByDelimiter() {
        let doc = "блок один\nстрока два\n===\nблок два\n===\nблок три"
        let chunks = splitIntoTelegramChunks(document: doc, maxLength: 4000)
        #expect(chunks == ["блок один\nстрока два", "блок два", "блок три"])
    }

    /// Блок длиннее лимита режется по границам строк.
    @Test("Длинный блок режется по строкам под лимит")
    func splitsLongBlockByLines() {
        let lines = (1...10).map { "строка \($0) " + String(repeating: "x", count: 50) }
        let doc = lines.joined(separator: "\n")
        let chunks = splitIntoTelegramChunks(document: doc, maxLength: 200)

        #expect(chunks.count > 1)
        #expect(chunks.allSatisfy { $0.count <= 200 })
        // Ничего не потеряли
        #expect(chunks.joined(separator: "\n") == doc)
    }

    /// Одна строка длиннее лимита — жёсткая нарезка по символам, без потерь.
    @Test("Строка длиннее лимита режется жёстко")
    func splitsOversizedLine() {
        let doc = String(repeating: "а", count: 450)
        let chunks = splitIntoTelegramChunks(document: doc, maxLength: 200)
        #expect(chunks.count == 3)
        #expect(chunks.joined() == doc)
    }

    /// Пустые блоки и лишние пустые строки не создают пустых сообщений.
    @Test("Пустые блоки пропускаются")
    func skipsEmptyBlocks() {
        let doc = "===\n\nпервый\n===\n   \n===\nвторой\n"
        let chunks = splitIntoTelegramChunks(document: doc, maxLength: 4000)
        #expect(chunks == ["первый", "второй"])
    }

    /// "===" как подстрока внутри текста — НЕ разделитель; делит только строка ровно "===".
    @Test("=== внутри строки не режет блок")
    func keepsInlineDelimiterText() {
        let doc = "=== ЗАГРУЗКА ЗАВЕРШЕНА ===\nПодтверди приём.\n===\nвторой блок"
        let chunks = splitIntoTelegramChunks(document: doc, maxLength: 4000)
        #expect(chunks == ["=== ЗАГРУЗКА ЗАВЕРШЕНА ===\nПодтверди приём.", "второй блок"])
    }
}
