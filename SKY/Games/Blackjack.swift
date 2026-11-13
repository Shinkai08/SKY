import SwiftUI

/// Table felt: rounded top, elliptical bottom (border-radius 24px 24px 50% 50% / 24px 24px 34% 34%).
struct FeltShape: Shape {
    func path(in r: CGRect) -> Path {
        let t: CGFloat = 24, bx = r.width / 2, by = r.height * 0.34
        var p = Path()
        p.move(to: CGPoint(x: r.minX + t, y: r.minY))
        p.addLine(to: CGPoint(x: r.maxX - t, y: r.minY))
        p.addQuadCurve(to: CGPoint(x: r.maxX, y: r.minY + t), control: CGPoint(x: r.maxX, y: r.minY))
        p.addLine(to: CGPoint(x: r.maxX, y: r.maxY - by))
        p.addCurve(to: CGPoint(x: r.midX, y: r.maxY), control1: CGPoint(x: r.maxX, y: r.maxY - by + by * 0.5523),
                   control2: CGPoint(x: r.maxX - bx + bx * 0.4477, y: r.maxY))
        p.addCurve(to: CGPoint(x: r.minX, y: r.maxY - by), control1: CGPoint(x: r.minX + bx * 0.5523, y: r.maxY),
                   control2: CGPoint(x: r.minX, y: r.maxY - by + by * 0.5523))
        p.addLine(to: CGPoint(x: r.minX, y: r.minY + t))
        p.addQuadCurve(to: CGPoint(x: r.minX + t, y: r.minY), control: CGPoint(x: r.minX, y: r.minY))
        p.closeSubpath()
        return p
    }
}

/// One playing card (.bj-card): c < 0 is face down.
struct PlayingCard: View {
    let c: Int
    var size = "m"
    static let ranks = ["A", "2", "3", "4", "5", "6", "7", "8", "9", "10", "J", "Q", "K"]
    static let suits = ["♠", "♥", "♦", "♣"]
    var body: some View {
        let dims: (CGFloat, CGFloat, CGFloat, CGFloat, CGFloat) = size == "s" ? (22, 31, 10, 10, 3) : size == "l" ? (46, 64, 19, 22, 6) : (36, 50, 15, 17, 5)
        Group {
            if c < 0 {
                RoundedRectangle(cornerRadius: dims.4)
                    .fill(ImagePaint(image: Image(uiImage: PlayingCard.back), scale: 1))
                    .overlay(RoundedRectangle(cornerRadius: dims.4).strokeBorder(Color(hex: 0xfbfaf6), lineWidth: 2))
            } else {
                let suit = (c / 13) % 4
                VStack(alignment: .leading, spacing: 0) {
                    Text(PlayingCard.ranks[c % 13]).font(.custom("Georgia-Bold", fixedSize: dims.2))
                    Spacer(minLength: 0)
                    Text(PlayingCard.suits[suit]).font(.custom("Georgia", fixedSize: dims.3)).frame(maxWidth: .infinity, alignment: .trailing)
                }
                .foregroundColor(suit == 1 || suit == 2 ? Color(hex: 0xc8283c) : Color(hex: 0x17181c))
                .padding(.horizontal, size == "s" ? 2 : size == "l" ? 5 : 4).padding(.vertical, size == "s" ? 2 : size == "l" ? 4 : 3)
                .background(RoundedRectangle(cornerRadius: dims.4).fill(Color(hex: 0xfbfaf6)))
            }
        }
        .frame(width: dims.0, height: dims.1)
        .shadow(color: .black.opacity(0.4), radius: 2.5, x: 0, y: 2)
        .transition(.move(edge: .top).combined(with: .opacity))
    }

    /// Striped back (repeating 45° red stripes).
    static let back: UIImage = {
        UIGraphicsImageRenderer(size: CGSize(width: 16, height: 16)).image { ctx in
            UIColor(Color(hex: 0x7a1f2e)).setFill(); ctx.fill(CGRect(x: 0, y: 0, width: 16, height: 16))
            UIColor(Color(hex: 0xa32c3f)).setFill()
            let p = UIBezierPath()
            for o in stride(from: -16.0, through: 16.0, by: 8.0) {
                p.move(to: CGPoint(x: o + 4, y: 0)); p.addLine(to: CGPoint(x: o + 8, y: 0))
                p.addLine(to: CGPoint(x: o + 8 + 16, y: 16)); p.addLine(to: CGPoint(x: o + 4 + 16, y: 16)); p.close()
            }
            p.fill()
        }
    }()
}

/// Overlapping card row.
struct CardRow: View {
    let cards: [Int]
    var size = "m"
    var body: some View {
        let overlap: CGFloat = size == "s" ? -11 : size == "l" ? -16 : -14
        HStack(spacing: overlap) {
            ForEach(Array(cards.enumerated()), id: \.offset) { _, c in PlayingCard(c: c, size: size) }
        }
        .animation(.easeOut(duration: 0.25), value: cards.count)
    }
}

struct TotalBadge: View {
    let n: Int
    var small = false
    var color = Color.black.opacity(0.55)
    var body: some View {
        Text("\(n)").font(.inter(small ? 10 : 12, .bold)).monospacedDigit().foregroundColor(.white)
            .padding(.horizontal, small ? 4 : 6).padding(.vertical, small ? 0 : 1)
            .frame(minWidth: small ? 16 : 22)
            .background(Capsule().fill(color))
    }
}

@MainActor
@Observable
final class TableModel {
    var s: JSON?
    var down = false
    var offset: Double = 0
    @ObservationIgnored private var best = Double.infinity
    @ObservationIgnored private var task: Task<Void, Never>?

    func start() {
        task?.cancel()
        task = Task { [weak self] in
            while !Task.isCancelled {
                await self?.load()
                if Demo.on { return }
                try? await Task.sleep(nanoseconds: 450_000_000)
            }
        }
    }
    func stop() { task?.cancel() }

    func load() async {
        let t0 = Date().timeIntervalSince1970 * 1000
        do {
            let v = try await API.shared.get("/games/blackjack")
            let t1 = Date().timeIntervalSince1970 * 1000
            best += 5
            if t1 - t0 <= best { best = t1 - t0; offset = v["now"].double - (t0 + t1) / 2 }
            s = v; down = false
        } catch { down = true }
    }
    var now: Double { Date().timeIntervalSince1970 * 1000 + offset }
}

extension Fair {
    /// Same shoe as the server: Fisher–Yates over HMAC-SHA256(seed, "sky-bj:<round>:<block>") uint32s with rejection.
    static func bjShoe(seedHex: String, round: Int) -> [Int] {
        let key = bytes(seedHex)
        let n = 312
        var shoe = (0..<n).map { $0 % 52 }
        var buf: [UInt8] = [], off = 0, block = 0
        func next() -> UInt64 {
            if buf.count - off < 4 { buf = hmac(key, "sky-bj:\(round):\(block)"); block += 1; off = 0 }
            let v = UInt64(buf[off]) << 24 | UInt64(buf[off + 1]) << 16 | UInt64(buf[off + 2]) << 8 | UInt64(buf[off + 3])
            off += 4
            return v
        }
        var i = n - 1
        while i > 0 {
            let m = UInt64(i + 1), limit = (UInt64(1) << 32) / m * m
            var u = next()
            while u >= limit { u = next() }
            shoe.swapAt(i, Int(u % m))
            i -= 1
        }
        return shoe
    }

    static func verifyBJ(seed: String, hash: String, round: Int, drawn: [Int]) -> Bool {
        guard sha256(bytes(seed)) == hash else { return false }
        let shoe = bjShoe(seedHex: seed, round: round)
        return drawn.enumerated().allSatisfy { i, c in i < shoe.count && shoe[i] == c }
    }
}

/// pages/Blackjack.tsx.
struct BlackjackPage: View {
    @Environment(Prefs.self) private var prefs
    @Environment(Session.self) private var session
    @Environment(Router.self) private var router
    @Environment(\.pal) private var pal
    @State var model = TableModel()
    @State var amount = String(UserDefaults.standard.string(forKey: "sky.bjBet") ?? "10")
    @State var busy = false
    @State var msg = ""
    @State var tab = "rules"
    @State var mine: [JSON] = []
    @State var checked: [Int: Bool] = [:]

    var body: some View {
        let s = model.s
        let mySeat = s?["mySeat"].int ?? -1
        let my: JSON? = s != nil && mySeat >= 0 && s!["seats"][mySeat].exists ? s!["seats"][mySeat] : nil
        let myTurn = s?["phase"].string == "playing" && s?["turn"].int == mySeat && mySeat >= 0
        ZStack {
            pal.bg.ignoresSafeArea()
            VStack(spacing: 0) {
                CoverHeader(title: prefs.t("gm_blackjack")) {
                    IconButton(.chevronLeft, size: 24) { router.coverBack() }
                } right: { EmptyView() }
                ScrollView {
                    VStack(spacing: 0) {
                        felt(s, my: my)
                        TimelineView(.periodic(from: .now, by: 0.2)) { _ in status(s, myTurn: myTurn) }
                        panel(s, my: my, myTurn: myTurn)
                        tabs
                        list(s)
                        Text(prefs.t("gm_note")).font(.inter(11.5)).foregroundColor(pal.muted).multilineTextAlignment(.center)
                            .padding(.horizontal, 20).padding(.top, 14).padding(.bottom, 24)
                    }
                }
            }
        }
        .onAppear { model.start() }
        .onDisappear { model.stop() }
        .task(id: "\(tab)|\(s?["history"][0]["id"].int ?? 0)") {
            guard tab == "mine", session.me != nil else { return }
            if let r = try? await API.shared.get("/games/blackjack/me") { mine = r.array }
        }
    }

    // MARK: table

    private func seatPos(_ i: Int, _ size: CGSize) -> CGPoint {
        let t = Double.pi * (0.12 + 0.76 * Double(i) / 6)
        return CGPoint(x: size.width * (0.50 + 0.42 * cos(t)), y: size.height * (0.24 + 0.58 * sin(t)))
    }

    private func felt(_ s: JSON?, my: JSON?) -> some View {
        let dealer = s?["dealer"].array.map { $0.int } ?? []
        return GeometryReader { g in
            ZStack {
                VStack(spacing: 4) {
                    CardRow(cards: dealer)
                    if !dealer.isEmpty { TotalBadge(n: s?["dealerTotal"].int ?? 0) }
                    Text(prefs.t("bj_dealer")).font(.inter(11)).tracking(0.9).foregroundColor(.white.opacity(0.6))
                }
                .position(x: g.size.width / 2, y: 12 + 50)
                VStack(spacing: 3) {
                    Text(prefs.t("bj_pays")).font(.inter(13, .semibold)).tracking(1.6).foregroundColor(Color(r: 232, g: 200, b: 120, a: 0.85))
                    Text(prefs.t("bj_print")).font(.inter(10)).foregroundColor(.white.opacity(0.45)).multilineTextAlignment(.center)
                }
                .padding(.horizontal, 40)
                .frame(width: g.size.width)
                .position(x: g.size.width / 2, y: g.size.height * 0.30 + 16)
                ForEach(0..<7, id: \.self) { i in
                    seat(i, s: s, my: my).frame(width: g.size.width * 0.15).position(seatPos(i, g.size))
                }
            }
        }
        .frame(height: min(470, max(360, UIScreen.main.bounds.height * 0.62)))
        .background(
            FeltShape().fill(RadialGradient(stops: [.init(color: Color(hex: 0x1d7a52), location: 0), .init(color: Color(hex: 0x0e4a31), location: 0.55),
                                                    .init(color: Color(hex: 0x082c1d), location: 1)], center: .top, startRadius: 0, endRadius: 520))
        )
        .clipShape(FeltShape())
        .overlay(FeltShape().stroke(Color(r: 212, g: 175, b: 95, a: 0.55), lineWidth: 2))
        .shadow(color: .black.opacity(0.35), radius: 12, x: 0, y: 8)
        .padding(.horizontal, 10)
    }

    private func seat(_ i: Int, s: JSON?, my: JSON?) -> some View {
        let st = s?["seats"][i]
        let taken = st?.exists == true
        let isMe = st?["me"].bool == true
        let active = s?["phase"].string == "playing" && s?["turn"].int == i
        let hands = st?["hands"].array ?? []
        return VStack(spacing: 3) {
            Button {
                if session.me == nil { router.open(.login); return }
                if my == nil { Task { await call("sit", ["seat": i]) } }
            } label: {
                ZStack {
                    if taken {
                        Circle().fill(LinearGradient(colors: [Color(hex: 0x3b4252), Color(hex: 0x1f232c)], startPoint: .topLeading, endPoint: .bottomTrailing))
                        Circle().strokeBorder(isMe ? pal.gold : Color.white.opacity(0.55), lineWidth: 2)
                        Text(String(st!["nick"].string.suffix(4))).font(.inter(11, .semibold)).foregroundColor(.white)
                    } else {
                        Circle().fill(Color.black.opacity(0.25))
                        Circle().strokeBorder(Color.white.opacity(0.35), style: StrokeStyle(lineWidth: 2, dash: [4, 3]))
                        Text("\(i + 1)").font(.inter(13, .bold)).foregroundColor(.white.opacity(0.75))
                    }
                }
                .frame(width: 44, height: 44)
                .background(Circle().stroke(isMe ? Color(r: 212, g: 175, b: 95, a: 0.25) : .clear, lineWidth: 6))
                .scaleEffect(active ? 1.06 : 1)
                .animation(active ? .easeInOut(duration: 0.5).repeatForever(autoreverses: true) : .default, value: active)
            }
            .buttonStyle(PlainTap())
            .disabled(taken || (my != nil && !taken) || busy)
            if taken, hands.first?.exists == true {
                Text(prefs.num(hands.reduce(0) { $0 + $1["bet"].double }))
                    .font(.inter(10, .heavy)).monospacedDigit().foregroundColor(Color(hex: 0x2a1f05))
                    .padding(.horizontal, 6)
                    .background(RoundedRectangle(cornerRadius: 8).fill(Color(r: 232, g: 200, b: 120, a: 0.92)))
            }
            if !taken && my == nil { Text(prefs.t("bj_sit")).font(.inter(10)).foregroundColor(.white.opacity(0.55)) }
        }
        .overlay(alignment: .bottom) {
            if taken && !hands.isEmpty {
                VStack(spacing: 2) {
                    ForEach(Array(hands.enumerated().reversed()), id: \.offset) { j, h in
                        let res = h["result"].string
                        HStack(spacing: 2) {
                            CardRow(cards: h["cards"].array.map { $0.int }, size: "s")
                            if !h["cards"].array.isEmpty {
                                TotalBadge(n: h["total"].int, small: true,
                                           color: res == "win" || res == "blackjack" ? Color(hex: 0x1f9d5c) : res == "lose" || res == "bust" ? Color(hex: 0xb3263a) : Color.black.opacity(0.55))
                            }
                        }
                        .padding(1)
                        .overlay(RoundedRectangle(cornerRadius: 5).strokeBorder(active && s?["hand"].int == j ? pal.gold : .clear, lineWidth: 2))
                    }
                }
                .fixedSize()
                .alignmentGuide(.bottom) { d in d[.bottom] + 44 - 14 + (hands.first?.exists == true ? 18 : 0) }
            }
        }
    }

    private func status(_ s: JSON?, myTurn: Bool) -> some View {
        let left = max(0, ((s?["deadline"].double ?? 0) - model.now) / 1000)
        var text: String
        if let s {
            let l = String(format: "%.0f", left)
            switch s["phase"].string {
            case "waiting": text = prefs.t("bj_waiting")
            case "betting": text = "\(prefs.t("bj_betting")) \(l)s"
            case "insurance": text = "\(prefs.t("bj_insurance")) \(l)s"
            case "playing":
                let who = s["seats"][s["turn"].int]
                text = who["me"].bool ? "\(prefs.t("bj_yourTurn")) \(l)s" : "\(prefs.t("bj_turnOf").replacingOccurrences(of: "{n}", with: who["nick"].string)) \(l)s"
            case "dealer": text = prefs.t("bj_dealerPlays")
            default: text = prefs.t("bj_settled")
            }
        } else {
            text = model.down ? prefs.t("cr_down") : prefs.t("connecting")
        }
        return HStack {
            Text(text).font(.inter(13, .semibold)).foregroundColor(myTurn ? pal.gold : pal.ink)
            Spacer()
            if let s, s["phase"].string != "waiting" {
                Text("#\(s["round"].int) · \(s["players"].int)/7").font(.inter(12.5)).foregroundColor(pal.muted)
            }
        }
        .padding(.horizontal, 14).padding(.vertical, 10)
        .background(RoundedRectangle(cornerRadius: 12).fill(pal.surface))
        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(myTurn ? pal.gold : pal.line, lineWidth: 1))
        .padding(.horizontal, 16).padding(.top, 10)
    }

    // MARK: panel

    private func panel(_ s: JSON?, my: JSON?, myTurn: Bool) -> some View {
        let avail = session.account?.available ?? 0
        let minBet = s?["limits"]["minBet"].doubleOrNil ?? 1, maxBet = s?["limits"]["maxBet"].doubleOrNil ?? 5000
        let amt = Double(amount.replacingOccurrences(of: ",", with: ".")) ?? 0
        let actions = s?["actions"].array.map { $0.string } ?? []
        let hands = my?["hands"].array ?? []
        let settled = s?["phase"].string == "settled"
        var net = 0.0
        if settled, let my {
            net = hands.reduce(0) { $0 + $1["payout"].double - $1["bet"].double }
            let ins = my["ins"].double
            if ins > 0 { net += (s?["dealer"].array.count == 2 && s?["dealerTotal"].int == 21) ? ins * 2 : -ins }
        }
        return VStack(spacing: 10) {
            HStack {
                Text(prefs.t("cr_balance")).foregroundColor(pal.muted)
                Spacer()
                Text(session.me != nil ? "\(prefs.num(avail)) USDT" : "—").font(.inter(12.5, .semibold)).monospacedDigit().foregroundColor(pal.ink)
            }
            .font(.inter(12.5))
            if !hands.isEmpty {
                VStack(spacing: 8) {
                    ForEach(Array(hands.enumerated()), id: \.offset) { j, h in
                        let cards = h["cards"].array.map { $0.int }
                        let total = h["total"].int
                        let res = h["result"].string
                        HStack(spacing: 12) {
                            CardRow(cards: cards, size: "l")
                            VStack(alignment: .leading, spacing: 2) {
                                Text(cards.isEmpty ? "—" : "\(h["soft"].bool && total < 21 ? "\(total - 10)/" : "")\(total)").font(.inter(20, .semibold)).monospacedDigit().foregroundColor(pal.ink)
                                Text("\(prefs.num(h["bet"].double)) USDT\(h["double"].bool ? " ×2" : "")").font(.inter(12.5)).monospacedDigit().foregroundColor(pal.muted)
                                if !res.isEmpty {
                                    Text("\(prefs.t("bj_r_\(res)"))\(h["payout"].double > 0 ? " +\(prefs.num(h["payout"].double))" : "")")
                                        .font(.inter(13, .bold))
                                        .foregroundColor(res == "win" || res == "blackjack" ? pal.green : res == "push" ? pal.muted : pal.red)
                                }
                            }
                            Spacer(minLength: 0)
                        }
                        .padding(8)
                        .background(RoundedRectangle(cornerRadius: 12).fill(pal.surface2))
                        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(myTurn && s?["hand"].int == j ? pal.gold : .clear, lineWidth: 2))
                    }
                }
            }
            if settled && !hands.isEmpty {
                Text("\(net > 0 ? "+" : net < 0 ? "−" : "±")\(prefs.num(abs(net))) USDT").font(.inter(13, .semibold))
                    .foregroundColor(net > 0 ? pal.green : net < 0 ? pal.red : pal.muted)
            }
            if session.me == nil {
                goButton(prefs.t("bj_login")) { router.open(.login) }
            } else if my == nil {
                Text(prefs.t("bj_pickSeat")).font(.inter(13)).foregroundColor(pal.muted)
            }
            if my != nil && actions.contains("bet") {
                HStack(spacing: 10) {
                    Text(prefs.t("cr_amount")).font(.inter(14)).foregroundColor(pal.ink2)
                    TextField("", text: $amount).font(.inter(17, .semibold)).monospacedDigit().multilineTextAlignment(.trailing)
                        .keyboardType(.decimalPad).foregroundColor(pal.ink)
                    Text("USDT").font(.inter(13)).foregroundColor(pal.muted)
                }
                .padding(.horizontal, 14).frame(height: 48)
                .background(RoundedRectangle(cornerRadius: 12).fill(pal.surface2))
                FlowWrap(spacing: 8) {
                    ForEach([1.0, 5, 10, 50, 100, 500], id: \.self) { c in
                        Button { amount = trim(min(maxBet, ((amt + c) * 100).rounded() / 100)) } label: {
                            Text("\(Int(c))").font(.inter(12, .heavy)).foregroundColor(.white)
                                .frame(width: 44, height: 44)
                                .background(Circle().fill(Color(hex: chipColor(c))))
                                .overlay(Circle().strokeBorder(Color.white.opacity(0.7), style: StrokeStyle(lineWidth: 3, dash: [5, 4])))
                                .shadow(color: .black.opacity(0.35), radius: 3, x: 0, y: 2)
                        }
                        .buttonStyle(PlainTap())
                    }
                    Button { amount = "0" } label: {
                        Text(prefs.t("bj_clear")).font(.inter(12, .heavy)).foregroundColor(pal.ink2)
                            .padding(.horizontal, 12).frame(height: 44)
                            .overlay(Capsule().strokeBorder(pal.line, lineWidth: 1))
                    }
                    .buttonStyle(PlainTap())
                }
                .frame(maxWidth: .infinity)
                goButton("\(prefs.t("cr_bet")) \(amt > 0 ? "\(prefs.num(amt)) USDT" : "")") {
                    if !(amt >= minBet && amt <= maxBet) {
                        msg = prefs.t("cr_range").replacingOccurrences(of: "{a}", with: prefs.num(minBet)).replacingOccurrences(of: "{b}", with: prefs.num(maxBet))
                        return
                    }
                    if amt > avail { msg = prefs.t("err_crash_insufficient"); return }
                    UserDefaults.standard.set(String(amt), forKey: "sky.bjBet")
                    Task { await call("bet", ["amount": String(floor(amt * 100) / 100)]) }
                }
                .disabled(busy)
            }
            if my != nil && s?["phase"].string == "betting" && !actions.contains("bet") {
                Text(prefs.t("bj_betPlaced")).font(.inter(13)).foregroundColor(pal.muted)
            }
            if actions.contains("insurance"), let my {
                Text(prefs.t("bj_insAsk").replacingOccurrences(of: "{x}", with: prefs.num(my["hands"][0]["bet"].double / 2))).font(.inter(13)).foregroundColor(pal.ink)
                HStack(spacing: 8) {
                    actButton(prefs.t("bj_insYes"), bg: AnyShapeStyle(pal.goldGrad), fg: Color(hex: 0x2a1f05)) { Task { await call("insurance", ["take": true]) } }
                    actButton(prefs.t("bj_insNo"), bg: AnyShapeStyle(pal.surface2), fg: pal.ink) { Task { await call("insurance", ["take": false]) } }
                }
            }
            if myTurn {
                HStack(spacing: 8) {
                    ForEach(["hit", "stand", "double", "split"], id: \.self) { a in
                        let style: (AnyShapeStyle, Color) = a == "stand" ? (AnyShapeStyle(pal.surface2), pal.ink)
                            : a == "double" ? (AnyShapeStyle(Color(hex: 0x2a6fd6)), .white) : a == "split" ? (AnyShapeStyle(Color(hex: 0x7b3fd0)), .white)
                            : (AnyShapeStyle(pal.goldGrad), Color(hex: 0x2a1f05))
                        actButton(prefs.t("bj_\(a)"), bg: style.0, fg: style.1) { Task { await call("action", ["action": a]) } }
                            .disabled(busy || !actions.contains(a))
                            .opacity(busy || !actions.contains(a) ? 0.35 : 1)
                    }
                }
            }
            if !msg.isEmpty { Text(msg).font(.inter(12.5, .semibold)).foregroundColor(pal.red) }
            if let my {
                Button(my["leaving"].bool ? prefs.t("bj_leaving") : prefs.t("bj_leave")) { Task { await call("leave") } }
                    .font(.inter(13)).foregroundColor(pal.muted).underline().buttonStyle(PlainTap()).disabled(busy)
            }
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 16).fill(pal.surface))
        .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(pal.line, lineWidth: 1))
        .padding(.horizontal, 16).padding(.top, 14)
    }

    private func chipColor(_ c: Double) -> UInt32 {
        switch c {
        case 1: return 0x8a8f99
        case 5: return 0xc8283c
        case 10: return 0x2a6fd6
        case 50: return 0x1f9d5c
        case 100: return 0x23252b
        default: return 0x7b3fd0
        }
    }

    private func trim(_ v: Double) -> String {
        let s = String(format: "%.2f", v)
        return s.hasSuffix(".00") ? String(s.dropLast(3)) : s.hasSuffix("0") ? String(s.dropLast()) : s
    }

    private func goButton(_ title: String, _ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title).font(.inter(17, .heavy)).foregroundColor(Color(hex: 0x2a1f05))
                .frame(maxWidth: .infinity).frame(height: 54)
                .background(RoundedRectangle(cornerRadius: 14).fill(pal.goldGrad))
        }
        .buttonStyle(PlainTap())
    }

    private func actButton(_ title: String, bg: AnyShapeStyle, fg: Color, _ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title).font(.inter(16, .heavy)).foregroundColor(fg).lineLimit(1).minimumScaleFactor(0.7)
                .frame(maxWidth: .infinity).frame(height: 50)
                .background(RoundedRectangle(cornerRadius: 12).fill(bg))
        }
        .buttonStyle(PlainTap())
    }

    private var tabs: some View {
        HStack(spacing: 6) {
            tabButton("rules", .bookOpen, prefs.t("bj_rulesTab"))
            tabButton("mine", .history, prefs.t("cr_mine"))
            tabButton("fair", .shieldCheck, prefs.t("cr_fair"))
        }
        .padding(4)
        .background(RoundedRectangle(cornerRadius: 12).fill(pal.surface2))
        .padding(.horizontal, 16).padding(.top, 16)
    }

    private func tabButton(_ id: String, _ icon: Lucide, _ label: String) -> some View {
        Button { tab = id } label: {
            HStack(spacing: 5) { Icon(icon, 16); Text(label).font(.inter(14, .semibold)) }
                .foregroundColor(tab == id ? pal.ink : pal.muted)
                .frame(maxWidth: .infinity).frame(height: 36)
                .background(RoundedRectangle(cornerRadius: 9).fill(tab == id ? pal.surface : .clear))
        }
        .buttonStyle(PlainTap())
    }

    @ViewBuilder private func list(_ s: JSON?) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            if tab == "rules" {
                Text(prefs.t("bj_rules")).font(.inter(12.5)).foregroundColor(pal.ink).lineSpacing(4).padding(.vertical, 6)
            } else if tab == "mine" {
                if session.me == nil { EmptyNote(text: prefs.t("bj_login"), pad: 24) }
                else if mine.isEmpty { EmptyNote(text: prefs.t("cr_noBets"), pad: 24) }
                ForEach(Array(mine.enumerated()), id: \.offset) { _, r in
                    let net = (r["paid"].double - r["staked"].double) / 1e8
                    let refund = r["refund"].bool
                    HStack(alignment: .center, spacing: 10) {
                        Text("#\(r["round"].int)\(refund ? " · \(prefs.t("cr_refund"))" : "")").font(.inter(12.5)).foregroundColor(pal.muted)
                        VStack(alignment: .leading, spacing: 2) {
                            ForEach(Array(r["hands"].array.enumerated()), id: \.offset) { _, h in
                                let res = h["result"].string
                                (Text(h["cards"].array.map { PlayingCard.ranks[$0.int % 13] }.joined(separator: " ") + " ").foregroundColor(pal.ink)
                                 + Text(prefs.t("bj_r_\(res)")).fontWeight(.bold)
                                    .foregroundColor(res == "win" || res == "blackjack" ? pal.green : res == "lose" || res == "bust" ? pal.red : pal.ink))
                            }
                            if r["dealer"].exists {
                                Text("\(prefs.t("bj_dealer")) \(r["dealer"].array.map { PlayingCard.ranks[$0.int % 13] }.joined(separator: " "))").foregroundColor(pal.muted)
                            }
                        }
                        .font(.inter(13))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        Text(refund ? "±0" : "\(net > 0 ? "+" : net < 0 ? "−" : "±")\(prefs.num(abs(net)))").font(.inter(13)).monospacedDigit()
                            .foregroundColor(refund ? pal.muted : net > 0 ? pal.green : net < 0 ? pal.red : pal.muted)
                    }
                    .padding(.vertical, 10)
                    .overlay(alignment: .bottom) { Hairline() }
                }
            } else if let s {
                Text(prefs.t("bj_fairHow")).font(.inter(12.5)).foregroundColor(pal.muted).padding(.vertical, 6)
                if !s["hash"].string.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("\(prefs.t("cr_hash")) #\(s["round"].int)").font(.inter(12.5)).foregroundColor(pal.muted)
                        Text(s["hash"].string).font(.system(size: 11, design: .monospaced)).foregroundColor(pal.ink).textSelection(.enabled)
                    }
                    .padding(.vertical, 10).overlay(alignment: .bottom) { Hairline() }
                }
                ForEach(Array(s["history"].array.enumerated()), id: \.offset) { _, r in
                    let id = r["id"].int
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 8) {
                            Text("#\(id) · \(prefs.t("bj_dealer")) \(r["total"].int) · \(r["drawn"].array.count) \(prefs.t("bj_cardsDrawn"))")
                                .font(.inter(12.5)).foregroundColor(pal.ink)
                            Spacer()
                            Button {
                                checked[id] = Fair.verifyBJ(seed: r["seed"].string, hash: r["hash"].string, round: id, drawn: r["drawn"].array.map { $0.int })
                            } label: {
                                Text(checked[id] == nil ? prefs.t("cr_verify") : checked[id]! ? "✓ \(prefs.t("cr_verified"))" : "✗ \(prefs.t("cr_mismatch"))")
                                    .font(.inter(12)).foregroundColor(pal.gold)
                                    .padding(.horizontal, 10).frame(height: 26)
                                    .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(pal.line, lineWidth: 1))
                            }
                            .buttonStyle(PlainTap())
                        }
                        Text("\(prefs.t("cr_seed")) \(r["seed"].string)").font(.system(size: 11, design: .monospaced)).foregroundColor(pal.muted)
                    }
                    .padding(.vertical, 10)
                    .overlay(alignment: .bottom) { Hairline() }
                }
            }
        }
        .padding(.horizontal, 16).padding(.vertical, 8)
    }

    private func call(_ path: String, _ body: [String: Any] = [:]) async {
        busy = true; msg = ""
        defer { busy = false }
        do {
            _ = try await API.shared.post("/games/blackjack/\(path)", body)
            Haptic.tap()
        } catch {
            let code = (error as? APIError)?.code ?? "service_unavailable"
            msg = prefs.has("err_\(code)") ? prefs.t("err_\(code)") : code
            Haptic.error()
        }
        await model.load()
        await session.refresh()
    }
}
