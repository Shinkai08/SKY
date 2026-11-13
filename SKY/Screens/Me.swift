import SwiftUI
import PhotosUI
import AVFoundation
import CoreImage.CIFilterBuiltins

/// components/Me.tsx: the personal center that slides in from the left, with its own page stack.
struct MeDrawer: View {
    @Environment(Prefs.self) private var prefs
    @Environment(Session.self) private var session
    @Environment(Router.self) private var router
    @Environment(\.pal) private var pal
    @State private var stack: [String] = ["center"]
    @State private var info: JSON?
    @State private var gift: JSON?

    var body: some View {
        ZStack {
            ForEach(Array(stack.enumerated()), id: \.offset) { i, p in
                page(p)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                    .background(pal.bg.ignoresSafeArea())
                    .transition(.move(edge: .trailing))
                    .zIndex(Double(i))
            }
        }
        .animation(.easeOut(duration: 0.28), value: stack.count)
        .background(pal.bg.ignoresSafeArea())
        .task {
            if let p = router.mePage, p != "center" { stack = ["center", p] }
            await load()
        }
    }

    private func load() async {
        info = try? await API.shared.get("/me/center")
        gift = try? await API.shared.get("/welcome-gift")
    }

    private func push(_ p: String) { stack.append(p) }
    private func back() { if stack.count > 1 { stack.removeLast() } else { router.meOpen = false } }

    @ViewBuilder private func page(_ p: String) -> some View {
        switch p {
        case "account": AccountPage(info: info, back: back, go: push)
        case "coupons": CouponsPage(gift: gift, back: back) { Task { await load() } }
        case "qr": QrPage(info: info, back: back)
        case "scan": ScanPage(back: back)
        case "support": MeSimplePage(icon: .headset, title: prefs.t("me_support"), heading: prefs.t("me_supportTitle"),
                                     message: prefs.t("me_supportBody"), back: back, action: (prefs.t("community"), { router.go(.community(nil)) }))
        case "soon": MeSimplePage(icon: .gift, title: nil, heading: prefs.t("me_soon"), message: prefs.t("me_soonBody"), back: back, action: nil)
        default: CenterPage(info: info, gift: gift, back: back, go: push) { Task { await load() } }
        }
    }
}

/// .me-bar
struct MeBar<Right: View>: View {
    @Environment(\.pal) private var pal
    var title: String?
    let back: () -> Void
    @ViewBuilder var right: () -> Right
    var body: some View {
        HStack(spacing: 8) {
            IconButton(.arrowLeft, size: 22, color: pal.ink2, action: back)
            Spacer(minLength: 0)
            if let title { Text(title).font(.inter(18, .semibold)).foregroundColor(pal.ink).lineLimit(1) }
            Spacer(minLength: 0)
            HStack(spacing: 2) { right() }.frame(minWidth: 40, alignment: .trailing)
        }
        .padding(.horizontal, 12).padding(.vertical, 10)
    }
}

extension MeBar where Right == EmptyView {
    init(title: String? = nil, back: @escaping () -> Void) {
        self.title = title; self.back = back; self.right = { EmptyView() }
    }
}

private func meLevel(_ info: JSON?) -> Int {
    if let v = info?["vip"], v.exists { return v.int }
    return VIP.tierFor(spot: true, assets: info?["total"].double ?? 0, volume: 0).level
}

private func authorOf(_ info: JSON?) -> Author {
    guard let i = info else { return Author(nick: "?") }
    return Author(id: i["id"].int, nick: i["nick"].string, avatar: i["avatar"].string, frame: i["frame"].string, photo: i["photo"].string)
}

struct CopyIdButton: View {
    @Environment(Prefs.self) private var prefs
    @Environment(\.pal) private var pal
    let text: String
    @State var done = false
    var body: some View {
        Button {
            UIPasteboard.general.string = text
            done = true
            Haptic.success()
        } label: {
            if done { Text(prefs.t("copied")).font(.inter(11.5)).foregroundColor(pal.gold) } else { Icon(.copy, 15).foregroundColor(pal.muted) }
        }
        .buttonStyle(PlainTap())
        .padding(2)
        .task(id: done) {
            guard done else { return }
            try? await Task.sleep(nanoseconds: 1_200_000_000)
            done = false
        }
    }
}

struct CenterPage: View {
    @Environment(Prefs.self) private var prefs
    @Environment(Router.self) private var router
    @Environment(\.pal) private var pal
    let info: JSON?
    let gift: JSON?
    let back: () -> Void
    let go: (String) -> Void
    let reload: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            MeBar(back: back) {
                IconButton(.qrCode, size: 21) { go("qr") }
                IconButton(.scanLine, size: 21) { go("scan") }
                IconButton(.settings, size: 21) { router.go(.settings) }
            }
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    Button { go("account") } label: {
                        HStack(spacing: 14) {
                            AvatarView(a: authorOf(info), size: 72)
                            VStack(alignment: .leading, spacing: 4) {
                                Text(info?["nick"].string ?? "…").font(.inter(22, .bold)).foregroundColor(pal.ink).lineLimit(1)
                                HStack(spacing: 6) {
                                    Text("ID: \(info.map { "\($0["id"].int)" } ?? "—")").font(.inter(12.5)).foregroundColor(pal.muted)
                                    if let info { CopyIdButton(text: "\(info["id"].int)") }
                                }
                                MeBadges(info: info)
                            }
                            Spacer(minLength: 0)
                            Icon(.chevronRight, 20).foregroundColor(pal.muted)
                        }
                        .padding(.vertical, 6)
                    }
                    .buttonStyle(PlainTap())

                    HStack(spacing: 12) {
                        Icon(.headset, 20).foregroundColor(pal.gold).frame(width: 34, height: 34).background(Circle().fill(pal.goldTint))
                        Text(prefs.t("me_support")).font(.inter(13, .semibold)).foregroundColor(pal.ink)
                        Spacer()
                        Button(prefs.t("me_getSupport")) { go("support") }.btn(.plain, .sm)
                    }
                    .padding(.horizontal, 16).padding(.vertical, 14)
                    .background(RoundedRectangle(cornerRadius: 16).fill(pal.surface))

                    HStack(spacing: 12) {
                        tile(.usersRound, prefs.t("me_invite"), prefs.t("me_inviteSub"))
                        tile(.sparkles, prefs.t("me_guess"), prefs.t("me_guessSub"))
                    }

                    VStack(alignment: .leading, spacing: 12) {
                        cardHead(prefs.t("me_coupons")) { go("coupons") }
                        CouponSummary(gift: gift)
                        if let gift, gift["enabled"].bool { WelcomeCoupon(gift: gift, compact: true, onUse: reload) }
                    }
                    .padding(16)
                    .background(RoundedRectangle(cornerRadius: 16).fill(pal.surface))

                    VStack(alignment: .leading, spacing: 12) {
                        cardHead(prefs.t("me_tasks")) { go("soon") }
                        HStack(spacing: 10) {
                            Icon(.listChecks, 22).foregroundColor(pal.gold)
                            Text(prefs.t("me_tasksSub")).font(.inter(12.5)).foregroundColor(pal.muted)
                            Spacer()
                            SoonBadge()
                        }
                    }
                    .padding(16)
                    .background(RoundedRectangle(cornerRadius: 16).fill(pal.surface))
                }
                .padding(.horizontal, 16).padding(.top, 4).padding(.bottom, 28)
            }
        }
    }

    private func tile(_ icon: Lucide, _ label: String, _ sub: String) -> some View {
        Button { go("soon") } label: {
            VStack(alignment: .leading, spacing: 6) {
                Icon(icon, 30, stroke: 1.5).foregroundColor(pal.gold)
                Spacer(minLength: 0)
                Text(label).font(.inter(12.5)).foregroundColor(pal.muted)
                Text(sub).font(.inter(15, .semibold)).foregroundColor(pal.ink).multilineTextAlignment(.leading)
            }
            .padding(16)
            .frame(maxWidth: .infinity, minHeight: 150, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 16).fill(pal.surface))
            .overlay(alignment: .topTrailing) { SoonBadge().padding(12) }
        }
        .buttonStyle(PlainTap())
    }

    private func cardHead(_ title: String, _ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack {
                Text(title).font(.inter(16)).foregroundColor(pal.muted)
                Spacer()
                Icon(.chevronRight, 18).foregroundColor(pal.muted)
            }
        }
        .buttonStyle(PlainTap())
    }
}

struct SoonBadge: View {
    @Environment(Prefs.self) private var prefs
    @Environment(\.pal) private var pal
    var body: some View {
        Text(prefs.t("me_soon")).font(.inter(11)).foregroundColor(pal.gold)
            .padding(.horizontal, 8).padding(.vertical, 1)
            .overlay(Capsule().strokeBorder(pal.gold, lineWidth: 1))
    }
}

struct MeBadges: View {
    @Environment(Prefs.self) private var prefs
    @Environment(\.pal) private var pal
    let info: JSON?
    var body: some View {
        let kyc = info?["kyc"].bool ?? false
        HStack(spacing: 6) {
            HStack(spacing: 4) {
                if kyc { Icon(.badgeCheck, 13) }
                Text(prefs.t(kyc ? "me_kycYes" : "me_kycNo"))
            }
            .foregroundColor(kyc ? pal.green : pal.muted)
            .padding(.horizontal, 10).frame(height: 24)
            .background(RoundedRectangle(cornerRadius: 7).fill(kyc ? pal.greenTint : pal.surface2))
            Text(tierName(meLevel(info), prefs)).foregroundColor(pal.ink)
                .padding(.horizontal, 10).frame(height: 24)
                .background(RoundedRectangle(cornerRadius: 7).fill(pal.surface2))
        }
        .font(.inter(12.5))
    }
}

struct AccountPage: View {
    @Environment(Prefs.self) private var prefs
    @Environment(Session.self) private var session
    @Environment(Router.self) private var router
    @Environment(\.pal) private var pal
    let info: JSON?
    let back: () -> Void
    let go: (String) -> Void
    @State var showMail = false

    var body: some View {
        let mail = info?["email"].string ?? ""
        let masked = mail.replacingOccurrences(of: "^(.{2})[^@]*(@.*)$", with: "$1***$2", options: .regularExpression)
        let kyc = info?["kyc"].bool ?? false
        VStack(spacing: 0) {
            MeBar(title: prefs.t("me_account"), back: back) {
                IconButton(.userRoundCog, size: 21) { router.go(.settings) }
            }
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    VStack(alignment: .leading, spacing: 16) {
                        HStack(spacing: 10) {
                            Button { router.go(.settings) } label: {
                                AvatarView(a: authorOf(info), size: 64)
                                    .overlay(alignment: .bottomTrailing) {
                                        Icon(.pencil, 12).foregroundColor(pal.bg).frame(width: 22, height: 22)
                                            .background(Circle().fill(pal.ink)).offset(x: 2, y: 2)
                                    }
                            }
                            .buttonStyle(PlainTap())
                            Text(info?["nick"].string ?? "").font(.inter(22, .bold)).foregroundColor(pal.ink).lineLimit(1)
                        }
                        Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 12) {
                            GridRow {
                                Text(prefs.t("me_uid")).foregroundColor(pal.muted)
                                HStack(spacing: 6) {
                                    Spacer(minLength: 0)
                                    Text("\(info?["id"].int ?? 0)").monospacedDigit().foregroundColor(pal.ink)
                                    if let info { CopyIdButton(text: "\(info["id"].int)") }
                                }
                            }
                            GridRow {
                                Text(prefs.t("me_regInfo")).foregroundColor(pal.muted)
                                HStack(spacing: 6) {
                                    Spacer(minLength: 0)
                                    Text(showMail ? mail : masked).foregroundColor(pal.ink).lineLimit(1).minimumScaleFactor(0.7)
                                    Button { showMail.toggle() } label: { Icon(showMail ? .eyeOff : .eye, 15).foregroundColor(pal.muted) }
                                        .buttonStyle(PlainTap())
                                }
                            }
                        }
                        .font(.inter(13))
                    }
                    .padding(.horizontal, 18).padding(.vertical, 20)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .overlay(RoundedRectangle(cornerRadius: 18).strokeBorder(pal.line, lineWidth: 1))
                    .overlay(alignment: .topTrailing) {
                        Text(tierName(meLevel(info), prefs)).font(.inter(12.5)).foregroundColor(pal.ink)
                            .padding(.horizontal, 12).padding(.vertical, 5)
                            .background(UnevenRoundedRectangle(bottomLeadingRadius: 12, topTrailingRadius: 18).fill(pal.surface2))
                    }
                    VStack(spacing: 0) {
                        listRow(.badgeCheck, prefs.t("me_kycCenter"), value: prefs.t(kyc ? "me_kycYes" : "me_kycNo"), valueColor: kyc ? pal.green : pal.muted) { go("soon") }
                        listRow(.shieldCheck, prefs.t("me_security")) { router.go(.settings) }
                        listRow(.link2, prefs.t("me_social")) { go("soon") }
                        listRow(.usersRound, prefs.t("me_sub")) { go("soon") }
                    }
                    Button {
                        Task { await session.logout(); router.go(.home) }
                    } label: {
                        Text(prefs.t("me_logout")).font(.inter(17, .semibold)).foregroundColor(pal.ink)
                            .frame(maxWidth: .infinity).frame(height: 50)
                            .background(RoundedRectangle(cornerRadius: 8).fill(pal.surface2))
                    }
                    .buttonStyle(PlainTap())
                    .padding(.top, 24)
                }
                .padding(.horizontal, 16).padding(.top, 4).padding(.bottom, 28)
            }
        }
    }

    private func listRow(_ icon: Lucide, _ label: String, value: String = "", valueColor: Color? = nil, _ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Icon(icon, 20).foregroundColor(pal.ink)
                Text(label).font(.inter(17)).foregroundColor(pal.ink)
                Spacer()
                if !value.isEmpty { Text(value).font(.inter(15)).foregroundColor(valueColor ?? pal.muted) }
                Icon(.chevronRight, 18).foregroundColor(pal.muted)
            }
            .padding(.horizontal, 2).padding(.vertical, 18)
        }
        .buttonStyle(PlainTap())
    }
}

// MARK: coupons

struct VLine: Shape {
    func path(in r: CGRect) -> Path { Path { p in p.move(to: CGPoint(x: r.midX, y: 0)); p.addLine(to: CGPoint(x: r.midX, y: r.height)) } }
}

struct CouponSummary: View {
    @Environment(Prefs.self) private var prefs
    @Environment(\.pal) private var pal
    let gift: JSON?
    var body: some View {
        let got = gift?["enabled"].bool == true ? 1 : 0
        let used = gift?["claimed"].bool == true ? 1 : 0
        HStack(spacing: 10) {
            (Text("\(prefs.t("me_totalReward")) ").foregroundColor(pal.muted)
             + Text("\(prefs.num(used == 1 ? gift?["amount"].double ?? 0 : 0, 0)) USDT").font(.inter(12.5, .semibold)).foregroundColor(pal.ink))
            Rectangle().fill(pal.line).frame(width: 1, height: 12)
            (Text("\(prefs.t("me_used")) ").foregroundColor(pal.muted) + Text("\(used)").font(.inter(12.5, .semibold)).foregroundColor(pal.ink))
            Rectangle().fill(pal.line).frame(width: 1, height: 12)
            (Text("\(prefs.t("me_received")) ").foregroundColor(pal.muted) + Text("\(got)").font(.inter(12.5, .semibold)).foregroundColor(pal.ink))
        }
        .font(.inter(12.5))
        .lineLimit(1)
    }
}

/// Ticket-shaped coupon with notches (.coupon).
struct WelcomeCoupon: View {
    @Environment(Prefs.self) private var prefs
    @Environment(\.pal) private var pal
    let gift: JSON
    var compact = false
    var onUse: (() -> Void)?
    var notchColor: Color?
    @State var busy = false

    var body: some View {
        let claimed = gift["claimed"].bool
        let left: CGFloat = compact ? 84 : 96
        HStack(spacing: 14) {
            VStack(spacing: 0) {
                Text("\(gift["amount"].int)").font(.inter(30, .bold)).foregroundColor(pal.gold)
                Text("USDT").font(.inter(12)).foregroundColor(pal.gold)
            }
            .frame(width: left)
            .overlay(alignment: .trailing) {
                VLine().stroke(Color(r: 217, g: 181, b: 96, a: 0.45), style: StrokeStyle(lineWidth: 1, dash: [3, 3]))
                    .frame(width: 1)
            }
            VStack(alignment: .leading, spacing: 3) {
                Text(prefs.t("me_couponWelcome")).font(.inter(15, .semibold)).foregroundColor(pal.ink)
                Text(prefs.t("me_couponWelcomeDesc")).font(.inter(11.5)).foregroundColor(pal.muted)
                Text(prefs.t("me_noExpiry")).font(.inter(11.5)).foregroundColor(pal.muted)
            }
            Spacer(minLength: 0)
            if claimed {
                Text(prefs.t("me_used")).font(.inter(12)).foregroundColor(pal.muted)
                    .padding(.horizontal, 8).padding(.vertical, 3)
                    .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(pal.line, lineWidth: 1))
                    .rotationEffect(.degrees(-8))
            } else {
                Button(prefs.t("me_use")) {
                    Task {
                        busy = true
                        _ = try? await API.shared.post("/welcome-gift/claim", [:])
                        busy = false
                        onUse?()
                    }
                }
                .btn(.gold, .sm).frame(minWidth: 64).disabled(busy)
            }
        }
        .padding(.vertical, 14).padding(.trailing, 16)
        .background(
            ZStack {
                pal.surface2
                LinearGradient(stops: [.init(color: pal.goldTint, location: 0), .init(color: .clear, location: 0.7)], startPoint: .leading, endPoint: .trailing)
            }
        )
        .overlay(alignment: .topLeading) { Circle().fill(notchColor ?? pal.surface).frame(width: 12, height: 12).offset(x: left - 6, y: -6) }
        .overlay(alignment: .bottomLeading) { Circle().fill(notchColor ?? pal.surface).frame(width: 12, height: 12).offset(x: left - 6, y: 6) }
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .grayscale(claimed ? 0.9 : 0).opacity(claimed ? 0.7 : 1)
    }
}

struct CouponsPage: View {
    @Environment(Prefs.self) private var prefs
    @Environment(\.pal) private var pal
    let gift: JSON?
    let back: () -> Void
    let onChange: () -> Void
    @State var tab = 0

    var body: some View {
        let list: [JSON] = gift?["enabled"].bool == true ? [gift!] : []
        let shown = list.filter { (tab == 1) == $0["claimed"].bool }
        VStack(spacing: 0) {
            MeBar(title: prefs.t("me_coupons"), back: back)
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    CouponSummary(gift: gift).padding(16).frame(maxWidth: .infinity, alignment: .leading)
                        .background(RoundedRectangle(cornerRadius: 16).fill(pal.surface))
                    HStack(spacing: 0) {
                        ForEach(0..<2, id: \.self) { i in
                            Button { tab = i } label: {
                                Text(prefs.t(i == 0 ? "me_available" : "me_used")).font(.inter(13))
                                    .foregroundColor(tab == i ? pal.ink : pal.muted)
                                    .frame(maxWidth: .infinity).frame(height: 32)
                                    .background(RoundedRectangle(cornerRadius: 8).fill(tab == i ? pal.surface : .clear))
                            }
                            .buttonStyle(PlainTap())
                        }
                    }
                    .padding(3)
                    .background(RoundedRectangle(cornerRadius: 10).fill(pal.surface2))
                    if shown.isEmpty {
                        VStack(spacing: 10) {
                            Icon(.ticket, 40, stroke: 1.2).foregroundColor(pal.muted)
                            Text(prefs.t("me_noCoupons")).font(.inter(12.5)).foregroundColor(pal.muted)
                        }
                        .frame(maxWidth: .infinity).padding(.vertical, 40)
                    } else {
                        ForEach(shown.indices, id: \.self) { i in WelcomeCoupon(gift: shown[i], onUse: onChange, notchColor: pal.bg) }
                    }
                    Text(prefs.t("me_couponRule")).font(.inter(11.5)).foregroundColor(pal.muted)
                }
                .padding(.horizontal, 16).padding(.top, 4).padding(.bottom, 28)
            }
        }
    }
}

// MARK: QR code

/// QR module matrix from Core Image (dark = true), without the quiet zone.
enum QRMatrix {
    static func make(_ text: String, level: String = "H") -> [[Bool]] {
        let f = CIFilter.qrCodeGenerator()
        f.message = Data(text.utf8)
        f.correctionLevel = level
        guard let img = f.outputImage, let cg = CIContext().createCGImage(img, from: img.extent) else { return [] }
        let w = cg.width, h = cg.height
        var px = [UInt8](repeating: 255, count: w * h)
        let drawn: Bool = px.withUnsafeMutableBytes { buf in
            guard let ctx = CGContext(data: buf.baseAddress, width: w, height: h, bitsPerComponent: 8, bytesPerRow: w,
                                      space: CGColorSpaceCreateDeviceGray(), bitmapInfo: CGImageAlphaInfo.none.rawValue) else { return false }
            ctx.draw(cg, in: CGRect(x: 0, y: 0, width: w, height: h))
            return true
        }
        guard drawn else { return [] }
        var minX = w, minY = h, maxX = -1, maxY = -1
        for y in 0..<h { for x in 0..<w where px[y * w + x] < 128 {
            minX = min(minX, x); maxX = max(maxX, x); minY = min(minY, y); maxY = max(maxY, y)
        } }
        guard maxX >= minX else { return [] }
        return (minY...maxY).map { y in (minX...maxX).map { x in px[y * w + x] < 128 } }
    }
}

/// SkyQR.tsx: soft modules, rounded eyes with gold pupils, the emblem in the middle.
struct SkyQRView: View {
    let text: String
    var size: CGFloat = 232
    var body: some View {
        let m = QRMatrix.make(text)
        let n = m.count
        Canvas { ctx, s in
            guard n > 0 else { return }
            let q = 2.0, V = Double(n) + 2 * q
            let k = s.width / V
            ctx.fill(Path(roundedRect: CGRect(origin: .zero, size: s), cornerRadius: 2.5 * k), with: .color(.white))
            let logoN = Int(ceil(Double(n) * 0.22))
            let lo = (n - logoN) / 2, hi = lo + logoN
            func finder(_ r: Int, _ c: Int) -> Bool { (r < 7 && c < 7) || (r < 7 && c >= n - 7) || (r >= n - 7 && c < 7) }
            for r in 0..<n { for c in 0..<n where m[r][c] && !finder(r, c) && !(r >= lo && r < hi && c >= lo && c < hi) {
                let rect = CGRect(x: (Double(c) + q + 0.04) * k, y: (Double(r) + q + 0.04) * k, width: 0.92 * k, height: 0.92 * k)
                ctx.fill(Path(roundedRect: rect, cornerRadius: 0.3 * k), with: .color(Color(hex: 0x14161a)))
            } }
            let gold = Gradient(stops: [.init(color: Color(hex: 0x9a7428), location: 0), .init(color: Color(hex: 0x7d5c1c), location: 0.55), .init(color: Color(hex: 0x5c4210), location: 1)])
            for (x, y) in [(0, 0), (n - 7, 0), (0, n - 7)] {
                let ox = (Double(x) + q) * k, oy = (Double(y) + q) * k
                ctx.stroke(Path(roundedRect: CGRect(x: ox + 0.5 * k, y: oy + 0.5 * k, width: 6 * k, height: 6 * k), cornerRadius: 1.6 * k),
                           with: .color(Color(hex: 0x14161a)), lineWidth: k)
                let pupil = CGRect(x: ox + 2 * k, y: oy + 2 * k, width: 3 * k, height: 3 * k)
                ctx.fill(Path(roundedRect: pupil, cornerRadius: 0.8 * k),
                         with: .linearGradient(gold, startPoint: pupil.origin, endPoint: CGPoint(x: pupil.maxX, y: pupil.maxY)))
            }
            let logo = Double(n) * 0.2
            let lx = (Double(n) - logo) / 2 + q
            ctx.fill(Path(roundedRect: CGRect(x: (lx - 0.6) * k, y: (lx - 0.6) * k, width: (logo + 1.2) * k, height: (logo + 1.2) * k), cornerRadius: 1.6 * k), with: .color(.white))
            if let emblem = WebImage.load("vip-cards-emblem.png") {
                ctx.draw(Image(uiImage: emblem).resizable(), in: CGRect(x: lx * k, y: lx * k, width: logo * k, height: logo * k))
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .padding(6)
        .background(RoundedRectangle(cornerRadius: 18).fill(.white))
        .shadow(color: .black.opacity(0.35), radius: 15, x: 0, y: 10)
    }
}

struct QrPage: View {
    @Environment(Prefs.self) private var prefs
    @Environment(\.pal) private var pal
    let info: JSON?
    let back: () -> Void
    @State var copied = false
    @State var saved = false

    var body: some View {
        let link = info.map { "\(API.site.absoluteString)/#/k7bg/\($0["id"].int)" } ?? ""
        VStack(spacing: 0) {
            MeBar(title: prefs.t("me_qrTitle"), back: back)
            ScrollView {
                VStack(spacing: 14) {
                    VStack(spacing: 16) {
                        HStack(spacing: 10) {
                            AvatarView(a: authorOf(info), size: 48)
                            VStack(alignment: .leading, spacing: 0) {
                                Text(info?["nick"].string ?? "").font(.inter(13, .semibold)).foregroundColor(pal.ink)
                                Text("SKY ID \(info?["id"].int ?? 0)").font(.inter(11.5)).foregroundColor(pal.muted)
                            }
                            Spacer()
                        }
                        if !link.isEmpty { SkyQRView(text: link) }
                        Text(prefs.t("me_qrHint")).font(.inter(12.5)).foregroundColor(pal.muted).multilineTextAlignment(.center)
                        HStack(spacing: 6) {
                            WebImg(name: "vip-cards-emblem.png", mode: .fit).frame(width: 18, height: 18)
                            Text("SKYLINE EXCHANGE").font(.inter(11)).tracking(11 * 0.14).foregroundColor(pal.gold)
                        }
                    }
                    .padding(.horizontal, 18).padding(.vertical, 22)
                    .background(
                        ZStack {
                            RoundedRectangle(cornerRadius: 20).fill(pal.surface)
                            RoundedRectangle(cornerRadius: 20).fill(RadialGradient(colors: [Color(r: 217, g: 181, b: 96, a: 0.22), .clear], center: .topLeading, startRadius: 0, endRadius: 300))
                        }
                    )
                    .overlay(RoundedRectangle(cornerRadius: 20).strokeBorder(Color(r: 217, g: 181, b: 96, a: 0.35), lineWidth: 1))
                    HStack(spacing: 10) {
                        Button {
                            UIPasteboard.general.string = link
                            copied = true
                        } label: {
                            HStack(spacing: 6) { Icon(.copy, 15); Text(copied ? prefs.t("copied") : prefs.t("me_copyLink")) }
                        }
                        .btn(.plain, wide: true)
                        Button(saved ? prefs.t("saved") : prefs.t("me_saveImage")) {
                            let r = ImageRenderer(content: SkyQRView(text: link, size: 948).padding(0))
                            r.scale = 1
                            if let img = r.uiImage { UIImageWriteToSavedPhotosAlbum(img, nil, nil, nil); saved = true; Haptic.success() }
                        }
                        .btn(.gold, wide: true)
                    }
                }
                .padding(.horizontal, 16).padding(.top, 4).padding(.bottom, 28)
            }
        }
    }
}

// MARK: scanner

/// Camera QR reader (AVFoundation).
struct QRCameraView: UIViewRepresentable {
    let onCode: (String) -> Void

    final class Box: UIView {
        let session = AVCaptureSession()
        var layerPreview: AVCaptureVideoPreviewLayer?
        override func layoutSubviews() { super.layoutSubviews(); layerPreview?.frame = bounds }
    }

    final class Coordinator: NSObject, AVCaptureMetadataOutputObjectsDelegate {
        let onCode: (String) -> Void
        var done = false
        init(_ f: @escaping (String) -> Void) { onCode = f }
        func metadataOutput(_ output: AVCaptureMetadataOutput, didOutput objects: [AVMetadataObject], from connection: AVCaptureConnection) {
            guard !done, let o = objects.first as? AVMetadataMachineReadableCodeObject, let s = o.stringValue else { return }
            done = true
            onCode(s)
        }
    }

    func makeCoordinator() -> Coordinator { Coordinator(onCode) }

    func makeUIView(context: Context) -> Box {
        let v = Box()
        v.backgroundColor = .black
        guard let dev = AVCaptureDevice.default(for: .video), let input = try? AVCaptureDeviceInput(device: dev),
              v.session.canAddInput(input) else { return v }
        v.session.addInput(input)
        let out = AVCaptureMetadataOutput()
        if v.session.canAddOutput(out) {
            v.session.addOutput(out)
            out.setMetadataObjectsDelegate(context.coordinator, queue: .main)
            out.metadataObjectTypes = [.qr]
        }
        let layer = AVCaptureVideoPreviewLayer(session: v.session)
        layer.videoGravity = .resizeAspectFill
        v.layer.addSublayer(layer)
        v.layerPreview = layer
        let s = v.session
        DispatchQueue.global(qos: .userInitiated).async { s.startRunning() }
        return v
    }

    func updateUIView(_ uiView: Box, context: Context) {}

    static func dismantleUIView(_ uiView: Box, coordinator: Coordinator) {
        let s = uiView.session
        DispatchQueue.global(qos: .userInitiated).async { s.stopRunning() }
    }
}

struct ScanPage: View {
    @Environment(Prefs.self) private var prefs
    @Environment(Router.self) private var router
    @Environment(\.pal) private var pal
    let back: () -> Void
    @State var state = "ask"
    @State var result = ""
    @State var pick: PhotosPickerItem?
    @State var line = false

    var body: some View {
        VStack(spacing: 0) {
            MeBar(title: prefs.t("me_scanTitle"), back: back)
            VStack(spacing: 14) {
                GeometryReader { g in
                    ZStack {
                        Color.black
                        if state == "live" { QRCameraView { handle($0) } }
                        let fx = g.size.width * 0.14, fy = g.size.height * 0.18
                        Rectangle().fill(Color.black.opacity(0.35))
                            .mask(
                                Rectangle().overlay(
                                    RoundedRectangle(cornerRadius: 18).frame(width: g.size.width - 2 * fx, height: g.size.height - 2 * fy)
                                        .blendMode(.destinationOut)
                                ).compositingGroup()
                            )
                        RoundedRectangle(cornerRadius: 18).strokeBorder(Color(r: 217, g: 181, b: 96, a: 0.9), lineWidth: 2)
                            .frame(width: g.size.width - 2 * fx, height: g.size.height - 2 * fy)
                        if state == "live" {
                            LinearGradient(colors: [.clear, pal.gold, .clear], startPoint: .leading, endPoint: .trailing)
                                .frame(width: g.size.width * 0.68, height: 2)
                                .position(x: g.size.width / 2, y: g.size.height * (line ? 0.78 : 0.20))
                                .onAppear { withAnimation(.easeInOut(duration: 1).repeatForever(autoreverses: true)) { line = true } }
                        } else {
                            overlay
                        }
                        PhotosPicker(selection: $pick, matching: .images) {
                            VStack(spacing: 5) {
                                Icon(.images, 24, stroke: 1.6).foregroundColor(.white)
                                    .frame(width: 54, height: 54)
                                    .background(Circle().fill(Color.white.opacity(0.14)))
                                    .overlay(Circle().strokeBorder(Color.white.opacity(0.65), lineWidth: 1.5))
                                Text(prefs.t("me_album")).font(.inter(12.5)).foregroundColor(.white)
                            }
                        }
                        .position(x: g.size.width / 2, y: g.size.height - 50)
                    }
                }
                .aspectRatio(3.0 / 4.0, contentMode: .fit)
                .clipShape(RoundedRectangle(cornerRadius: 18))
                Text(prefs.t("me_scanHint")).font(.inter(12.5)).foregroundColor(pal.muted).multilineTextAlignment(.center)
            }
            .padding(.horizontal, 16).padding(.top, 4)
            Spacer()
        }
        .onChange(of: pick) { _, item in
            guard let item else { return }
            Task { await read(item) }
        }
    }

    @ViewBuilder private var overlay: some View {
        VStack(spacing: 14) {
            Icon(.camera, 40, stroke: 1.3).foregroundColor(Color(white: 0.93))
            switch state {
            case "ask":
                Text(prefs.t("me_camAsk")).multilineTextAlignment(.center)
                Button(prefs.t("me_camAllow")) { Task { await start() } }.btn(.gold)
            case "denied":
                Text(prefs.t("me_camDenied")).multilineTextAlignment(.center)
                Button(prefs.t("me_retry")) { Task { await start() } }.btn()
            case "none": Text(prefs.t("me_camNone"))
            case "nocode":
                Text(prefs.t("me_noCode"))
                Button(prefs.t("me_scanAgain")) { Task { await start() } }.btn()
            case "done":
                Text(prefs.t("me_scanResult")).font(.inter(12.5))
                Text(result).font(.system(size: 12, design: .monospaced)).textSelection(.enabled)
                    .padding(.horizontal, 10).padding(.vertical, 8)
                    .background(RoundedRectangle(cornerRadius: 8).fill(Color.white.opacity(0.08)))
                Button(prefs.t("me_scanAgain")) { result = ""; Task { await start() } }.btn()
            default: Text(prefs.t("connecting"))
            }
        }
        .font(.inter(13))
        .foregroundColor(Color(white: 0.93))
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black.opacity(0.6))
    }

    private func start() async {
        guard AVCaptureDevice.default(for: .video) != nil else { state = "none"; return }
        state = "starting"
        let ok = await AVCaptureDevice.requestAccess(for: .video)
        state = ok ? "live" : "denied"
    }

    private func handle(_ text: String) {
        let prefix = API.site.absoluteString + "/#/k7bg/"
        if text.hasPrefix(prefix), let id = Int(text.dropFirst(prefix.count).prefix { $0.isNumber }) {
            router.go(.profile(id))
            return
        }
        result = text
        state = "done"
    }

    private func read(_ item: PhotosPickerItem) async {
        state = "reading"
        defer { pick = nil }
        guard let data = try? await item.loadTransferable(type: Data.self), let ci = CIImage(data: data) else { state = "nocode"; return }
        let det = CIDetector(ofType: CIDetectorTypeQRCode, context: nil, options: [CIDetectorAccuracy: CIDetectorAccuracyHigh])
        let text = (det?.features(in: ci).first as? CIQRCodeFeature)?.messageString ?? ""
        if text.isEmpty { state = "nocode" } else { handle(text) }
    }
}

struct MeSimplePage: View {
    @Environment(\.pal) private var pal
    let icon: Lucide
    let title: String?
    let heading: String
    let message: String
    let back: () -> Void
    let action: (String, () -> Void)?

    var body: some View {
        VStack(spacing: 0) {
            MeBar(title: title, back: back)
            VStack(spacing: 10) {
                Icon(icon, 44, stroke: 1.2).foregroundColor(pal.gold)
                Text(heading).font(.inter(13, .semibold)).foregroundColor(pal.ink)
                Text(message).font(.inter(12.5)).foregroundColor(pal.muted).multilineTextAlignment(.center)
                if let action { Button(action.0, action: action.1).btn(.gold) }
            }
            .padding(.horizontal, 12).padding(.vertical, 40)
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 16)
            Spacer()
        }
    }
}
