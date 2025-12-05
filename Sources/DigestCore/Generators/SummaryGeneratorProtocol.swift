import Foundation
import TgClientModels

/// Протокол для генерации AI-саммари из сообщений.
///
/// Абстракция для смены провайдеров AI (OpenAI, Claude, локальные LLM).
public protocol SummaryGeneratorProtocol: Sendable {
    /// Генерирует AI-саммари из массива сообщений.
    ///
    /// - Parameter messages: Массив сообщений из источников (каналы/группы)
    /// - Returns: Дайджест в формате Telegram MarkdownV2 (≤ 4096 символов)
    /// - Throws: Ошибки API или сети
    func generate(messages: [SourceMessage]) async throws -> String
}
