import TgClientModels
import TGClientInterfaces
import Testing
import Foundation
import TDLibAdapter

/// Unit-тесты `AddProxyRequest` и разбора `TDProxy` из строки `TDLIB_PROXY`.
///
/// ## Зачем
///
/// Из России TDLib не достучаться до дата-центров Telegram напрямую (замер 2026-10-06, ubuntu-home:
/// все DC на :443 не отвечают). TDLib не читает `HTTP(S)_PROXY` — прокси задаётся явно методом `addProxy`.
///
/// ## Связь с TDLib API (схема 1.8.67, `td/generate/scheme/td_api.tl`)
///
/// ```
/// addProxy proxy:proxy enable:Bool comment:string = AddedProxy;   // «Can be called before authorization»
/// proxy server:string port:int32 type:ProxyType = Proxy;
/// proxyTypeSocks5 username:string password:string = ProxyType;
/// ```
///
/// ⚠️ В старых версиях TDLib сигнатура была плоской: `addProxy server port enable type` — Research-First поймал смену.
///
/// **Документация TDLib:** https://core.telegram.org/tdlib/docs/classtd_1_1td__api_1_1add_proxy.html
@Suite("AddProxyRequest и TDProxy")
struct AddProxyRequestTests {

    let encoder = TDLibRequestEncoder()

    /// `proxy` — вложенный объект `{@type: proxy, server, port, type: proxyTypeSocks5}`.
    @Test("Encode AddProxyRequest — SOCKS5 по схеме TDLib 1.8.67")
    func encodeSocks5() throws {
        let request = AddProxyRequest(proxy: TDProxy(server: "127.0.0.1", port: 1080), enable: true, comment: "tg-client")

        let json = try JSONSerialization.jsonObject(with: try encoder.encode(request)) as? [String: Any]
        let proxy = json?["proxy"] as? [String: Any]
        let type = proxy?["type"] as? [String: Any]

        #expect(json?["@type"] as? String == "addProxy")
        #expect(json?["enable"] as? Bool == true)
        #expect(json?["comment"] as? String == "tg-client")
        #expect(proxy?["@type"] as? String == "proxy")
        #expect(proxy?["server"] as? String == "127.0.0.1")
        #expect(proxy?["port"] as? Int == 1080)
        #expect(type?["@type"] as? String == "proxyTypeSocks5")
        #expect(type?["username"] as? String == "")
        #expect(type?["password"] as? String == "")
    }

    @Test("TDProxy из socks5://host:port")
    func parseHostPort() {
        let proxy = TDProxy(url: "socks5://127.0.0.1:1080")
        #expect(proxy == TDProxy(server: "127.0.0.1", port: 1080))
    }

    @Test("TDProxy из socks5://user:pass@host:port")
    func parseCredentials() {
        let proxy = TDProxy(url: "socks5://bob:secret@proxy.example.com:1080")
        #expect(proxy == TDProxy(server: "proxy.example.com", port: 1080, username: "bob", password: "secret"))
    }

    @Test("TDProxy: не socks5 или без порта → nil")
    func parseInvalid() {
        #expect(TDProxy(url: "http://127.0.0.1:8080") == nil)
        #expect(TDProxy(url: "socks5://127.0.0.1") == nil)
        #expect(TDProxy(url: "") == nil)
    }
}
