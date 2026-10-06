import TGClientInterfaces
import Foundation

/// SOCKS5-прокси для сетевых запросов TDLib.
///
/// Нужен там, где дата-центры Telegram недоступны напрямую (Россия). Задаётся `TDLIB_PROXY=socks5://[user:pass@]host:port`.
///
/// **TDLib API:** `proxy server:string port:int32 type:ProxyType`, `proxyTypeSocks5 username:string password:string`
public struct TDProxy: Sendable, Equatable, Encodable {
    public let server: String
    public let port: Int32
    public let username: String
    public let password: String

    public init(server: String, port: Int32, username: String = "", password: String = "") {
        self.server = server
        self.port = port
        self.username = username
        self.password = password
    }

    /// Разбор `socks5://[user:pass@]host:port`; другие схемы и адрес без порта — `nil`.
    public init?(url: String) {
        guard let components = URLComponents(string: url), components.scheme == "socks5",
              let host = components.host, !host.isEmpty, let port = components.port else { return nil }
        self.init(server: host, port: Int32(port), username: components.user ?? "", password: components.password ?? "")
    }

    private enum CodingKeys: String, CodingKey {
        case type = "@type", server, port
        case proxyType = "type"
    }

    private enum Socks5Keys: String, CodingKey {
        case type = "@type", username, password
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode("proxy", forKey: .type)
        try container.encode(server, forKey: .server)
        try container.encode(port, forKey: .port)
        var socks5 = container.nestedContainer(keyedBy: Socks5Keys.self, forKey: .proxyType)
        try socks5.encode("proxyTypeSocks5", forKey: .type)
        try socks5.encode(username, forKey: .username)
        try socks5.encode(password, forKey: .password)
    }
}

/// Запрос `addProxy` — добавить (и сразу включить) прокси. Можно вызывать до авторизации.
///
/// **TDLib API (1.8.67):** `addProxy proxy:proxy enable:Bool comment:string = AddedProxy`
/// https://core.telegram.org/tdlib/docs/classtd_1_1td__api_1_1add_proxy.html
public struct AddProxyRequest: TDLibRequest {
    public let type = "addProxy"
    public let proxy: TDProxy
    public let enable: Bool
    public let comment: String

    enum CodingKeys: String, CodingKey {
        case type = "@type", proxy, enable, comment
    }

    public init(proxy: TDProxy, enable: Bool = true, comment: String = "tg-client") {
        self.proxy = proxy
        self.enable = enable
        self.comment = comment
    }
}
