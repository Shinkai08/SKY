import Foundation

/// Lenient JSON reader: missing keys read as 0 / "" / false, numbers may arrive as strings.
struct JSON {
    let raw: Any?
    init(_ raw: Any?) { self.raw = raw is NSNull ? nil : raw }
    init(data: Data) { self.init(try? JSONSerialization.jsonObject(with: data, options: [.fragmentsAllowed])) }

    subscript(key: String) -> JSON { JSON((raw as? [String: Any])?[key]) }
    subscript(index: Int) -> JSON {
        guard let a = raw as? [Any], index >= 0, index < a.count else { return JSON(nil) }
        return JSON(a[index])
    }
    var exists: Bool { raw != nil }
    var double: Double {
        if let n = raw as? NSNumber { return n.doubleValue }
        if let s = raw as? String { return Double(s) ?? 0 }
        return 0
    }
    var doubleOrNil: Double? {
        if let n = raw as? NSNumber { return n.doubleValue }
        if let s = raw as? String { return Double(s) }
        return nil
    }
    var int: Int { Int(double) }
    var string: String {
        if let s = raw as? String { return s }
        if let n = raw as? NSNumber { return n.stringValue }
        return ""
    }
    var stringOrNil: String? { raw as? String }
    var bool: Bool {
        if let b = raw as? Bool { return b }
        if let n = raw as? NSNumber { return n.intValue != 0 }
        return false
    }
    var array: [JSON] { (raw as? [Any])?.map { JSON($0) } ?? [] }
    var dict: [String: JSON] {
        var out: [String: JSON] = [:]
        for (k, v) in (raw as? [String: Any]) ?? [:] { out[k] = JSON(v) }
        return out
    }
}

struct APIError: Error {
    let status: Int
    let code: String
}

/// skyd client. Logins use the same HttpOnly `sky_session` cookie as the website;
/// iOS keeps it in the shared cookie store.
final class API {
    static let shared = API()
    static let site = URL(string: "https://sky.shinkaicc.com")!

    let session: URLSession

    private init() {
        let cfg = URLSessionConfiguration.default
        cfg.httpCookieStorage = HTTPCookieStorage.shared
        cfg.httpShouldSetCookies = true
        cfg.httpCookieAcceptPolicy = .always
        cfg.timeoutIntervalForRequest = 15
        if Demo.on { cfg.protocolClasses = [DemoProtocol.self] + (cfg.protocolClasses ?? []) }
        session = URLSession(configuration: cfg)
    }

    func url(_ path: String) -> URL {
        URL(string: "/api/v1" + path, relativeTo: API.site)!.absoluteURL
    }

    func get(_ path: String) async throws -> JSON {
        try await send(URLRequest(url: url(path)))
    }

    func post(_ path: String, _ body: [String: Any] = [:], method: String = "POST") async throws -> JSON {
        var req = URLRequest(url: url(path))
        req.httpMethod = method
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try? JSONSerialization.data(withJSONObject: body)
        return try await send(req)
    }

    func upload(_ path: String, data: Data, contentType: String) async throws -> JSON {
        var req = URLRequest(url: url(path))
        req.httpMethod = "POST"
        req.setValue(contentType, forHTTPHeaderField: "Content-Type")
        req.httpBody = data
        return try await send(req)
    }

    /// Any absolute URL (Binance public data).
    func fetch(_ absolute: String) async throws -> JSON {
        guard let u = URL(string: absolute) else { throw APIError(status: 0, code: "bad_url") }
        return try await send(URLRequest(url: u))
    }

    private func send(_ req: URLRequest) async throws -> JSON {
        let data: Data
        let resp: URLResponse
        do {
            (data, resp) = try await session.data(for: req)
        } catch {
            throw APIError(status: 0, code: "service_unavailable")
        }
        let status = (resp as? HTTPURLResponse)?.statusCode ?? 0
        let json = JSON(data: data)
        if !(200..<300).contains(status) {
            let code = json["error"].string
            throw APIError(status: status, code: code.isEmpty ? "http_\(status)" : code)
        }
        return json
    }

    /// Absolute URL for a server path such as an uploaded avatar ("/api/v1/avatars/…").
    static func asset(_ path: String) -> URL? {
        if path.hasPrefix("http") { return URL(string: path) }
        return URL(string: path, relativeTo: site)?.absoluteURL
    }
}

// MARK: - Demo mode (screenshots in CI): every request is answered from bundled fixtures.

enum Demo {
    static let on = ProcessInfo.processInfo.arguments.contains("-demo")

    static func arg(_ name: String) -> String? {
        let a = ProcessInfo.processInfo.arguments
        guard let i = a.firstIndex(of: name), i + 1 < a.count else { return nil }
        return a[i + 1]
    }

    /// Fixture file for a URL; scripts/record-demo.mjs writes files with the same names.
    static func key(_ url: URL) -> String {
        var s = ""
        if url.host != API.site.host { s += (url.host ?? "") + "_" }
        s += url.path
        if let q = url.query, !q.isEmpty { s += "_" + q }
        let mapped = s.map { ch -> Character in (ch.isLetter && ch.isASCII) || (ch.isNumber && ch.isASCII) ? ch : "_" }
        return String(String(mapped).prefix(150))
    }
}

final class DemoProtocol: URLProtocol {
    override class func canInit(with request: URLRequest) -> Bool { Demo.on }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        guard let url = request.url else { return }
        var status = 200
        var body = Data("{\"ok\":true}".utf8)
        let args = ProcessInfo.processInfo.arguments
        if args.contains("-loggedout") && (url.path == "/api/v1/me" || url.path == "/api/v1/account") {
            status = 401; body = Data("{\"error\":\"unauthorized\"}".utf8)
        } else if url.path == "/api/v1/app/version" && !args.contains("-update") {
            body = Data("{\"enabled\":false}".utf8)
        } else if request.httpMethod == nil || request.httpMethod == "GET" {
            var bare = URLComponents(url: url, resolvingAgainstBaseURL: false)
            bare?.query = nil
            let names = [Demo.key(url), bare?.url.map(Demo.key) ?? ""]
            if let f = names.lazy.compactMap({ Bundle.main.url(forResource: $0, withExtension: "json", subdirectory: "Demo") }).first,
               let d = try? Data(contentsOf: f) {
                body = d
            } else if url.path.hasSuffix(".png") || url.path.hasSuffix(".jpg") || url.path.hasSuffix(".webp") {
                status = 404; body = Data()
            } else {
                status = 404; body = Data("{\"error\":\"not_found\"}".utf8)
            }
        }
        let resp = HTTPURLResponse(url: url, statusCode: status, httpVersion: "HTTP/1.1",
                                   headerFields: ["Content-Type": "application/json"])!
        client?.urlProtocol(self, didReceive: resp, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: body)
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}
