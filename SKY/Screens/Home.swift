import SwiftUI

/// pages/Home.tsx (phone layout).
struct HomePage: View {
    @Environment(Prefs.self) private var prefs
    @Environment(Session.self) private var session
    @Environment(Router.self) private var router
    @Environment(\.pal) private var pal

    @State private var tab = "popular"
    @State private var feed = SpotTickers(MarketMeta.spotSymbols + ["PAXGUSDT"])
    @State private var skyStats: (n: Int, trades: Int)?

    var body: some View {
        let markets = MarketMeta.live(feed.tickers)
        let totalVol = markets.reduce(0) { $0 + $1.vol }
        VStack(alignment: .leading, spacing: 16) {
            hero(totalVol: totalVol)
            coinCard(markets)
            newsCard
        }
        .task { await feed.start() }
        .onDisappear { feed.stop() }
        .task {
            while !Task.isCancelled {
                if let ms = try? await API.shared.get("/sky/markets") {
                    let rows = ms.array
                    skyStats = (rows.count, rows.reduce(0) { $0 + $1["trades"].int })
                }
                try? await Task.sleep(nanoseconds: 5_000_000_000)
            }
        }
    }

    // MARK: hero

    @ViewBuilder private func hero(totalVol: Double) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            GoldText(text: "SKY", font: .cinzel(56), tracking: 56 * 0.14)
                .shadow(color: .black.opacity(0.25), radius: 0, x: 0, y: 1)
                .padding(.top, 6)
                .frame(height: 62, alignment: .bottomLeading)
            if session.me != nil {
                vipCard.padding(.top, 14)
                HStack(spacing: 8) {
                    Button(prefs.t("deposit")) { router.go(.assets) }.btn(.gold, .lg, wide: true)
                    Button { router.go(.spot("BTCUSDT")) } label: {
                        HStack(spacing: 6) { Text(prefs.t("tradeNow")); Icon(.arrowRight, 16) }
                    }.btn(.plain, .lg, wide: true)
                }
                .padding(.top, 14)
            } else {
                HStack(spacing: 8) {
                    Button(prefs.t("register")) { router.open(.register) }.btn(.gold, .lg, wide: true)
                    Button(prefs.t("login")) { router.open(.login) }.btn(.plain, .lg, wide: true)
                }
                .padding(.top, 14)
            }
            stats(totalVol: totalVol).padding(.top, 14)
        }
    }

    private var vipCard: some View {
        let acct = session.account
        let total = acct?.total ?? acct?.equity ?? 0
        let pnl = acct?.upnl ?? 0
        let level = VIP.of(acct).level
        return Button { router.go(.vip) } label: {
            JoyCard(tier: CardTier.forLevel(level), level: level, radius: 14)
                .overlay(alignment: .bottomTrailing) {
                    GeometryReader { g in
                        VStack(alignment: .trailing, spacing: 3) {
                            Text(prefs.t("equity")).font(.system(size: 11.5)).foregroundColor(.white.opacity(0.78))
                            HStack(alignment: .firstTextBaseline, spacing: 4) {
                                Text(prefs.num(total)).font(.inter(19, .bold)).monospacedDigit().foregroundColor(.white)
                                Text("USDT").font(.inter(11, .medium)).foregroundColor(.white.opacity(0.78))
                            }
                            Text("\(prefs.t("pnl")) \(pnl >= 0 ? "+" : "−")\(prefs.num(abs(pnl)))")
                                .font(.inter(12, .semibold)).monospacedDigit()
                                .foregroundColor(pnl >= 0 ? Color(hex: 0x5be0a8) : Color(hex: 0xff8b9b))
                        }
                        .shadow(color: .black.opacity(0.6), radius: 1.5, x: 0, y: 1)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                        .padding(.trailing, g.size.width * 0.065)
                        .padding(.bottom, g.size.height * 0.09)
                    }
                }
        }
        .buttonStyle(PlainTap())
    }

    private func stats(totalVol: Double) -> some View {
        let items: [(Lucide, String, String)] = [
            (.activity, Fmt.compact(totalVol, prefs.num), prefs.t("activity")),
            (.layoutGrid, skyStats.map { prefs.num(Double($0.n), 0) } ?? "—", "SKY · \(prefs.t("markets"))"),
            (.receipt, skyStats.map { prefs.num(Double($0.trades), 0) } ?? "—", "SKY · \(prefs.t("tradeCount"))"),
        ]
        return HStack(spacing: 8) {
            ForEach(0..<3, id: \.self) { i in
                VStack(alignment: .leading, spacing: 4) {
                    Icon(items[i].0, 16, stroke: 1.7)
                        .foregroundColor(pal.gold)
                        .frame(width: 26, height: 26)
                        .background(RoundedRectangle(cornerRadius: 8).fill(pal.goldTint))
                    Text(items[i].1).font(.inter(16, .semibold)).monospacedDigit().foregroundColor(pal.ink).lineLimit(1)
                    Text(items[i].2).font(.inter(11)).foregroundColor(pal.muted).lineLimit(1)
                }
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(RoundedRectangle(cornerRadius: 10).fill(pal.surface))
                .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(pal.line, lineWidth: 1))
            }
        }
    }

    // MARK: lists

    private func coinCard(_ markets: [MarketMeta]) -> some View {
        let list = markets.sorted { tab == "popular" ? $0.vol > $1.vol : $0.chg > $1.chg }.prefix(5)
        return VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top) {
                Tabs(items: [("popular", prefs.t("popular")), ("gainers", prefs.t("gainers"))], value: $tab)
                Spacer()
                AllLink { router.go(.markets) }
            }
            ForEach(Array(list), id: \.sym) { m in
                Button { router.go(.spot(m.sym + "USDT")) } label: {
                    HStack(spacing: 10) {
                        Token(sym: m.sym, size: 28)
                        Text(m.sym).font(.inter(13, .semibold)).foregroundColor(pal.ink)
                        Spacer(minLength: 0)
                        Num(prefs.num(m.price, Fmt.priceDigits(m.price)), 13, .medium)
                        Chg(v: m.chg, plain: true, size: 13)
                        Color.clear.frame(width: 64, height: 1)
                    }
                    .padding(.vertical, 8)
                    .contentShape(Rectangle())
                }
                .buttonStyle(PlainTap())
            }
        }
        .card()
    }

    private var newsCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text(prefs.t("news")).font(.inter(14.5, .semibold)).foregroundColor(pal.ink)
                Spacer()
                AllLink { router.go(.vip) }
            }
            .padding(.bottom, 8)
            newsRow("news1") { router.go(.trade("BTCUSDT")) }
            newsRow("news2") { router.go(.vip) }
            newsRow("news3") { router.go(.settings) }
        }
        .card()
    }

    private func newsRow(_ key: String, _ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(prefs.t(key)).font(.inter(13)).foregroundColor(pal.ink2)
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, 9)
        }
        .buttonStyle(PlainTap())
    }
}

/// "查看全部 ›" link (.more.muted.small).
struct AllLink: View {
    @Environment(Prefs.self) private var prefs
    @Environment(\.pal) private var pal
    var label: String?
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            HStack(spacing: 2) {
                Text(label ?? prefs.t("all")).font(.inter(12.5))
                Icon(.chevronRight, 14)
            }
            .foregroundColor(pal.muted)
        }
        .buttonStyle(PlainTap())
    }
}
