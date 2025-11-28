import TgClientModels
import TGClientInterfaces
import Foundation
import Testing
@testable import TDLibAdapter
@testable import TestHelpers

/// Unit-тесты для MockTDLibFFI — mock FFI слоя для тестирования.
///
/// **Фокус:** send() генерирует уникальный @extra и добавляет в response (как реальный TDLib).
@Suite("Unit: MockTDLibFFI - @extra generation")
struct MockTDLibFFITests {

    /// send() генерирует @extra и возвращает его.
    ///
    /// **Given:** MockTDLibFFI с замоканным response
    /// **When:** send() вызывается с request БЕЗ @extra
    /// **Then:** send() возвращает сгенерированный @extra, response содержит его
    @Test("send() генерирует @extra и возвращает его")
    func sendReturnsGeneratedExtra() throws {
        let mockFFI = MockTDLibFFI()

        let chatResponse = ChatResponse(
            id: 12345,
            type: .`private`(userId: 100),
            title: "Test Chat",
            unreadCount: 0,
            lastReadInboxMessageId: 0
        )
        mockFFI.mockResponse(forRequestType: "getChat", return: .success(chatResponse))

        // Отправляем request БЕЗ @extra — send() должен сгенерировать его
        let request = GetChatRequest(chatId: 12345)
        let requestJSON = try request.toTDLibJSON()  // БЕЗ extra
        let generatedExtra = mockFFI.send(requestJSON)

        // send() должен вернуть непустой @extra
        #expect(!generatedExtra.isEmpty)

        // Получаем response
        let responseString = mockFFI.receive(timeout: 1.0)
        #expect(responseString != nil)

        let data = responseString!.data(using: .utf8)!
        let parsed = try JSONSerialization.jsonObject(with: data) as! [String: Any]

        // Response содержит сгенерированный @extra
        let extra = parsed["@extra"] as? String
        #expect(extra == generatedExtra)
    }

    /// send() генерирует УНИКАЛЬНЫЕ @extra для каждого вызова.
    ///
    /// **Given:** MockTDLibFFI с несколькими замоканными responses
    /// **When:** несколько последовательных send() вызовов
    /// **Then:** каждый возвращает уникальный @extra
    @Test("send() генерирует уникальные @extra для каждого вызова")
    func sendGeneratesUniqueExtras() throws {
        let mockFFI = MockTDLibFFI()

        // Мокаем 3 response для getChat
        for _ in 0..<3 {
            let chatResponse = ChatResponse(
                id: 12345,
                type: .`private`(userId: 100),
                title: "Test Chat",
                unreadCount: 0,
                lastReadInboxMessageId: 0
            )
            mockFFI.mockResponse(forRequestType: "getChat", return: .success(chatResponse))
        }

        var generatedExtras: Set<String> = []

        // 3 последовательных вызова send()
        for _ in 0..<3 {
            let request = GetChatRequest(chatId: 12345)
            let requestJSON = try request.toTDLibJSON()
            let extra = mockFFI.send(requestJSON)
            generatedExtras.insert(extra)
        }

        // Все @extra должны быть уникальными
        #expect(generatedExtras.count == 3)
    }

    /// send() добавляет сгенерированный @extra в error response.
    ///
    /// **Given:** MockTDLibFFI с замоканной ошибкой
    /// **When:** send() вызывается
    /// **Then:** error response содержит сгенерированный @extra
    @Test("send() добавляет @extra в error response")
    func sendAddsExtraToErrorResponse() throws {
        let mockFFI = MockTDLibFFI()

        let error = TDLibErrorResponse(code: 404, message: "Chat not found")
        mockFFI.mockResponse(forRequestType: "getChat", return: Result<ChatResponse, TDLibErrorResponse>.failure(error))

        let request = GetChatRequest(chatId: 404)
        let requestJSON = try request.toTDLibJSON()
        let generatedExtra = mockFFI.send(requestJSON)

        #expect(!generatedExtra.isEmpty)

        let responseString = mockFFI.receive(timeout: 1.0)
        #expect(responseString != nil)

        let data = responseString!.data(using: .utf8)!
        let parsed = try JSONSerialization.jsonObject(with: data) as! [String: Any]

        // Error response содержит сгенерированный @extra
        let extra = parsed["@extra"] as? String
        #expect(extra == generatedExtra)
    }
}
