import TGClientInterfaces
import Foundation

/// Прокси для сетевых запросов TDLib: SOCKS5 или HTTP CONNECT.
///
/// Нужен там, где дата-центры Telegram недоступны напрямую (Россия).
/// Задаётся `TDLIB_PROXY=socks5://[user:pass@]host:port` или `http://[user:pass@]host:port`.
///
/// **TDLib API:** `proxy server:string port:int32 type:ProxyType`;
/// `proxyTypeSocks5 username password`, `proxyTypeHttp username password http_only` (`http_only=false` — CONNECT).
public struct TDProxy: Sendable, Equatable, Encodable {
    public enum Kind: String, Sendable {
        case socks5
        case http
    }

    public let server: String
    public let port: Int32
    public let username: String
    public let password: String
    public let kind: Kind

    public init(server: String, port: Int32, username: String = "", password: String = "", kind: Kind = .socks5) {
        self.server = server
        self.port = port
        self.username = username
        self.password = password
        self.kind = kind
    }

    /// Разбор `socks5://` / `http://[user:pass@]host:port`; другие схемы и адрес без порта — `nil`.
    public init?(url: String) {
        guard let components = URLComponents(string: url), let kind = components.scheme.flatMap(Kind.init(rawValue:)),
              let host = components.host, !host.isEmpty, let port = components.port else { return nil }
        self.init(server: host, port: Int32(port), username: components.user ?? "", password: components.password ?? "", kind: kind)
    }

    /// Для логов: схема, хост и порт — без логина и пароля.
    public var logDescription: String { "\(kind.rawValue) \(server):\(port)" }

    private enum CodingKeys: String, CodingKey {
        case type = "@type", server, port
        case proxyType = "type"
    }

    private enum TypeKeys: String, CodingKey {
        case type = "@type", username, password
        case httpOnly = "http_only"
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode("proxy", forKey: .type)
        try container.encode(server, forKey: .server)
        try container.encode(port, forKey: .port)
        var type = container.nestedContainer(keyedBy: TypeKeys.self, forKey: .proxyType)
        try type.encode(username, forKey: .username)
        try type.encode(password, forKey: .password)
        switch kind {
        case .socks5:
            try type.encode("proxyTypeSocks5", forKey: .type)
        case .http:
            try type.encode("proxyTypeHttp", forKey: .type)
            try type.encode(false, forKey: .httpOnly)  // CONNECT-туннель: TDLib нужен TCP, не HTTP-запросы
        }
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
