import SwiftUI

/// Account-pages rail (Nav.tsx SideNav), horizontal on phones.
struct SideNavBar: View {
    @Environment(Prefs.self) private var prefs
    @Environment(Router.self) private var router
    @Environment(\.pal) private var pal
    let active: String
    var body: some View {
        let items: [(String, Lucide, String, Route)] = [
            ("assets", .layoutDashboard, prefs.t("overview"), .assets),
            ("futures", .chartCandlestick, prefs.t("futures"), .trade("BTCUSDT")),
            ("vip", .crown, prefs.t("vipTitle"), .vip),
            ("settings", .slidersHorizontal, prefs.t("settings"), .settings),
            ("security", .shieldCheck, prefs.t("security"), .settings),
            ("help", .circleHelp, prefs.t("help"), .settings),
        ]
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 4) {
                ForEach(items.indices, id: \.self) { i in
                    let it = items[i]
                    let on = it.0 == active
                    Button { router.go(it.3) } label: {
                        HStack(spacing: 12) {
                            Icon(it.1, 18, stroke: 1.7)
                            Text(it.2).font(.inter(13, .medium)).lineLimit(1)
                        }
                        .foregroundColor(on ? pal.gold : pal.ink2)
                        .padding(.horizontal, 12).padding(.vertical, 8)
                        .background(RoundedRectangle(cornerRadius: 8).fill(on ? pal.surface2 : .clear))
                    }
                    .buttonStyle(PlainTap())
                }
            }
        }
    }
}

/// pages/Vip.tsx.
struct VipPage: View {
    @Environment(Prefs.self) private var prefs
    @Environment(Session.self) private var session
    @Environment(Router.self) private var router
    @Environment(\.pal) private var pal
    @State private var market = "spot"

    var body: some View {
        let mine = VIP.of(session.account)
        let current = market == "spot" ? mine.spot : mine.perp
        VStack(alignment: .leading, spacing: 10) {
            SideNavBar(active: "vip")
            VStack(alignment: .leading, spacing: 4) {
                Text(prefs.t("vipTitle")).font(prefs.display(19)).foregroundColor(pal.ink)
                Text(prefs.t("vipSubtitle")).font(.inter(12)).foregroundColor(pal.muted)
            }
            vipCard(mine)
            gallery(current.level)
            table(current)
        }
    }

    private func vipCard(_ mine: VIP.Mine) -> some View {
        let next = VIP.next(mine.spot)
        let progress = next.map { min(1, mine.assetsUsd / $0.minAssets) } ?? 1
        return VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(prefs.t("vip")).font(.inter(16, .semibold)).foregroundColor(pal.ink)
                    Text(prefs.t("vipSub")).font(.inter(12.5)).foregroundColor(pal.muted)
                }
                Spacer()
                TierBadge(text: tierName(mine.spot.level, prefs), icon: .crown)
            }
            JoyCard(tier: CardTier.forLevel(mine.spot.level), level: mine.spot.level)
            VStack(spacing: 0) {
                HStack {
                    Text(prefs.t("vipCardFees")); Spacer()
                    Text(prefs.t("maker")).frame(width: 96, alignment: .trailing)
                    Text(prefs.t("taker")).frame(width: 96, alignment: .trailing)
                }
                .font(.inter(11.5)).foregroundColor(pal.muted).padding(.vertical, 4)
                feeRow(prefs.t("spot"), VIP.pct(mine.spot.spotMaker), VIP.pct(mine.spot.spotTaker))
                feeRow(prefs.t("perpetual"), VIP.pct(mine.perp.perpMaker), VIP.pct(mine.perp.perpTaker))
            }
            if let next {
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text(prefs.t("toNext", ["tier": tierName(next.level, prefs)])).foregroundColor(pal.ink)
                        Spacer()
                        Text("\(Int((progress * 100).rounded()))%").monospacedDigit().foregroundColor(pal.muted)
                    }
                    .font(.inter(12.5))
                    GeometryReader { g in
                        ZStack(alignment: .leading) {
                            Capsule().fill(pal.surface2)
                            Capsule().fill(pal.goldGrad).frame(width: g.size.width * progress)
                        }
                    }
                    .frame(height: 6)
                    Text("\(prefs.t("needAssets", ["x": prefs.num(max(0, next.minAssets - mine.assetsUsd))])) \(prefs.t("needVol", ["x": prefs.num(max(0, next.minVolSpot - mine.volSpot), 0)]))")
                        .font(.inter(11.5)).foregroundColor(pal.muted)
                }
            } else {
                Text(prefs.t("topTier")).font(.inter(12.5)).foregroundColor(pal.muted)
            }
            Button { router.go(.vip) } label: {
                HStack(spacing: 6) { Icon(.arrowUpRight, 16); Text(prefs.t("benefits")) }
            }
            .btn(.gold, .sm)
        }
        .card(tint: true)
    }

    private func feeRow(_ name: String, _ maker: String, _ taker: String) -> some View {
        VStack(spacing: 0) {
            Hairline()
            HStack {
                Text(name).foregroundColor(pal.ink); Spacer()
                Text(maker).monospacedDigit().foregroundColor(pal.ink).frame(width: 96, alignment: .trailing)
                Text(taker).monospacedDigit().foregroundColor(pal.ink).frame(width: 96, alignment: .trailing)
            }
            .font(.inter(13))
            .padding(.vertical, 7)
        }
    }

    private func gallery(_ level: Int) -> some View {
        let mine = CardTier.forLevel(level)
        return VStack(alignment: .leading, spacing: 8) {
            Text(prefs.t("vipCardGallery")).font(.inter(14.5, .semibold)).foregroundColor(pal.ink)
            VStack(spacing: 14) {
                ForEach(CardTier.allCases, id: \.self) { c in
                    VStack(alignment: .leading, spacing: 8) {
                        JoyCard(tier: c, compact: true)
                            .padding(c == mine ? 3 : 0)
                            .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(c == mine ? pal.gold : .clear, lineWidth: 2))
                        (Text("\(prefs.t("vipTier_\(c.rawValue)")) · ").foregroundColor(pal.ink)
                         + Text("\(tierName(c.levels.0, prefs)) – \(tierName(c.levels.1, prefs))").foregroundColor(pal.muted))
                            .font(.inter(12.5))
                    }
                    .opacity(c == mine ? 1 : 0.72)
                }
            }
        }
        .card()
    }

    private func usd(_ n: Double) -> String {
        let short: (Double) -> String = { v in prefs.num(v, v.rounded() == v ? 0 : 1) }
        return n >= 1e9 ? "\(short(n / 1e9))B" : n >= 1e6 ? "\(short(n / 1e6))M" : prefs.num(n, 0)
    }

    private func table(_ current: VipTier) -> some View {
        let spot = market == "spot"
        return VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top) {
                Tabs(items: [("spot", prefs.t("spot")), ("perp", prefs.t("perpetual"))], value: $market)
                Spacer()
                TierBadge(text: "\(prefs.t("yourTier")) · \(tierName(current.level, prefs))")
            }
            .padding(.horizontal, 12).padding(.top, 10)
            .overlay(alignment: .bottom) { Hairline() }
            ScrollView(.horizontal, showsIndicators: false) {
                Grid(alignment: .leading, horizontalSpacing: 0, verticalSpacing: 0) {
                    GridRow {
                        th(prefs.t("tier"), .leading)
                        th(prefs.t("assetReq"), .trailing)
                        th("", .center)
                        th(prefs.t("volReq"), .trailing)
                        th(prefs.t("maker"), .trailing)
                        th(prefs.t("taker"), .trailing)
                    }
                    ForEach(VIP.tiers, id: \.level) { x in
                        let on = x.level == current.level
                        let vol = spot ? x.minVolSpot : x.minVolPerp
                        let first = VIP.tiers[1]
                        let maker = spot ? x.spotMaker : x.perpMaker
                        GridRow {
                            td(tierName(x.level, prefs), .leading, color: on ? pal.gold : pal.ink, weight: on ? .semibold : .regular)
                            td(x.level == 0 ? "< \(usd(first.minAssets))" : "≥ \(usd(x.minAssets))", .trailing)
                            td(prefs.t("or"), .center, color: pal.muted, size: 12.5)
                            td(x.level == 0 ? "< \(usd(spot ? first.minVolSpot : first.minVolPerp))" : "≥ \(usd(vol))", .trailing)
                            td(VIP.pct(maker), .trailing, color: maker < 0 ? pal.green : pal.ink)
                            td(VIP.pct(spot ? x.spotTaker : x.perpTaker), .trailing)
                        }
                        .background(on ? pal.goldTint : .clear)
                        .overlay(alignment: .top) { Hairline() }
                    }
                }
            }
            Text(prefs.t("orRule")).font(.inter(12.5)).foregroundColor(pal.muted)
                .padding(.horizontal, 20).padding(.vertical, 14)
        }
        .card(0)
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private func th(_ s: String, _ a: Alignment) -> some View {
        Text(s).font(.inter(11)).foregroundColor(pal.muted).lineLimit(1).fixedSize()
            .padding(8).frame(maxWidth: .infinity, alignment: a)
    }

    private func td(_ s: String, _ a: Alignment, color: Color? = nil, size: CGFloat = 12.5, weight: Font.Weight = .regular) -> some View {
        Text(s).font(.inter(size, weight)).monospacedDigit().foregroundColor(color ?? pal.ink).lineLimit(1).fixedSize()
            .padding(8).frame(maxWidth: .infinity, alignment: a)
    }
}
