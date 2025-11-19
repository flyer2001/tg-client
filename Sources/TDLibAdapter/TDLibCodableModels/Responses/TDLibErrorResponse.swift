import Foundation

public struct TDLibErrorResponse: TDLibResponse, Error, Sendable {
    public let type = "error"
    public let code: Int
    public let message: String

    enum CodingKeys: String, CodingKey {
        case code
        case message
    }

    /// Создаёт ошибку TDLib программно.
    ///
    /// Используется:
    /// - В background loop для resume waiter с ошибкой
    /// - В тестах для создания mock ошибок
    init(code: Int, message: String) {
        self.code = code
        self.message = message
    }

    #if DEBUG
    /// Helper для тестов: создать ошибку 404 (все чаты загружены)
    public static func allChatsLoaded() -> TDLibErrorResponse {
        TDLibErrorResponse(code: 404, message: "Not Found")
    }
    #endif
}

// MARK: - Business Logic Helpers

extension TDLibErrorResponse {
    /// Все чаты уже загружены (TDLib вернул 404).
    public var isAllChatsLoaded: Bool {
        code == 404
    }
}
