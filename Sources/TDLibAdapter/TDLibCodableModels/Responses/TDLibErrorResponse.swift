import Foundation

public struct TDLibErrorResponse: TDLibResponse, Error, Sendable {
    public let type = "error"
    public let code: Int
    public let message: String

    enum CodingKeys: String, CodingKey {
        case code
        case message
    }

    #if DEBUG
    public init(code: Int, message: String) {
        self.code = code
        self.message = message
    }
    #endif
}
