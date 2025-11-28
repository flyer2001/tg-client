import TgClientModels
import TGClientInterfaces
import Foundation
import Testing
import FoundationExtensions
import TestHelpers
@testable import TDLibAdapter

/// Тесты для декодирования OkResponse.
///
/// **TDLib API:** https://core.telegram.org/tdlib/docs/classtd_1_1td__api_1_1ok.html
///
/// Ok - универсальный успешный ответ без дополнительных данных.
/// Используется методами которые не возвращают конкретных данных.
/// Подробнее см. документацию TDLib.
///
/// **Структура ответа:**
/// ```json
/// {
///   "@type": "ok"
/// }
/// ```
@Suite("Декодирование OkResponse")
struct OkResponseTests {

    @Test("Декодирование Ok ответа")
    func decodeOkResponse() throws {
        let json = """
        {
            "@type": "ok"
        }
        """

        let data = Data(json.utf8)
        let decoder = JSONDecoder.tdlib()
        let response = try decoder.decode(OkResponse.self, from: data)

        // Проверяем что @type включен в encoded JSON (критично для TDLibClient routing)
        try response.assertValidEncoding()

        #expect(response.type == "ok")
    }
}
