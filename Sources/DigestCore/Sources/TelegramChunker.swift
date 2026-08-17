import Foundation

/// Режет человекочитаемый документ на сообщения под лимит Telegram (4096 символов).
///
/// **Формат документа:** блоки разделены строкой, состоящей из `===`.
/// Блок = одно сообщение. Блок длиннее лимита режется по границам строк,
/// строка длиннее лимита — жёстко по символам (ничего не теряем).
///
/// - Parameters:
///   - document: исходный текст
///   - maxLength: лимит одного сообщения (Telegram: 4096; берём с запасом)
/// - Returns: сообщения в исходном порядке, без пустых
public func splitIntoTelegramChunks(document: String, maxLength: Int = 4000) -> [String] {
    precondition(maxLength > 0)

    let blocks = document
        .components(separatedBy: "\n===\n")
        .flatMap { $0.components(separatedBy: "\n===") }
        .flatMap { $0.components(separatedBy: "===\n") }
        .map { $0 == "===" ? "" : $0 }

    var chunks: [String] = []
    for block in blocks {
        let trimmed = block.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { continue }
        if trimmed.count <= maxLength {
            chunks.append(trimmed)
            continue
        }

        // Блок не влезает — копим строки до лимита
        var current = ""
        for line in trimmed.components(separatedBy: "\n") {
            var line = line
            // Строка сама длиннее лимита — жёсткая нарезка
            while line.count > maxLength {
                if !current.isEmpty {
                    chunks.append(current)
                    current = ""
                }
                chunks.append(String(line.prefix(maxLength)))
                line = String(line.dropFirst(maxLength))
            }
            let candidate = current.isEmpty ? line : current + "\n" + line
            if candidate.count > maxLength {
                chunks.append(current)
                current = line
            } else {
                current = candidate
            }
        }
        if !current.isEmpty { chunks.append(current) }
    }
    return chunks
}
