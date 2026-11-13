import SwiftUI

/// pages/Profile.tsx (phone layout, follow button docked at the bottom).
struct ProfilePage: View {
    @Environment(Prefs.self) private var prefs
    @Environment(Session.self) private var session
    @Environment(Router.self) private var router
    @Environment(\.pal) private var pal
    let id: Int
    @State var p: JSON?
    @State var err = ""
    @State var tab = "content"
    @State var feed: JSON?
    @State var rev = 0
    @State var first = true

    var body: some View {
        Group {
            if let p {
                ZStack(alignment: .bottom) {
                    ScrollView { content(p).padding(.horizontal, 10).padding(.bottom, p["isMe"].bool ? 16 : 70) }
                    if !p["isMe"].bool {
                        Button("\(prefs.t(p["isFollowing"].bool ? "pf_following" : "pf_follow")) · \(p["followers"].int)") { Task { await follow() } }
                            .btn(p["isFollowing"].bool ? .plain : .gold, wide: true)
                            .padding(.horizontal, 10).padding(.vertical, 6)
                            .background(pal.surface)
                            .overlay(alignment: .top) { Hairline() }
                    }
                }
            } else if !err.isEmpty {
                VStack(alignment: .leading, spacing: 16) {
                    Text(prefs.t("err_\(err)")).font(.inter(16, .semibold)).foregroundColor(pal.ink)
                    Button(prefs.t("community")) { router.go(.community(nil)) }.btn(.gold)
                }
                .padding(20).card(0).padding(10)
                Spacer()
            } else {
                EmptyNote(text: prefs.t("connecting"))
                Spacer()
            }
        }
        .task(id: "\(rev)|\(session.me?.id ?? 0)") {
            do {
                let d = try await API.shared.get("/users/\(id)")
                p = d
                if first { tab = d["ai"].bool || d["publicPerf"].bool ? "live" : "content"; first = false }
            } catch { err = (error as? APIError)?.code ?? "service_unavailable" }
            feed = try? await API.shared.get("/users/\(id)/posts")
        }
    }

    @ViewBuilder private func content(_ p: JSON) -> some View {
        let a = Author(p)
        VStack(alignment: .leading, spacing: 0) {
            ZStack {
                pal.goldGrad
                RadialGradient(colors: [Color.white.opacity(0.35), .clear], center: UnitPoint(x: 0.8, y: 0.2), startRadius: 0, endRadius: 120)
            }
            .frame(height: 84)
            .padding(.horizontal, -10)
            HStack(alignment: .bottom) {
                AvatarView(a: a, size: 68)
                    .padding(3)
                    .background(Circle().fill(pal.bg))
                Spacer()
                if p["isMe"].bool {
                    Button { router.go(.settings) } label: { HStack(spacing: 6) { Icon(.pencil, 15); Text(prefs.t("pf_edit")) } }
                        .btn(.ghost).padding(.bottom, 6)
                }
            }
            .padding(.horizontal, 4)
            .padding(.top, -34)
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 6) {
                    Text(p["nick"].string).font(.inter(19, .bold)).foregroundColor(pal.ink)
                    if p["verified"].bool { VerifiedMark(size: 22) }
                    if p["ai"].bool { AIBadge() }
                }
                if !p["bio"].string.isEmpty { Text(p["bio"].string).font(.inter(12.5)).foregroundColor(pal.ink2) }
                FlowWrap(spacing: 8) {
                    ForEach(Array(p["badges"].array.filter { $0["key"].string != "ai" }.enumerated()), id: \.offset) { _, b in
                        let key = b["key"].string
                        HStack(spacing: 6) {
                            if let ic = badgeIcon(key) { Icon(ic, 14) }
                            Text(prefs.t("pf_badge_\(key)", ["n": b["n"].string]))
                        }
                        .font(.inter(11.5, .medium)).foregroundColor(pal.gold)
                        .padding(.horizontal, 9).padding(.vertical, 3)
                        .background(RoundedRectangle(cornerRadius: 8).fill(pal.goldTint))
                    }
                    ForEach(p["tags"].array.map { $0.string }, id: \.self) { x in
                        Text(x).font(.inter(11.5, .medium)).foregroundColor(pal.gold)
                            .padding(.horizontal, 9).padding(.vertical, 3)
                            .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(pal.gold, lineWidth: 1))
                    }
                }
                HStack(spacing: 16) {
                    stat(p["following"].int, prefs.t("pf_followingN"))
                    stat(p["followers"].int, prefs.t("pf_followers"))
                    stat(p["likes"].int, prefs.t("pf_likes"))
                }
                if p["ai"].bool {
                    Text(prefs.t("pf_aiNote")).font(.inter(11.5)).foregroundColor(Color(hex: 0xa9b6ff))
                        .padding(.horizontal, 10).padding(.vertical, 8)
                        .background(RoundedRectangle(cornerRadius: 8).fill(Color(r: 120, g: 140, b: 255, a: 0.10)))
                }
            }
            .padding(.horizontal, 4).padding(.top, 8).padding(.bottom, 4)
            if !err.isEmpty { Text(prefs.t("err_\(err)")).font(.inter(12.5)).foregroundColor(pal.red) }
            Tabs(items: [("content", prefs.t("pf_content")), ("replies", prefs.t("pf_replies")), ("live", prefs.t("pf_live"))], value: $tab, size: 14)
                .padding(.horizontal, 4).padding(.top, 8)
                .frame(maxWidth: .infinity, alignment: .leading)
                .overlay(alignment: .bottom) { Hairline() }
                .padding(.bottom, 4)
            switch tab {
            case "content":
                let posts = feed?["posts"].array ?? []
                if posts.isEmpty { EmptyNote(text: prefs.t("pf_noPosts")) }
                ForEach(Array(posts.enumerated()), id: \.offset) { _, post in
                    PostCard(p: post, onOpen: { router.go(.community(post["id"].int)) }, onLike: { Task { await like(post["id"].int) } })
                }
            case "replies":
                let replies = feed?["replies"].array ?? []
                if replies.isEmpty { EmptyNote(text: prefs.t("pf_noPosts")) }
                ForEach(Array(replies.enumerated()), id: \.offset) { _, r in
                    Button { router.go(.community(r["postId"].int)) } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("\(prefs.t("pf_repliedTo")) 「\(r["postTitle"].string)」 · \(localDate(r["created"].string))").font(.inter(11.5)).foregroundColor(pal.muted)
                            Text(r["body"].string).font(.inter(13)).foregroundColor(pal.ink).multilineTextAlignment(.leading)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 2).padding(.vertical, 12)
                        .overlay(alignment: .bottom) { Hairline() }
                    }
                    .buttonStyle(PlainTap())
                }
            default:
                LivePanel(id: id, rev: rev, joinedDays: p["days"].int)
            }
        }
    }

    private func badgeIcon(_ key: String) -> Lucide? {
        switch key {
        case "live": return .radio
        case "active": return .flame
        case "days", "years": return .timer
        default: return nil
        }
    }

    private func stat(_ n: Int, _ label: String) -> some View {
        HStack(spacing: 2) {
            Text("\(n)").font(.inter(14, .semibold)).foregroundColor(pal.ink)
            Text(" \(label)").font(.inter(12)).foregroundColor(pal.muted)
        }
    }

    private func follow() async {
        guard session.me != nil else { router.open(.login); return }
        do { _ = try await API.shared.post("/users/\(id)/follow", [:]); rev += 1 } catch { err = (error as? APIError)?.code ?? "service_unavailable" }
    }

    private func like(_ postId: Int) async {
        guard session.me != nil else { router.open(.login); return }
        _ = try? await API.shared.post("/community/\(postId)/like", [:])
        rev += 1
    }
}

/// Live futures record (Profile.tsx LivePanel).
struct LivePanel: View {
    @Environment(Prefs.self) private var prefs
    @Environment(Router.self) private var router
    @Environment(\.pal) private var pal
    let id: Int
    let rev: Int
    let joinedDays: Int
    @State var days = "30"
    @State var view = "pnl"
    @State var list = "pos"
    @State var perf: JSON?
    @State var priv = false

    var body: some View {
        Group {
            if priv {
                VStack(spacing: 8) {
                    Icon(.lock, 22).foregroundColor(pal.muted)
                    Text(prefs.t("pf_private")).font(.inter(13)).foregroundColor(pal.muted)
                }
                .frame(maxWidth: .infinity).padding(.vertical, 14).card().padding(.top, 12)
            } else if let perf {
                panel(perf)
            } else {
                EmptyNote(text: prefs.t("connecting"))
            }
        }
        .task(id: "\(days)|\(rev)") {
            while !Task.isCancelled {
                do {
                    perf = try await API.shared.get("/users/\(id)/perf?days=\(days)")
                    priv = false
                } catch let e as APIError where e.status == 403 { priv = true } catch {}
                try? await Task.sleep(nanoseconds: 15_000_000_000)
            }
        }
    }

    private func panel(_ perf: JSON) -> some View {
        let series = perf["curve"].array.map { c in view == "ret" ? c["ret"].double : view == "pnl" ? c["pnl"].double : c["total"].double }
        let tr = perf["trader"]
        return VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 0) {
                Text(prefs.t("pf_perf")).font(.inter(14.5, .semibold)).foregroundColor(pal.ink).padding(.bottom, 8)
                LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], alignment: .leading, spacing: 12) {
                    cell(prefs.t("pf_cumRet"), prefs.signed(perf["ret"].double, 2, "%"), pal.dir(perf["ret"].double))
                    cell(prefs.t("pf_totalPnl"), prefs.signed(perf["pnl"].double), pal.dir(perf["pnl"].double))
                    cell(prefs.t("pf_assets"), prefs.num(perf["total"].double), nil)
                    cell(prefs.t("pf_days"), "\(joinedDays)", nil)
                    cell(prefs.t("pf_win"), "\(prefs.num(perf["winRate"].double, 2))%", nil)
                    cell(prefs.t("pf_mdd"), "\(prefs.num(perf["maxDrawdown"].double, 2))%", nil)
                    cell(prefs.t("pf_netIn"), prefs.num(perf["netIn"].double), nil)
                }
                .padding(.top, 4).padding(.bottom, 12)
                HStack {
                    PillTabs(items: [("ret", prefs.t("pf_ret")), ("pnl", prefs.t("pf_pnl")), ("total", prefs.t("pf_assetsShort"))], value: $view)
                    Spacer()
                    PillTabs(items: [("7", prefs.t("pf_d7")), ("30", prefs.t("pf_d30")), ("90", prefs.t("pf_d90"))], value: $days)
                }
                HStack(alignment: .firstTextBaseline) {
                    Text(prefs.t("pf_d\(days)")).font(.inter(11.5)).foregroundColor(pal.muted)
                    Spacer()
                    Text("\(prefs.signed(perf["rangePnl"].double)) USDT · \(prefs.signed(perf["rangeRet"].double, 2, "%"))")
                        .font(.inter(13, .semibold)).monospacedDigit().foregroundColor(pal.dir(perf["rangePnl"].double))
                }
                .padding(.top, 10).padding(.bottom, 4)
                PnlChart(values: series, zero: view != "total").frame(height: 180)
            }
            .card()
            VStack(alignment: .leading, spacing: 0) {
                Tabs(items: [("pos", "\(prefs.t("pf_positions")) (\(tr["positions"].array.count))"), ("hist", prefs.t("pf_history"))], value: $list)
                    .padding(.bottom, 6)
                if list == "pos" {
                    if tr["positions"].array.isEmpty { EmptyNote(text: prefs.t("pf_noPositions")) }
                    ForEach(Array(tr["positions"].array.enumerated()), id: \.offset) { i, x in position(x, first: i == 0) }
                } else {
                    if tr["closed"].array.isEmpty { EmptyNote(text: prefs.t("pf_noPositions")) }
                    ForEach(Array(tr["closed"].array.enumerated()), id: \.offset) { _, c in
                        let long = c["long"].bool, pd = c["priceDec"].int
                        HStack(spacing: 10) {
                            SideChip(long: long)
                            VStack(alignment: .leading, spacing: 0) {
                                Text(c["sym"].string).font(.inter(13, .semibold)).foregroundColor(pal.ink)
                                Text("\(prefs.num(c["entry"].double, pd)) → \(prefs.num(c["exit"].double, pd)) · \(localMs(c["t"].double))")
                                    .font(.inter(11.5)).foregroundColor(pal.muted).lineLimit(1)
                            }
                            Spacer()
                            Text(prefs.signed(c["pnl"].double)).font(.inter(13, .semibold)).monospacedDigit().foregroundColor(pal.dir(c["pnl"].double))
                        }
                        .padding(.vertical, 10)
                        .overlay(alignment: .top) { Hairline() }
                    }
                }
            }
            .card()
        }
        .padding(.top, 12)
    }

    private func localMs(_ ms: Double) -> String {
        let f = DateFormatter(); f.dateStyle = .short; f.timeStyle = .medium
        return f.string(from: Date(timeIntervalSince1970: ms / 1000))
    }

    private func cell(_ k: String, _ v: String, _ color: Color?) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(k).font(.inter(11.5)).foregroundColor(pal.muted).underline(pattern: .dot, color: pal.line)
            Text(v).font(.inter(15, .semibold)).monospacedDigit().foregroundColor(color ?? pal.ink).lineLimit(1).minimumScaleFactor(0.7)
        }
    }

    private func position(_ x: JSON, first: Bool) -> some View {
        let long = x["qty"].double > 0
        let up = x["upnl"].double
        let pd = x["priceDec"].int
        return VStack(alignment: .leading, spacing: 0) {
            HStack {
                FlowWrap(spacing: 6) {
                    SideChip(long: long)
                    Text(x["sym"].string).font(.inter(14, .semibold)).foregroundColor(pal.ink)
                    tag(prefs.t("pf_perp")); tag(prefs.t("pf_cross")); tag("\(x["lev"].int)x")
                }
                Spacer()
                Button(prefs.t("pf_trade")) { router.go(.trade(x["sym"].string)) }.btn(.gold, .sm)
            }
            HStack {
                big(prefs.t("pf_pnl") + " (USDT)", prefs.signed(up), pal.dir(up), right: false)
                Spacer()
                big(prefs.t("pf_roe"), prefs.signed(x["roe"].double, 2, "%"), pal.dir(up), right: true)
            }
            .padding(.top, 10)
            Grid(alignment: .leading, horizontalSpacing: 8, verticalSpacing: 8) {
                GridRow {
                    small("\(prefs.t("pf_qty")) (\(x["base"].string))", prefs.num(abs(x["qty"].double), max(0, x["qtyDec"].int)))
                    small(prefs.t("pf_margin"), prefs.num(x["margin"].double))
                    small(prefs.t("pf_marginRatio"), "\(prefs.num(x["marginRatio"].double, 2))%", right: true)
                }
                GridRow {
                    small(prefs.t("pf_entry"), prefs.num(x["entry"].double, pd))
                    small(prefs.t("pf_mark"), prefs.num(x["mark"].double, pd))
                    small(prefs.t("pf_liq"), x["liq"].double > 0 ? prefs.num(x["liq"].double, pd) : "—", right: true)
                }
            }
            .padding(.top, 10)
        }
        .padding(.vertical, 12)
        .overlay(alignment: .top) { if !first { Hairline() } }
    }

    private func tag(_ s: String) -> some View {
        Text(s).font(.inter(12)).foregroundColor(pal.ink2).padding(.horizontal, 7).padding(.vertical, 1)
            .background(RoundedRectangle(cornerRadius: 4).fill(pal.surface2))
    }

    private func big(_ k: String, _ v: String, _ c: Color, right: Bool) -> some View {
        VStack(alignment: right ? .trailing : .leading, spacing: 3) {
            Text(k).font(.inter(11)).foregroundColor(pal.muted)
            Text(v).font(.inter(16, .semibold)).monospacedDigit().foregroundColor(c)
        }
    }

    private func small(_ k: String, _ v: String, right: Bool = false) -> some View {
        VStack(alignment: right ? .trailing : .leading, spacing: 3) {
            Text(k).font(.inter(11)).foregroundColor(pal.muted).lineLimit(1)
            Text(v).font(.inter(13, .medium)).monospacedDigit().foregroundColor(pal.ink).lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: right ? .trailing : .leading)
    }
}

/// B / S chip (.side-chip).
struct SideChip: View {
    @Environment(\.pal) private var pal
    let long: Bool
    var body: some View {
        Text(long ? "B" : "S").font(.inter(11, .bold)).foregroundColor(long ? pal.green : pal.red)
            .frame(width: 18, height: 18)
            .background(RoundedRectangle(cornerRadius: 4).fill(long ? pal.greenTint : pal.redTint))
    }
}
