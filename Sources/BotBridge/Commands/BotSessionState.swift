import Foundation
import TgClientModels

/// Хранит состояние между командами в рамках одного процесса.
///
/// **Текущее состояние:** последнее меню (нумерация → чат). Используется в `/get N`.
///
/// **Reset:** меню перезаписывается при каждом `/digest`. Сбрасывается при рестарте сервиса.
public actor BotSessionState {
    private var lastMenu: [Int: UnreadChatInfo] = [:]

    public init() {}

    /// Запоминает меню. Возвращает то же содержимое с проставленной нумерацией (1-based).
    @discardableResult
    public func recordMenu(_ chats: [UnreadChatInfo]) -> [(index: Int, chat: UnreadChatInfo)] {
        lastMenu.removeAll(keepingCapacity: true)
        var indexed: [(Int, UnreadChatInfo)] = []
        for (offset, chat) in chats.enumerated() {
            let index = offset + 1
            lastMenu[index] = chat
            indexed.append((index, chat))
        }
        return indexed
    }

    public func resolve(index: Int) -> UnreadChatInfo? {
        return lastMenu[index]
    }

    public func resolveAll() -> [UnreadChatInfo] {
        return lastMenu.keys.sorted().compactMap { lastMenu[$0] }
    }

    public func resolveByKind(_ kind: ChatKind) -> [UnreadChatInfo] {
        return lastMenu.keys.sorted().compactMap { lastMenu[$0] }.filter { $0.kind == kind }
    }

    public var isEmpty: Bool {
        return lastMenu.isEmpty
    }
}
