import Foundation

// skyd / Binance payloads (same shapes the website reads in market/sky.ts etc.).

struct Me: Equatable {
    var id: Int
    var email: String
    var role: String
    var created: String
    init(_ j: JSON) { id = j["id"].int; email = j["email"].string; role = j["role"].string; created = j["created"].string }
    var admin: Bool { role == "admin" }
}

struct Author: Equatable {
    var id: Int
    var nick: String
    var avatar: String
    var frame: String
    var photo: String
    var ai: Bool
    var verified: Bool
    init(_ j: JSON) {
        id = j["id"].int; nick = j["nick"].string; avatar = j["avatar"].string; frame = j["frame"].string
        photo = j["photo"].string; ai = j["ai"].bool; verified = j["verified"].bool
    }
    init(id: Int = 0, nick: String, avatar: String = "", frame: String = "", photo: String = "") {
        self.id = id; self.nick = nick; self.avatar = avatar; self.frame = frame; self.photo = photo; ai = false; verified = false
    }
}

struct Position: Identifiable, Equatable {
    var id: String { sym }
    var sym: String, base: String
    var qty: Double, entry: Double, mark: Double, upnl: Double, lev: Double, margin: Double
    var isolated: Bool, liq: Double, maint: Double, priceDec: Int, qtyDec: Int
    var realized: Double?, tp: Double, sl: Double, removable: Double, maxLev: Double?
    init(_ j: JSON) {
        sym = j["sym"].string; base = j["base"].string; qty = j["qty"].double; entry = j["entry"].double
        mark = j["mark"].double; upnl = j["upnl"].double; lev = j["lev"].double; margin = j["margin"].double
        isolated = j["isolated"].bool; liq = j["liq"].double; maint = j["maint"].double
        priceDec = j["priceDec"].int; qtyDec = j["qtyDec"].int
        realized = j["realized"].doubleOrNil; tp = j["tp"].double; sl = j["sl"].double
        removable = j["removable"].double; maxLev = j["maxLev"].doubleOrNil
    }
    var long: Bool { qty > 0 }
}

struct Balance: Identifiable, Equatable {
    var id: String { sym.isEmpty ? base : sym }
    var sym: String, base: String, cat: String
    var free: Double, locked: Double, mark: Double, value: Double, avgCost: Double, pnl: Double
    var priceDec: Int, qtyDec: Int
    init(_ j: JSON) {
        sym = j["sym"].string; base = j["base"].string; cat = j["cat"].string
        free = j["free"].double; locked = j["locked"].double; mark = j["mark"].double; value = j["value"].double
        avgCost = j["avgCost"].double; pnl = j["pnl"].double; priceDec = j["priceDec"].int; qtyDec = j["qtyDec"].int
    }
}

struct OpenOrder: Identifiable, Equatable {
    var id: Int
    var sym: String, side: String
    var price: Double, qty: Double, priceDec: Int, qtyDec: Int
    var spot: Bool, lev: Double, isolated: Bool, reduceOnly: Bool
    init(_ j: JSON) {
        id = j["id"].int; sym = j["sym"].string; side = j["side"].string; price = j["price"].double; qty = j["qty"].double
        priceDec = j["priceDec"].int; qtyDec = j["qtyDec"].int; spot = j["spot"].bool; lev = j["lev"].double
        isolated = j["isolated"].bool; reduceOnly = j["reduceOnly"].bool
    }
}

struct VipInfo: Equatable {
    var spot: Int, perp: Int
    var assets: Double, vol30Spot: Double, vol30Perp: Double
    var spotMaker: Double, spotTaker: Double, perpMaker: Double, perpTaker: Double
    init(_ j: JSON) {
        spot = j["spot"].int; perp = j["perp"].int; assets = j["assets"].double
        vol30Spot = j["vol30Spot"].double; vol30Perp = j["vol30Perp"].double
        spotMaker = j["spotMaker"].double; spotTaker = j["spotTaker"].double
        perpMaker = j["perpMaker"].double; perpTaker = j["perpTaker"].double
    }
}

struct Account: Equatable {
    var wallet: Double, equity: Double, available: Double, margin: Double, upnl: Double, leverage: Double
    var fees: Double, volume: Double
    var positions: [Position]
    var orders: [OpenOrder]
    var spotValue: Double, spotLocked: Double, total: Double
    var balances: [Balance]
    var usdtUsd: Double
    var vip: VipInfo?
    init(_ j: JSON) {
        wallet = j["wallet"].double; equity = j["equity"].double; available = j["available"].double
        margin = j["margin"].double; upnl = j["upnl"].double; leverage = j["leverage"].double
        fees = j["fees"].double; volume = j["volume"].double
        positions = j["positions"].array.map(Position.init)
        orders = j["orders"].array.map(OpenOrder.init)
        spotValue = j["spotValue"].double; spotLocked = j["spotLocked"].double; total = j["total"].double
        balances = j["balances"].array.map(Balance.init)
        usdtUsd = j["usdtUsd"].double
        vip = j["vip"].exists ? VipInfo(j["vip"]) : nil
    }
}

typealias Level = (p: Double, q: Double)

struct SkyTrade: Identifiable {
    var id: Int, price: Double, qty: Double, buy: Bool, t: Double
    init(_ j: JSON) { id = j["id"].int; price = j["price"].double; qty = j["qty"].double; buy = j["buy"].bool; t = j["t"].double }
}

/// /snapshot: one SKY market's ticker, book and trades.
struct Snapshot {
    var sym: String, base: String, name: String, cat: String, sub: String, src: String, ref: String, icon: String
    var priceDec: Int, qtyDec: Int, maxLev: Double, spot: Bool
    var bid: Double, ask: Double, live: Bool
    var last: Double, mark: Double, index: Double, open: Double, high: Double, low: Double
    var volBase: Double, volUsdt: Double, funding: Double, nextFunding: Double
    var bids: [Level], asks: [Level]
    var trades: [SkyTrade]
    var tradeCount: Int
    init(_ j: JSON) {
        sym = j["sym"].string; base = j["base"].string; name = j["name"].string; cat = j["cat"].string
        sub = j["sub"].string; src = j["src"].string; ref = j["ref"].string; icon = j["icon"].string
        priceDec = j["priceDec"].int; qtyDec = j["qtyDec"].int; maxLev = j["maxLev"].double; spot = j["spot"].bool
        bid = j["bid"].double; ask = j["ask"].double; live = j["live"].bool
        last = j["last"].double; mark = j["mark"].double; index = j["index"].double
        open = j["open"].double; high = j["high"].double; low = j["low"].double
        volBase = j["volBase"].double; volUsdt = j["volUsdt"].double
        funding = j["funding"].double; nextFunding = j["nextFunding"].double
        bids = j["bids"].array.map { ($0[0].double, $0[1].double) }
        asks = j["asks"].array.map { ($0[0].double, $0[1].double) }
        trades = j["trades"].array.map(SkyTrade.init)
        tradeCount = j["tradeCount"].int
    }
    var chg: Double { open > 0 ? (last - open) / open * 100 : 0 }
}

struct Candle {
    var t: Double, o: Double, h: Double, l: Double, c: Double, v: Double
}

/// Binance 24h / trading-day ticker.
struct Ticker {
    var sym: String, price: Double, open: Double, chg: Double, high: Double, low: Double, quoteVol: Double
    init(_ j: JSON) {
        sym = j["symbol"].string; price = j["lastPrice"].double; open = j["openPrice"].double
        chg = j["priceChangePercent"].double; high = j["highPrice"].double; low = j["lowPrice"].double
        quoteVol = j["quoteVolume"].double
    }
}

/// skyd /markets catalog row.
struct CatItem: Identifiable {
    var id: String { sym }
    var sym: String, base: String, name: String, sub: String, chain: String, icon: String
    var price: Double, chg: Double, vol: Double, tradable: Bool, spot: Bool
    var cat: String
    init(_ j: JSON, cat: String) {
        sym = j["sym"].string; base = j["base"].string; name = j["name"].string; sub = j["sub"].string
        chain = j["chain"].string; icon = j["icon"].string; price = j["price"].double; chg = j["chg"].double
        vol = j["vol"].double; tradable = j["tradable"].bool; spot = j["spot"].bool
        self.cat = cat
    }
}
