import Foundation

// Binance public market data (market/binance.ts). Display feed only.
enum Binance {
    static let spotREST = "https://data-api.binance.vision"
    static let perpREST = "https://fapi.binance.com"
    static let spotWS = "wss://data-stream.binance.vision/stream"
    static let perpWS = "wss://fstream.binance.com/stream"

    /// Today's tickers (trading day from 00:00 UTC+8).
    static func tradingDay(_ symbols: [String]) async -> [String: Ticker] {
        let list = "[" + symbols.map { "\"\($0)\"" }.joined(separator: ",") + "]"
        let q = list.addingPercentEncoding(withAllowedCharacters: .alphanumerics) ?? ""
        guard let rows = try? await API.shared.fetch("\(spotREST)/api/v3/ticker/tradingDay?symbols=\(q)&timeZone=8") else { return [:] }
        var out: [String: Ticker] = [:]
        for r in rows.array { let t = Ticker(r); out[t.sym] = t }
        return out
    }

    static func perpTicker(_ symbol: String) async -> Ticker? {
        guard let r = try? await API.shared.fetch("\(perpREST)/fapi/v1/ticker/24hr?symbol=\(symbol)") else { return nil }
        return Ticker(r)
    }

    static func klines(_ symbol: String, _ interval: String, _ limit: Int, perp: Bool = false) async -> [Candle] {
        let base = perp ? "\(perpREST)/fapi/v1/klines" : "\(spotREST)/api/v3/klines"
        guard let rows = try? await API.shared.fetch("\(base)?symbol=\(symbol)&interval=\(interval)&limit=\(limit)") else { return [] }
        return rows.array.map { Candle(t: $0[0].double, o: $0[1].double, h: $0[2].double, l: $0[3].double, c: $0[4].double, v: $0[5].double) }
    }

    /// Milliseconds until the next 00:00 UTC+8.
    static func msToNextDayUTC8() -> Double {
        let now = Date().timeIntervalSince1970 * 1000
        let day = 86_400_000.0, shift = 8 * 3_600_000.0
        return day - (now + shift).truncatingRemainder(dividingBy: day)
    }
}

/// Combined-stream WebSocket with backoff reconnect (binance.ts stream()).
final class WSStream {
    private let base: String
    private let streams: [String]
    private let onMsg: (String, JSON) -> Void
    private var task: URLSessionWebSocketTask?
    private var closed = false
    private var retry = 0

    init(_ base: String, _ streams: [String], onMsg: @escaping (String, JSON) -> Void) {
        self.base = base; self.streams = streams; self.onMsg = onMsg
        if !Demo.on { connect() }
    }

    private func connect() {
        guard !closed, let url = URL(string: "\(base)?streams=\(streams.joined(separator: "/"))") else { return }
        let t = URLSession.shared.webSocketTask(with: url)
        task = t
        t.resume()
        receive(t)
    }

    private func receive(_ t: URLSessionWebSocketTask) {
        t.receive { [weak self] result in
            guard let self, !self.closed else { return }
            switch result {
            case .success(let msg):
                self.retry = 0
                var data: Data?
                switch msg {
                case .string(let s): data = s.data(using: .utf8)
                case .data(let d): data = d
                @unknown default: data = nil
                }
                if let data {
                    let j = JSON(data: data)
                    let name = j["stream"].string
                    let payload = j["data"]
                    DispatchQueue.main.async { self.onMsg(name, payload) }
                }
                self.receive(t)
            case .failure:
                let delay = min(30.0, pow(2.0, Double(self.retry)))
                self.retry += 1
                DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in self?.connect() }
            }
        }
    }

    func close() {
        closed = true
        task?.cancel(with: .goingAway, reason: nil)
    }

    deinit { close() }
}

/// Live spot tickers for a fixed symbol list (hooks.ts useSpotTickers).
@MainActor
@Observable
final class SpotTickers {
    var tickers: [String: Ticker] = [:]
    var state = "loading"
    @ObservationIgnored private var ws: WSStream?
    @ObservationIgnored private let symbols: [String]

    init(_ symbols: [String]) { self.symbols = symbols }

    func start() async {
        let t = await Binance.tradingDay(symbols)
        if !t.isEmpty { tickers = t; state = "live" } else if tickers.isEmpty { state = "offline" }
        guard ws == nil else { return }
        ws = WSStream(Binance.spotWS, symbols.map { "\($0.lowercased())@miniTicker" }) { [weak self] _, d in
            guard let self else { return }
            let sym = d["s"].string
            guard var day = self.tickers[sym] else { return }
            let price = d["c"].double
            day.price = price
            day.chg = day.open > 0 ? (price - day.open) / day.open * 100 : 0
            day.high = max(day.high, price)
            day.low = min(day.low, price)
            self.tickers[sym] = day
        }
    }

    func stop() { ws?.close(); ws = nil }
}

/// Static market metadata with demo fallbacks (data.ts MARKETS).
struct MarketMeta {
    let sym: String, name: String
    var price: Double, chg: Double, vol: Double
    static let all: [MarketMeta] = [
        MarketMeta(sym: "BTC", name: "Bitcoin", price: 68432.8, chg: 2.34, vol: 24.86e9),
        MarketMeta(sym: "ETH", name: "Ethereum", price: 3542.16, chg: 1.87, vol: 12.42e9),
        MarketMeta(sym: "SOL", name: "Solana", price: 162.38, chg: -0.91, vol: 3.18e9),
        MarketMeta(sym: "XRP", name: "XRP", price: 0.5248, chg: 0.68, vol: 1.06e9),
        MarketMeta(sym: "DOGE", name: "Dogecoin", price: 0.1426, chg: -1.24, vol: 842.31e6),
        MarketMeta(sym: "AVAX", name: "Avalanche", price: 28.64, chg: 3.12, vol: 416.82e6),
        MarketMeta(sym: "LINK", name: "Chainlink", price: 14.82, chg: 1.42, vol: 328.64e6),
    ]
    static var spotSymbols: [String] { all.map { $0.sym + "USDT" } }

    /// live.ts liveMarkets(): overlay live tickers.
    static func live(_ tickers: [String: Ticker]) -> [MarketMeta] {
        all.map { m in
            guard let t = tickers[m.sym + "USDT"] else { return m }
            var x = m; x.price = t.price; x.chg = t.chg; x.vol = t.quoteVol
            return x
        }
    }
}
