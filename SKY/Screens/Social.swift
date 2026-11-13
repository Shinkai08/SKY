import SwiftUI

func authorFrom(_ j: JSON, fallbackId: Int = 0) -> Author {
    guard j.exists else { return Author(id: fallbackId, nick: "SKY #\(fallbackId)") }
    var a = Author(j)
    if a.nick.isEmpty { a.nick = "SKY #\(fallbackId)" }
    return a
}

func localDate(_ iso: String) -> String {
    let f = ISO8601DateFormatter()
    f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    guard let d = f.date(from: iso) ?? ISO8601DateFormatter().date(from: iso) else { return iso }
    let o = DateFormatter()
    o.dateStyle = .short; o.timeStyle = .medium
    return o.string(from: d)
}

struct AIBadge: View {
    @Environment(Prefs.self) private var prefs
    var small = false
    var body: some View {
        HStack(spacing: small ? 2 : 4) {
            Icon(.bot, small ? 11 : 13)
            Text(small ? "AI" : prefs.t("pf_badge_ai"))
        }
        .font(.inter(small ? 10.5 : 12, .semibold))
        .foregroundColor(Color(hex: 0x8fa2ff))
        .padding(.horizontal, small ? 6 : 8).padding(.vertical, small ? 0 : 2)
        .background(Capsule().fill(Color(r: 120, g: 140, b: 255, a: 0.14)))
    }
}

struct VerifiedMark: View {
    @Environment(\.pal) private var pal
    var size: CGFloat = 16
    var body: some View {
        ZStack {
            Icon(.badgeCheck, size, filled: true).foregroundColor(pal.goldTint)
            Icon(.badgeCheck, size).foregroundColor(pal.gold)
        }
    }
}

/// Avatar + nickname + badges (Social.tsx AuthorLine).
struct AuthorLine: View {
    @Environment(Router.self) private var router
    @Environment(\.pal) private var pal
    let a: Author
    let id: Int
    var sub: String?
    var body: some View {
        Button { router.go(.profile(id)) } label: {
            HStack(spacing: 10) {
                AvatarView(a: a, size: 32)
                FlowWrap(spacing: 4) {
                    Text(a.nick).font(.inter(13, .semibold)).foregroundColor(pal.ink).lineLimit(1)
                    if a.verified { VerifiedMark(size: 14) }
                    if a.ai { AIBadge(small: true) }
                    if let sub { Text(sub).font(.inter(11.5)).foregroundColor(pal.muted) }
                }
            }
            .padding(.vertical, 6)
        }
        .buttonStyle(PlainTap())
    }
}

/// Area line chart, green above zero and red below (Social.tsx PnlChart).
struct PnlChart: View {
    @Environment(\.pal) private var pal
    let values: [Double]
    var zero = true
    var label: String?
    var body: some View {
        Canvas { ctx, s in
            guard values.count >= 2 else { return }
            let W = s.width, H = s.height, pad = 6.0
            let lo = min(values.min() ?? 0, zero ? 0 : .infinity), hi = max(values.max() ?? 0, zero ? 0 : -.infinity)
            let span = hi - lo == 0 ? 1 : hi - lo
            func x(_ i: Int) -> Double { pad + Double(i) / Double(values.count - 1) * (W - 2 * pad) }
            func y(_ v: Double) -> Double { pad + (1 - (v - lo) / span) * (H - 2 * pad) }
            var line = Path()
            for (i, v) in values.enumerated() { if i == 0 { line.move(to: CGPoint(x: x(i), y: y(v))) } else { line.addLine(to: CGPoint(x: x(i), y: y(v))) } }
            let base = zero ? y(0) : H - pad
            let zy = max(pad, min(H - pad, base))
            let split = Gradient(stops: [.init(color: pal.green, location: zy / H), .init(color: pal.red, location: zy / H)])
            if zero {
                ctx.stroke(Path { p in p.move(to: CGPoint(x: 0, y: zy)); p.addLine(to: CGPoint(x: W, y: zy)) },
                           with: .color(pal.line), style: StrokeStyle(lineWidth: 1, dash: [4, 4]))
            }
            var area = line
            area.addLine(to: CGPoint(x: x(values.count - 1), y: zy))
            area.addLine(to: CGPoint(x: x(0), y: zy))
            area.closeSubpath()
            var faint = ctx
            faint.opacity = 0.14
            faint.fill(area, with: .linearGradient(split, startPoint: .zero, endPoint: CGPoint(x: 0, y: H)))
            ctx.stroke(line, with: .linearGradient(split, startPoint: .zero, endPoint: CGPoint(x: 0, y: H)), style: StrokeStyle(lineWidth: 2, lineJoin: .round))
            if let label {
                ctx.draw(Text(label).font(.inter(11)).foregroundColor(pal.muted), at: CGPoint(x: W - 4, y: 14), anchor: .bottomTrailing)
            }
        }
    }
}

/// Return card attached to a post (Social.tsx PnlCard).
struct PnlCardView: View {
    @Environment(Prefs.self) private var prefs
    @Environment(\.pal) private var pal
    let c: JSON
    var body: some View {
        let ret = c["ret"].double
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 0) {
                    Text(prefs.t("pf_card", ["n": "\(c["days"].int)"])).font(.inter(11.5)).foregroundColor(pal.muted)
                    Text(prefs.signed(ret, 2, "%")).font(.inter(21, .bold)).monospacedDigit().foregroundColor(pal.dir(ret))
                }
                Spacer()
                Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 2) {
                    GridRow {
                        Text(prefs.t("pf_pnl")).foregroundColor(pal.muted)
                        Text("\(prefs.signed(c["pnl"].double)) USDT").foregroundColor(pal.dir(ret)).gridColumnAlignment(.trailing)
                    }
                    GridRow {
                        Text(prefs.t("pf_win")).foregroundColor(pal.muted)
                        Text("\(prefs.num(c["winRate"].double, 1))%").foregroundColor(pal.ink)
                    }
                    GridRow {
                        Text(prefs.t("pf_mdd")).foregroundColor(pal.muted)
                        Text("\(prefs.num(c["maxDrawdown"].double, 2))%").foregroundColor(pal.ink)
                    }
                }
                .font(.inter(12)).monospacedDigit().lineLimit(1)
            }
            PnlChart(values: c["curve"].array.map { $0.double }).frame(height: 90)
            if !c["position"].string.isEmpty {
                Text(c["position"].string).font(.inter(11.5)).foregroundColor(pal.ink2)
                    .padding(.horizontal, 8).padding(.vertical, 2)
                    .background(RoundedRectangle(cornerRadius: 6).fill(pal.surface))
            }
        }
        .padding(.horizontal, 12).padding(.vertical, 10)
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: 10).fill(pal.surface2)
                RoundedRectangle(cornerRadius: 10).fill(LinearGradient(stops: [.init(color: pal.goldTint, location: 0), .init(color: .clear, location: 0.55)], startPoint: .topLeading, endPoint: .bottomTrailing))
            }
        )
        .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(pal.line, lineWidth: 1))
        .padding(.vertical, 10)
    }
}

/// Feed post (Social.tsx PostCard).
struct PostCard: View {
    @Environment(\.pal) private var pal
    let p: JSON
    var onOpen: (() -> Void)?
    var onLike: (() -> Void)?
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            AuthorLine(a: authorFrom(p["authorInfo"], fallbackId: p["author"].int), id: p["author"].int, sub: "· \(localDate(p["created"].string))")
            Text(p["title"].string).font(.inter(14.5, .semibold)).foregroundColor(pal.ink).padding(.top, 2).padding(.bottom, 6)
            Text(p["body"].string).font(.inter(13)).foregroundColor(pal.ink2).lineLimit(6)
            if p["card"].exists { PnlCardView(c: p["card"]) }
            HStack(spacing: 28) {
                HStack(spacing: 6) { Icon(.messageCircle, 16); Text("\(p["replyCount"].int)") }
                Button { onLike?() } label: {
                    HStack(spacing: 6) { Icon(.heart, 16, filled: p["liked"].bool); Text("\(p["likes"].int)") }
                        .foregroundColor(p["liked"].bool ? pal.red : pal.muted)
                }
                .buttonStyle(PlainTap()).disabled(onLike == nil)
            }
            .font(.inter(13)).foregroundColor(pal.muted)
            .padding(.top, 8)
        }
        .padding(.horizontal, 2).padding(.vertical, 12)
        .contentShape(Rectangle())
        .onTapGesture { onOpen?() }
        .overlay(alignment: .bottom) { Hairline() }
    }
}
