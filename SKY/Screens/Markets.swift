import SwiftUI

/// Watchlist (market/watchlist.ts), same storage key as the website.
@Observable
final class Watchlist {
    static let shared = Watchlist()
    var stars: Set<String>
    private init() {
        if let saved = UserDefaults.standard.string(forKey: "sky.stars"),
           let data = saved.data(using: .utf8),
           let list = try? JSONSerialization.jsonObject(with: data) as? [String] {
            stars = Set(list)
        } else {
            stars = ["BTCUSDT", "ETHUSDT"]
        }
    }
    func toggle(_ sym: String) {
        if stars.contains(sym) { stars.remove(sym) } else { stars.insert(sym) }
        if let d = try? JSONSerialization.data(withJSONObject: Array(stars)), let s = String(data: d, encoding: .utf8) {
            UserDefaults.standard.set(s, forKey: "sky.stars")
        }
    }
}

/// usePriceFmt: enough digits for anything from 0.0000123 to 70,000.
func priceFmt(_ p: Double, _ prefs: Prefs) -> String {
    if p == 0 || !p.isFinite { return "—" }
    if p >= 100 { return prefs.num(p, 2) }
    if p >= 1 { return prefs.num(p, 4) }
    let d = min(10, max(4, 3 - Int(floor(log10(p)))))
    return prefs.num(p, d)
}

/// Polls skyd's /markets catalog for one category (catalog.ts useCatalog).
@MainActor
@Observable
final class Catalog {
    var items: [String: [CatItem]] = [:]
    var state: [String: String] = [:]

    func load(_ cat: String) async {
        do {
            let d = try await API.shared.get("/markets?cat=\(cat)")
            items[cat] = d["items"].array.map { CatItem($0, cat: cat) }
            state[cat] = "live"
        } catch {
            if state[cat] != "live" { state[cat] = "offline" }
        }
    }
}

/// pages/Markets.tsx (phone layout).
struct MarketsPage: View {
    @Environment(Prefs.self) private var prefs
    @Environment(Router.self) private var router
    @Environment(\.pal) private var pal

    @State private var cat = "crypto"
    @State private var sub = "all"
    @State private var q = ""
    @State private var limit = 50
    @State private var onlyStars = false
    @State private var catalog = Catalog()
    private var watch: Watchlist { Watchlist.shared }

    static let subs: [String: [String]] = [
        "crypto": [], "tradfi": ["local", "us", "hk", "kr", "cn", "preipo", "fx"],
        "commodities": ["metal", "energy", "rareearth"], "onchain": ["bsc", "solana", "base", "ethereum"],
    ]
    static let cats: [(String, Lucide)] = [("crypto", .bitcoin), ("tradfi", .landmark), ("commodities", .gem), ("onchain", .link2)]

    private var items: [CatItem] {
        if !onlyStars { return catalog.items[cat] ?? [] }
        var seen = Set<String>()
        var out: [CatItem] = []
        for c in ["tradfi", "crypto", "commodities", "onchain"] {
            for it in catalog.items[c] ?? [] where !seen.contains(it.sym) { seen.insert(it.sym); out.append(it) }
        }
        return out
    }

    private var feedState: String {
        if !onlyStars { return catalog.state[cat] ?? "loading" }
        let s = catalog.state.values
        return s.contains("live") ? "live" : s.isEmpty ? "loading" : "offline"
    }

    var body: some View {
        let all = items
        let qq = q.trimmingCharacters(in: .whitespaces).lowercased()
        let rows = all.filter { it in
            (onlyStars || sub == "all" || it.sub == sub)
                && (!onlyStars || watch.stars.contains(it.sym))
                && (qq.isEmpty || it.base.lowercased().contains(qq) || it.name.lowercased().contains(qq))
        }
        VStack(alignment: .leading, spacing: 10) {
            head
            chips
            boards(all)
            SentimentCard()
            ListingsCard()
            table(all: all, rows: rows)
        }
        .task(id: onlyStars ? "all" : cat) {
            while !Task.isCancelled {
                if onlyStars {
                    for c in ["crypto", "tradfi", "commodities", "onchain"] { await catalog.load(c) }
                } else {
                    await catalog.load(cat)
                }
                try? await Task.sleep(nanoseconds: 10_000_000_000)
            }
        }
    }

    private var head: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(prefs.t("marketTitle")).font(prefs.display(19)).foregroundColor(pal.ink)
                Text(prefs.t("marketSub")).font(.inter(12)).foregroundColor(pal.muted)
            }
            Spacer(minLength: 0)
            FeedBadge(state: feedState)
        }
    }

    private var chips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(0..<MarketsPage.cats.count, id: \.self) { ci in
                    let c = MarketsPage.cats[ci]
                    let on = !onlyStars && cat == c.0
                    Button {
                        onlyStars = false
                        if cat != c.0 { cat = c.0; sub = "all"; limit = 50 }
                    } label: {
                        HStack(spacing: 6) {
                            Icon(c.1, 16, stroke: 1.6)
                            Text(prefs.t(c.0)).font(.inter(13.5, .medium)).lineLimit(1)
                        }
                        .foregroundColor(on ? pal.gold : pal.muted)
                        .padding(.horizontal, 12).padding(.vertical, 7)
                        .background(RoundedRectangle(cornerRadius: 8).fill(on ? pal.surface2 : .clear))
                    }
                    .buttonStyle(PlainTap())
                }
            }
        }
    }

    private func open(_ m: CatItem) {
        if m.spot { router.go(.spot(m.sym)) } else if m.tradable { router.go(.trade(m.sym)) }
    }

    @ViewBuilder private func boards(_ all: [CatItem]) -> some View {
        let live = all.filter { $0.vol > 0 }
        let lists: [(String, [CatItem])] = [
            (prefs.t("hot"), Array(live.sorted { $0.vol > $1.vol }.prefix(3))),
            (prefs.t("gainers"), Array(live.sorted { $0.chg > $1.chg }.prefix(3))),
            (prefs.t("losers"), Array(live.sorted { $0.chg < $1.chg }.prefix(3))),
        ]
        let totalVol = all.reduce(0) { $0 + $1.vol }
        GeometryReader { g in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(alignment: .top, spacing: 10) {
                    ForEach(0..<3, id: \.self) { i in
                        VStack(alignment: .leading, spacing: 0) {
                            Text(lists[i].0).font(.inter(13, .medium)).foregroundColor(pal.muted)
                            VStack(spacing: 0) {
                                ForEach(lists[i].1) { m in
                                    Button { open(m) } label: {
                                        HStack(spacing: 8) {
                                            MarketIcon(base: m.base, icon: m.icon, cat: m.cat, sub: m.sub, chain: m.chain, size: 22)
                                            Text(m.base).font(.inter(13, .semibold)).foregroundColor(pal.ink).lineLimit(1)
                                            Spacer(minLength: 4)
                                            Num(priceFmt(m.price, prefs), 13)
                                            Chg(v: m.chg, plain: true, size: 13).frame(width: 64, alignment: .trailing)
                                        }
                                        .padding(.vertical, 7)
                                    }
                                    .buttonStyle(PlainTap())
                                }
                            }
                            .padding(.top, 8)
                        }
                        .card(16)
                        .frame(width: g.size.width * 0.74)
                    }
                    VStack(alignment: .leading, spacing: 4) {
                        Text(prefs.t("activity")).font(.inter(13, .medium)).foregroundColor(pal.muted)
                        HStack(alignment: .firstTextBaseline, spacing: 6) {
                            Num(Fmt.compact(totalVol, prefs.num), 17, .semibold)
                            Text("USDT").font(.inter(10)).foregroundColor(pal.muted)
                        }
                        Text("\(prefs.num(Double(all.count), 0)) \(prefs.t("results"))").font(.inter(12.5)).foregroundColor(pal.muted)
                        Spark(data: all.prefix(40).map { $0.vol }, fill: true).frame(height: 36)
                    }
                    .card(16)
                    .frame(width: g.size.width * 0.74)
                }
                .scrollTargetLayout()
            }
            .scrollTargetBehavior(.viewAligned)
        }
        .frame(height: 150)
    }

    @ViewBuilder private func table(all: [CatItem], rows: [CatItem]) -> some View {
        let subs = (MarketsPage.subs[cat] ?? []).filter { s in all.contains { $0.sub == s } }
        VStack(alignment: .leading, spacing: 0) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 16) {
                    tabButton(prefs.t("sub_all"), on: !onlyStars && sub == "all") { onlyStars = false; sub = "all" }
                    tabButton(prefs.t("watchlist"), on: onlyStars) { onlyStars = true; limit = 50 }
                    ForEach(subs, id: \.self) { s in
                        let label = prefs.has("sub_\(s)") ? prefs.t("sub_\(s)") : (all.first { $0.sub == s }?.chain ?? s)
                        tabButton(label, on: !onlyStars && sub == s) { onlyStars = false; sub = s }
                    }
                }
            }
            .padding(.horizontal, 12).padding(.top, 12)
            HStack(spacing: 8) {
                Icon(.search, 15).foregroundColor(pal.muted)
                TextField("", text: $q, prompt: Text(prefs.t("search")).foregroundColor(pal.muted))
                    .font(.inter(13)).foregroundColor(pal.ink)
                    .textInputAutocapitalization(.never).autocorrectionDisabled()
                    .onChange(of: q) { _, _ in limit = 50 }
            }
            .padding(.horizontal, 12)
            .frame(height: 34)
            .background(RoundedRectangle(cornerRadius: 8).fill(pal.surface))
            .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(pal.line, lineWidth: 1))
            .padding(.horizontal, 12).padding(.top, 4).padding(.bottom, 10)
            Hairline()
            HStack {
                Text(prefs.t("name"))
                Spacer()
                Text(prefs.t("price"))
                Text(prefs.t("change")).frame(width: 96, alignment: .trailing)
            }
            .font(.inter(11)).foregroundColor(pal.muted)
            .padding(8)
            ForEach(rows.prefix(limit)) { m in
                VStack(spacing: 0) {
                    Hairline()
                    HStack(spacing: 10) {
                        Button { watch.toggle(m.sym); Haptic.tap() } label: {
                            Icon(.star, 15, filled: watch.stars.contains(m.sym))
                                .foregroundColor(watch.stars.contains(m.sym) ? pal.gold : pal.muted)
                        }
                        .buttonStyle(PlainTap())
                        Button { open(m) } label: {
                            HStack(spacing: 10) {
                                MarketIcon(base: m.base, icon: m.icon, cat: m.cat, sub: m.sub, chain: m.chain, size: 26)
                                VStack(alignment: .leading, spacing: 1) {
                                    Text(m.base).font(.inter(13, .semibold)).foregroundColor(pal.ink).lineLimit(1)
                                    Text(subtitle(m)).font(.inter(11.5)).foregroundColor(pal.muted).lineLimit(1)
                                }
                                Spacer(minLength: 4)
                                Num(priceFmt(m.price, prefs), 13)
                                Text(Fmt.pct(m.chg)).font(.inter(12, .semibold)).monospacedDigit().foregroundColor(.white)
                                    .lineLimit(1).fixedSize()
                                    .frame(minWidth: 72).padding(.horizontal, 6).padding(.vertical, 5)
                                    .background(RoundedRectangle(cornerRadius: 6).fill(pal.dir(m.chg)))
                            }
                        }
                        .buttonStyle(PlainTap())
                    }
                    .padding(.horizontal, 8).padding(.vertical, 12)
                }
            }
            if rows.isEmpty {
                Hairline()
                EmptyNote(text: feedState == "offline" ? prefs.t("err_service_unavailable") : feedState == "loading" ? prefs.t("connecting") : prefs.t("noData"))
            }
            if rows.count > limit {
                Button("\(prefs.t("loadMore")) · \(prefs.num(Double(rows.count - limit), 0))") { limit += 50 }
                    .btn(.plain, .sm)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
            }
        }
        .card(0)
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private func subtitle(_ m: CatItem) -> String {
        let k = "cm_\(m.base)"
        var s = prefs.has(k) ? prefs.t(k) : m.name
        if s.isEmpty && m.sub == "spot" { s = "/ USDT" }
        if s.isEmpty { s = "/ USDT" }
        if !m.chain.isEmpty { s += " · \(m.chain)" }
        return s
    }

    private func tabButton(_ label: String, on: Bool, _ action: @escaping () -> Void) -> some View {
        Button { action(); Haptic.tap() } label: {
            Text(label).font(.inter(13, .medium)).foregroundColor(on ? pal.ink : pal.muted)
                .fixedSize()
                .padding(.bottom, 9)
                .overlay(alignment: .bottom) {
                    if on {
                        GeometryReader { g in
                            RoundedRectangle(cornerRadius: 2).fill(pal.gold)
                                .frame(width: g.size.width * 0.5, height: 3)
                                .position(x: g.size.width / 2, y: g.size.height - 1.5)
                        }
                    }
                }
        }
        .buttonStyle(PlainTap())
    }
}

/// ui.tsx FeedBadge: "● live · source".
struct FeedBadge: View {
    @Environment(Prefs.self) private var prefs
    @Environment(\.pal) private var pal
    let state: String
    var body: some View {
        HStack(spacing: 6) {
            Circle().fill(state == "live" ? pal.green : state == "offline" ? pal.red : pal.muted)
                .frame(width: 7, height: 7)
                .background(Circle().fill(state == "live" ? pal.greenTint : .clear).frame(width: 13, height: 13))
            (Text(state == "live" ? prefs.t("live") : state == "loading" ? prefs.t("connecting") : prefs.t("offline"))
                .foregroundColor(pal.ink)
             + Text(" · \(prefs.t("source"))").foregroundColor(pal.muted))
                .font(.inter(12))
                .lineLimit(1)
        }
    }
}

/// ui.tsx Spark.
struct Spark: View {
    @Environment(\.pal) private var pal
    let data: [Double]
    var up = true
    var fill = false
    var body: some View {
        GeometryReader { g in
            let w = g.size.width, h = g.size.height
            if data.count >= 2 {
                let lo = data.min() ?? 0, hi = data.max() ?? 1
                let span = (hi - lo) == 0 ? 1 : hi - lo
                let pts = data.enumerated().map { i, v in
                    CGPoint(x: CGFloat(i) / CGFloat(data.count - 1) * w, y: h - 2 - CGFloat((v - lo) / span) * (h - 4))
                }
                let line = Path { p in p.addLines(pts) }
                if fill {
                    Path { p in p.addLines(pts); p.addLine(to: CGPoint(x: w, y: h)); p.addLine(to: CGPoint(x: 0, y: h)); p.closeSubpath() }
                        .fill(LinearGradient(colors: [Color(hex: 0xd9b560, alpha: 0.28), Color(hex: 0xd9b560, alpha: 0)], startPoint: .top, endPoint: .bottom))
                }
                line.stroke(fill ? pal.gold : up ? pal.green : pal.red, style: StrokeStyle(lineWidth: fill ? 2 : 1.5, lineJoin: .round))
            }
        }
    }
}

/// SentimentGauge.tsx inside its pulse card.
struct SentimentCard: View {
    @Environment(Prefs.self) private var prefs
    @Environment(\.pal) private var pal
    @State private var data: JSON?
    @State private var failed = false

    static func mood(_ v: Double) -> String {
        v < 20 ? "moodExtremeFear" : v < 40 ? "moodFear" : v <= 60 ? "moodNeutral" : v < 80 ? "moodGreed" : "moodExtremeGreed"
    }

    var body: some View {
        let r = data?["fearGreed"]
        VStack(alignment: .leading, spacing: 14) {
            Text(prefs.t("fearGreedTitle")).font(.inter(17, .semibold)).foregroundColor(pal.ink)
            if let r, r.exists {
                let score = max(0, min(100, r["current"].double))
                HStack(alignment: .center, spacing: 8) {
                    gauge(score)
                    VStack(alignment: .leading, spacing: 26) {
                        history("sentimentYesterday", r["yesterday"].double)
                        history("sentimentLastWeek", r["lastWeek"].double)
                    }
                    .frame(width: 104)
                    .padding(.bottom, 4)
                }
                let bearN = r["bearish"].double, bullN = r["bullish"].double
                if bearN + bullN > 0 {
                    let bear = Int((100 * bearN / (bearN + bullN)).rounded())
                    VStack(alignment: .leading, spacing: 8) {
                        Text(prefs.t("btcSentiment")).font(.inter(12.5, .medium)).foregroundColor(pal.ink)
                        HStack(spacing: 5) {
                            vote(prefs.t("bearish"), bear, color: Color(hex: 0xf6465d), left: true)
                            vote(prefs.t("bullish"), 100 - bear, color: Color(hex: 0x2ebd85), left: false)
                        }
                    }
                }
                HStack(spacing: 8) {
                    Text("Binance Square")
                    Text(timeOf(r["updated"].string))
                }
                .font(.inter(11.5)).foregroundColor(pal.muted)
            } else {
                Text(prefs.t(failed ? "err_service_unavailable" : "connecting")).font(.inter(12.5)).foregroundColor(pal.muted)
                    .frame(maxWidth: .infinity).padding(.vertical, 40)
            }
        }
        .card()
        .task {
            while !Task.isCancelled {
                do { data = try await API.shared.get("/market-sentiment"); failed = false } catch { failed = true }
                try? await Task.sleep(nanoseconds: 15_000_000_000)
            }
        }
    }

    private func timeOf(_ iso: String) -> String {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let d = f.date(from: iso) ?? ISO8601DateFormatter().date(from: iso)
        guard let d else { return "" }
        let out = DateFormatter()
        out.dateFormat = "HH:mm:ss"
        return out.string(from: d)
    }

    private func history(_ key: String, _ v: Double) -> some View {
        HStack(spacing: 7) {
            VStack(alignment: .leading, spacing: 3) {
                Text(prefs.t(key)).font(.inter(12)).foregroundColor(pal.muted)
                Text(prefs.t(SentimentCard.mood(v))).font(.inter(12, .medium)).foregroundColor(pal.ink)
            }
            Spacer(minLength: 0)
            Text("\(Int(v))").font(.inter(20, .semibold)).foregroundColor(pal.ink)
        }
    }

    private func vote(_ label: String, _ pct: Int, color: Color, left: Bool) -> some View {
        HStack(spacing: 8) {
            Text(label).font(.inter(12, .medium))
            Text("\(pct)%").font(.inter(12, .semibold))
        }
        .foregroundColor(.white)
        .frame(maxWidth: .infinity, minHeight: 32)
        .background(Slant(left: left).fill(color))
    }

    /// The 320×180 gauge drawn at the card's width.
    private func gauge(_ score: Double) -> some View {
        GeometryReader { g in
            let k = g.size.width / 320
            let angle = Double.pi * (1 - score / 100)
            let dx = cos(angle), dy = -sin(angle)
            let x = 160 + 109 * dx, y = 155 + 109 * dy
            ZStack(alignment: .topLeading) {
                Path { p in
                    p.addArc(center: CGPoint(x: 160 * k, y: 155 * k), radius: 136 * k,
                             startAngle: .degrees(180), endAngle: .degrees(360), clockwise: false)
                }
                .stroke(LinearGradient(stops: [
                    .init(color: Color(hex: 0xf6465d), location: 0), .init(color: Color(hex: 0xff9c32), location: 0.35),
                    .init(color: Color(hex: 0xf0d64f), location: 0.53), .init(color: Color(hex: 0x32c88f), location: 0.75),
                    .init(color: Color(hex: 0x0ecb81), location: 1),
                ], startPoint: UnitPoint(x: 14 / 320, y: 0), endPoint: UnitPoint(x: 306 / 320, y: 0)), lineWidth: 20 * k)
                Path { p in
                    p.move(to: CGPoint(x: (x + 10 * dx) * k, y: (y + 10 * dy) * k))
                    p.addLine(to: CGPoint(x: (x - 7 * dx - 7 * dy) * k, y: (y - 7 * dy + 7 * dx) * k))
                    p.addLine(to: CGPoint(x: (x - 7 * dx + 7 * dy) * k, y: (y - 7 * dy - 7 * dx) * k))
                    p.closeSubpath()
                }
                .fill(pal.muted)
                Text("\(Int(score))").font(.inter(36 * min(1, k * 1.0), .semibold)).foregroundColor(pal.ink)
                    .fixedSize()
                    .position(x: 160 * k, y: 121 * k - 36 * 0.36 * min(1, k))
                Text(prefs.t(SentimentCard.mood(score))).font(.inter(21 * k, .medium)).foregroundColor(pal.ink)
                    .fixedSize()
                    .position(x: 160 * k, y: 151 * k - 21 * 0.36 * k)
            }
        }
        .aspectRatio(320.0 / 180.0, contentMode: .fit)
        .padding(.top, 8)
    }
}

/// Clipped vote bar (.fng-bear / .fng-bull).
struct Slant: Shape {
    let left: Bool
    func path(in r: CGRect) -> Path {
        Path { p in
            if left {
                p.move(to: .zero); p.addLine(to: CGPoint(x: r.width, y: 0))
                p.addLine(to: CGPoint(x: r.width * 0.95, y: r.height)); p.addLine(to: CGPoint(x: 0, y: r.height))
            } else {
                p.move(to: CGPoint(x: r.width * 0.05, y: 0)); p.addLine(to: CGPoint(x: r.width, y: 0))
                p.addLine(to: CGPoint(x: r.width, y: r.height)); p.addLine(to: CGPoint(x: 0, y: r.height))
            }
            p.closeSubpath()
        }
    }
}

/// MarketPulse.tsx upcoming-listings card.
struct ListingsCard: View {
    @Environment(Prefs.self) private var prefs
    @Environment(Router.self) private var router
    @Environment(\.pal) private var pal
    @State private var items: [JSON] = []
    @State private var offset: Double = 0
    @State private var ready = false
    @State private var failed = false
    @State private var now = Date()

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Icon(.clock3, 18).foregroundColor(pal.gold)
                Text(prefs.t("upcomingListings")).font(.inter(14.5, .semibold)).foregroundColor(pal.ink)
            }
            if items.isEmpty {
                Text(prefs.t(failed ? "err_service_unavailable" : ready ? "listingEmpty" : "connecting"))
                    .font(.inter(12.5)).foregroundColor(pal.muted)
            } else {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 9)], spacing: 9) {
                    ForEach(items.indices, id: \.self) { i in card(items[i]) }
                }
            }
        }
        .card()
        .task {
            while !Task.isCancelled {
                do {
                    let r = try await API.shared.get("/listings")
                    items = r["items"].array
                    offset = r["serverTime"].double - Date().timeIntervalSince1970 * 1000
                    ready = true; failed = false
                } catch { failed = true }
                try? await Task.sleep(nanoseconds: 4_000_000_000)
            }
        }
        .onReceive(Timer.publish(every: 1, on: .main, in: .common).autoconnect()) { now = $0 }
    }

    private func card(_ it: JSON) -> some View {
        let sym = it["symbol"].string
        let base = sym.hasSuffix("USDT") ? String(sym.dropLast(4)) : sym
        let board = it["board"].string
        let status = it["status"].string
        return VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                MarketIcon(base: base, cat: it["category"].string, size: 31)
                VStack(alignment: .leading, spacing: 0) {
                    Text("\(base) / USDT").font(.inter(13, .semibold)).foregroundColor(pal.ink)
                    if !it["name"].string.isEmpty { Text(it["name"].string).font(.inter(12.5)).foregroundColor(pal.muted) }
                }
            }
            HStack(spacing: 10) {
                if board != "perp" { TierBadge(text: prefs.t("spotNav")) }
                if board != "spot" { TierBadge(text: prefs.t("futuresNav")) }
            }
            Text(countdown(it)).font(.inter(18, .semibold)).monospacedDigit().foregroundColor(pal.gold)
            Text(launchTime(it["launchAt"].string)).font(.inter(11.5)).foregroundColor(pal.muted)
            if status == "live" {
                HStack(spacing: 10) {
                    if board != "perp" { Button(prefs.t("spotNav")) { router.go(.spot(sym)) }.foregroundColor(pal.gold) }
                    if board != "spot" { Button(prefs.t("futuresNav")) { router.go(.trade(sym)) }.foregroundColor(pal.gold) }
                }
                .font(.inter(13))
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 8).fill(pal.surface2))
        .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(pal.line, lineWidth: 1))
    }

    private func date(_ iso: String) -> Date? {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f.date(from: iso) ?? ISO8601DateFormatter().date(from: iso)
    }

    private func launchTime(_ iso: String) -> String {
        guard let d = date(iso) else { return iso }
        let f = DateFormatter()
        f.dateStyle = .short; f.timeStyle = .medium
        f.locale = Locale(identifier: prefs.lang)
        return f.string(from: d)
    }

    /// listings.ts remaining() + ListingCountdown.
    private func countdown(_ it: JSON) -> String {
        let status = it["status"].string
        if status != "scheduled" { return prefs.t(status == "live" ? "listingLive" : "listingCancelled") }
        let at = (date(it["launchAt"].string)?.timeIntervalSince1970 ?? 0) * 1000
        let nowMs = now.timeIntervalSince1970 * 1000 + offset
        var s = max(0, Int(ceil((at - nowMs) / 1000)))
        let days = s / 86400
        s %= 86400
        if days == 0 && s == 0 { return prefs.t(it["issue"].string.isEmpty ? "listingOpening" : "listingWaitingPrice") }
        let clock = String(format: "%02d:%02d:%02d", s / 3600, s % 3600 / 60, s % 60)
        return days > 0 ? "\(days)\(prefs.t("dayUnit")) \(clock)" : clock
    }
}

/// .tier-badge (phone size).
struct TierBadge: View {
    @Environment(\.pal) private var pal
    let text: String
    var icon: Lucide?
    var body: some View {
        HStack(spacing: 6) {
            if let icon { Icon(icon, 14) }
            Text(text).font(.inter(11.5)).lineLimit(1)
        }
        .foregroundColor(pal.gold)
        .padding(.horizontal, 9).padding(.vertical, 3)
        .background(Capsule().fill(pal.goldTint))
    }
}
