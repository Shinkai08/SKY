import SwiftUI
import CryptoKit

/// Sticky header of the full-screen game / prediction pages (.pr-top).
struct CoverHeader<Left: View, Right: View>: View {
    @Environment(\.pal) private var pal
    let title: String
    @ViewBuilder var left: () -> Left
    @ViewBuilder var right: () -> Right
    var body: some View {
        HStack {
            left().frame(width: 40, alignment: .leading)
            Spacer()
            Text(title).font(.inter(20, .bold)).foregroundColor(pal.ink).lineLimit(1)
            Spacer()
            right().frame(width: 40, alignment: .trailing)
        }
        .padding(.horizontal, 12)
        .frame(height: 56)
        .background(pal.bg)
    }
}

/// pages/Games.tsx: 3×3 lobby.
struct GamesPage: View {
    @Environment(Prefs.self) private var prefs
    @Environment(Router.self) private var router
    @Environment(\.pal) private var pal
    @State private var players: [String: Int] = [:]

    static let games: [(id: String, icon: Lucide, cover: Cover?, colors: [UInt32], mid: Double)] = [
        ("crash", .rocket, .crash, [0xf0c060, 0xc9771c, 0x7a3410], 0.55),
        ("blackjack", .spade, .blackjack, [0x2fbf7a, 0x137046, 0x0a3b25], 0.6),
        ("limbo", .target, nil, [0x3cc98a, 0x14805a, 0x0b4a35], 0.6),
        ("dice", .dices, nil, [0x6f8dff, 0x3b4fd1, 0x1f2a7a], 0.6),
        ("mines", .bomb, nil, [0xff7a7a, 0xc23a4c, 0x6d1a2c], 0.6),
        ("plinko", .triangle, nil, [0xe07cff, 0x9b3fd0, 0x4d1b74], 0.6),
        ("hilo", .arrowDownUp, nil, [0x5fd7e8, 0x1d93b0, 0x0c4c63], 0.6),
        ("wheel", .disc3, nil, [0xffd166, 0xe0902a, 0x8a4d0e], 0.6),
        ("tower", .castle, nil, [0xb38cff, 0x6a4bc4, 0x33236b], 0.6),
    ]

    var body: some View {
        ZStack {
            pal.bg.ignoresSafeArea()
            VStack(spacing: 0) {
                CoverHeader(title: prefs.t("gm_title")) { EmptyView() } right: {
                    IconButton(.x, size: 22) { router.closeCover() }
                }
                ScrollView {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 3), spacing: 10) {
                        ForEach(0..<GamesPage.games.count, id: \.self) { i in tile(GamesPage.games[i]) }
                    }
                    .padding(.horizontal, 16).padding(.vertical, 8)
                    Text(prefs.t("gm_note")).font(.inter(11.5)).foregroundColor(pal.muted).multilineTextAlignment(.center)
                        .padding(.horizontal, 20).padding(.top, 14)
                }
            }
        }
        .task {
            while !Task.isCancelled {
                for id in ["crash", "blackjack"] {
                    if let v = try? await API.shared.get("/games/\(id)") { players[id] = v["players"].int }
                }
                try? await Task.sleep(nanoseconds: 3_000_000_000)
            }
        }
    }

    private func tile(_ g: (id: String, icon: Lucide, cover: Cover?, colors: [UInt32], mid: Double)) -> some View {
        Button {
            if let c = g.cover { Haptic.tap(); router.open(c) }
        } label: {
            ZStack {
                LinearGradient(stops: [.init(color: Color(hex: g.colors[0]), location: 0), .init(color: Color(hex: g.colors[1]), location: g.mid),
                                       .init(color: Color(hex: g.colors[2]), location: 1)],
                               startPoint: UnitPoint(x: 0.25, y: 0), endPoint: UnitPoint(x: 0.75, y: 1))
                RadialGradient(colors: [Color.white.opacity(0.22), .clear], center: .top, startRadius: 0, endRadius: 70)
                VStack(spacing: 4) {
                    Icon(g.icon, 38, stroke: 1.6).foregroundColor(.white).shadow(color: .black.opacity(0.35), radius: 3, x: 0, y: 3)
                        .opacity(g.cover == nil ? 0.6 : 1)
                    Text(prefs.t("gm_\(g.id)")).font(.inter(15, .heavy)).tracking(0.3).foregroundColor(.white)
                        .shadow(color: .black.opacity(0.35), radius: 1, x: 0, y: 1).lineLimit(1).minimumScaleFactor(0.7)
                        .opacity(g.cover == nil ? 0.6 : 1)
                    Text(g.cover != nil ? prefs.t("gm_original") : "SKY").font(.inter(11)).foregroundColor(.white.opacity(0.78))
                }
                .padding(.top, 14)
            }
            .aspectRatio(1, contentMode: .fit)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(Color.white.opacity(0.08), lineWidth: 1))
            .overlay(alignment: .topTrailing) {
                if g.cover != nil, let n = players[g.id] {
                    HStack(spacing: 3) { Icon(.user, 12); Text("\(n)") }
                        .font(.inter(11, .semibold)).foregroundColor(.white)
                        .padding(.horizontal, 7).padding(.vertical, 1)
                        .background(RoundedRectangle(cornerRadius: 8).fill(Color.black.opacity(0.35)))
                        .padding(8)
                }
            }
            .overlay(alignment: .topLeading) {
                if g.cover == nil {
                    Text(prefs.t("gm_soon")).font(.inter(10, .semibold)).foregroundColor(.white)
                        .padding(.horizontal, 7).padding(.vertical, 1)
                        .background(RoundedRectangle(cornerRadius: 6).fill(Color.black.opacity(0.35)))
                        .padding(8)
                }
            }
        }
        .buttonStyle(PlainTap())
    }
}

// MARK: - fairness (same formulas as the server)

enum Fair {
    static func bytes(_ hex: String) -> Data {
        var d = Data()
        var i = hex.startIndex
        while i < hex.endIndex, let j = hex.index(i, offsetBy: 2, limitedBy: hex.endIndex) {
            if let b = UInt8(hex[i..<j], radix: 16) { d.append(b) }
            i = j
        }
        return d
    }
    static func hex(_ d: some Sequence<UInt8>) -> String { d.map { String(format: "%02x", $0) }.joined() }
    static func sha256(_ d: Data) -> String { hex(SHA256.hash(data: d)) }
    static func hmac(_ key: Data, _ msg: String) -> [UInt8] {
        Array(HMAC<SHA256>.authenticationCode(for: Data(msg.utf8), using: SymmetricKey(data: key)))
    }

    /// crashPoint ×100: clamp(floor(99 / (1 − r)), 100, 1e8), r = top 52 bits / 2^52.
    static func crashPoint(seedHex: String, round: Int) -> Int {
        let mac = hmac(bytes(seedHex), "sky-crash:\(round)")
        var x: UInt64 = 0
        for b in mac.prefix(8) { x = x << 8 | UInt64(b) }
        let r = Double(x >> 12) / pow(2, 52)
        return min(max(Int(floor(99 / (1 - r))), 100), 100_000_000)
    }

    static func verifyCrash(seed: String, hash: String, round: Int, point: Double) -> Bool {
        sha256(bytes(seed)) == hash && crashPoint(seedHex: seed, round: round) == Int((point * 100).rounded())
    }
}

// MARK: - Crash

@MainActor
@Observable
final class CrashModel {
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
                let running = self?.s?["phase"].string == "running"
                if Demo.on { return }
                try? await Task.sleep(nanoseconds: running ? 250_000_000 : 600_000_000)
            }
        }
    }
    func stop() { task?.cancel() }

    func load() async {
        let t0 = Date().timeIntervalSince1970 * 1000
        do {
            let v = try await API.shared.get("/games/crash")
            let t1 = Date().timeIntervalSince1970 * 1000
            best += 5
            if t1 - t0 <= best { best = t1 - t0; offset = v["now"].double - (t0 + t1) / 2 }
            s = v
            down = false
        } catch { down = true }
    }

    var now: Double { Date().timeIntervalSince1970 * 1000 + offset }
}

struct CrashPage: View {
    @Environment(Prefs.self) private var prefs
    @Environment(Session.self) private var session
    @Environment(Router.self) private var router
    @Environment(\.pal) private var pal
    @State var model = CrashModel()
    @State var amount = "10"
    @State var autoOn = false
    @State var auto = "2.00"
    @State var queued = false
    @State var busy = false
    @State var msg = ""
    @State var tab = "players"
    @State var mine: [JSON] = []
    @State var checked: [Int: Bool] = [:]

    static func fmtX(_ m: Double) -> String { String(format: "%.2fx", m) }

    var body: some View {
        let s = model.s
        let avail = session.account?.available ?? 0
        let me = s?["me"]
        let hasBet = me?.exists == true
        let phase = s?["phase"].string ?? ""
        let riding = phase == "running" && hasBet && (me?["cash"].double ?? 0) == 0
        let locked = hasBet && phase != "crashed"
        ZStack {
            pal.bg.ignoresSafeArea()
            VStack(spacing: 0) {
                CoverHeader(title: prefs.t("gm_crash")) {
                    IconButton(.chevronLeft, size: 24) { router.coverBack() }
                } right: { EmptyView() }
                ScrollView {
                    VStack(spacing: 0) {
                        chips(s)
                        chart(s).padding(.horizontal, 16)
                        panel(s, avail: avail, phase: phase, hasBet: hasBet, riding: riding, locked: locked)
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
        .onChange(of: "\(phase)|\(s?["round"].int ?? 0)") { _, _ in
            if queued && phase == "betting" && !hasBet { queued = false; Task { await placeBet() } }
        }
        .task(id: "\(tab)|\(s?["history"][0]["id"].int ?? 0)") {
            guard tab == "mine", session.me != nil else { return }
            if let r = try? await API.shared.get("/games/crash/me") { mine = r.array }
        }
    }

    private func tone(_ p: Double) -> (Color, Color) {
        p >= 10 ? (pal.gold, Color(r: 212, g: 175, b: 95, a: 0.18)) : p >= 2 ? (pal.green, pal.greenTint) : (pal.muted, pal.surface2)
    }

    private func chip(_ p: Double) -> some View {
        let c = tone(p)
        return Text(CrashPage.fmtX(p)).font(.inter(12, .semibold)).monospacedDigit().foregroundColor(c.0)
            .padding(.horizontal, 8).padding(.vertical, 3)
            .background(RoundedRectangle(cornerRadius: 8).fill(c.1))
    }

    private func chips(_ s: JSON?) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(Array((s?["history"].array ?? []).prefix(20).enumerated()), id: \.offset) { _, r in chip(r["point"].double) }
            }
            .padding(.horizontal, 16)
        }
        .padding(.top, 4).padding(.bottom, 10)
    }

    @ViewBuilder private func chart(_ s: JSON?) -> some View {
        Group {
            if let s {
                TimelineView(.animation) { _ in
                    CrashCanvas(s: s, now: model.now)
                }
            } else {
                Text(prefs.t(model.down ? "cr_down" : "connecting")).font(.inter(13)).foregroundColor(pal.muted)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .frame(height: min(340, max(220, UIScreen.main.bounds.height * 0.42)))
        .background(RoundedRectangle(cornerRadius: 16).fill(pal.surface))
        .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(pal.line, lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private func panel(_ s: JSON?, avail: Double, phase: String, hasBet: Bool, riding: Bool, locked: Bool) -> some View {
        let lim = s?["limits"]
        let minBet = lim?["minBet"].doubleOrNil ?? 0.1, maxBet = lim?["maxBet"].doubleOrNil ?? 10000
        let amt = Double(amount.replacingOccurrences(of: ",", with: ".")) ?? 0
        let autoX = Double(auto.replacingOccurrences(of: ",", with: ".")) ?? 0
        let me = s?["me"]
        let loggedIn = session.me != nil
        var label = prefs.t("cr_next"), kind = "bet"
        if !loggedIn { label = prefs.t("cr_login") }
        else if s == nil { label = "…" }
        else if phase == "betting" && hasBet { label = prefs.t("cr_cancel"); kind = "cancel" }
        else if phase == "betting" { label = prefs.t("cr_bet") }
        else if riding { label = prefs.t("cr_cashout"); kind = "cash" }
        else if queued { label = prefs.t("cr_queued"); kind = "cancel" }
        return VStack(spacing: 10) {
            HStack {
                Text(prefs.t("cr_balance")).foregroundColor(pal.muted)
                Spacer()
                Text(loggedIn ? "\(prefs.num(avail)) USDT" : "—").font(.inter(12.5, .semibold)).monospacedDigit().foregroundColor(pal.ink)
            }
            .font(.inter(12.5))
            crField(label: Text(prefs.t("cr_amount")), text: $amount, unit: "USDT", disabled: locked)
            HStack(spacing: 8) {
                quick("½") { amount = trim(max(minBet, (amt / 2 * 100).rounded() / 100)) }
                quick("2×") { amount = trim(min(maxBet, amt > 0 ? (amt * 2 * 100).rounded() / 100 : minBet)) }
                quick("Min") { amount = trim(minBet) }
                quick("Max") { amount = trim(max(minBet, min(maxBet, floor(avail * 100) / 100))) }
            }
            .disabled(locked)
            crField(label: Text(""), text: $auto, unit: "x", disabled: locked || !autoOn) {
                Button { autoOn.toggle() } label: {
                    HStack(spacing: 6) {
                        RoundedRectangle(cornerRadius: 3).fill(autoOn ? pal.gold : .clear)
                            .overlay(RoundedRectangle(cornerRadius: 3).strokeBorder(autoOn ? pal.gold : pal.muted, lineWidth: 1.5))
                            .overlay { if autoOn { Icon(.check, 11, stroke: 3).foregroundColor(pal.onGold) } }
                            .frame(width: 16, height: 16)
                        Text(prefs.t("cr_auto")).font(.inter(14)).foregroundColor(pal.ink2)
                    }
                }
                .buttonStyle(PlainTap()).disabled(locked)
            }
            if autoOn && autoX >= 1.01 && amt > 0 {
                Text(prefs.t("cr_autoHint").replacingOccurrences(of: "{x}", with: CrashPage.fmtX(autoX)).replacingOccurrences(of: "{p}", with: prefs.num(amt * autoX)))
                    .font(.inter(12.5)).foregroundColor(pal.muted).frame(maxWidth: .infinity, alignment: .leading)
            }
            Button { press(s, amt: amt, autoX: autoX, avail: avail, minBet: minBet, maxBet: maxBet, phase: phase, hasBet: hasBet, riding: riding) } label: {
                HStack(spacing: 6) {
                    Text(label)
                    if kind == "cash", let s {
                        TimelineView(.animation) { _ in
                            let m = exp(s["growth"].double * max(0, model.now - s["start"].double))
                            Text("\(prefs.num((me?["amount"].double ?? 0) * m)) USDT").monospacedDigit()
                        }
                    }
                }
                .font(.inter(17, .heavy))
                .foregroundColor(kind == "cash" ? Color(hex: 0x04210f) : kind == "cancel" ? pal.ink : Color(hex: 0x2a1f05))
                .frame(maxWidth: .infinity).frame(height: 54)
                .background {
                    switch kind {
                    case "cash": RoundedRectangle(cornerRadius: 14).fill(pal.green)
                    case "cancel": RoundedRectangle(cornerRadius: 14).fill(pal.surface2)
                    default: RoundedRectangle(cornerRadius: 14).fill(pal.goldGrad)
                    }
                }
            }
            .buttonStyle(PlainTap())
            .disabled(busy || (loggedIn && s == nil))
            .opacity(busy || (loggedIn && s == nil) ? 0.6 : 1)
            if let me, me["cash"].double > 0 {
                Text("\(prefs.t("cr_cashed")) \(CrashPage.fmtX(me["cash"].double)) · +\(prefs.num(me["payout"].double - me["amount"].double)) USDT")
                    .font(.inter(13, .semibold)).foregroundColor(pal.green)
            }
            if phase == "crashed", let me, me.exists, me["cash"].double == 0 {
                Text("\(prefs.t("cr_lost")) −\(prefs.num(me["amount"].double)) USDT").font(.inter(13, .semibold)).foregroundColor(pal.red)
            }
            if !msg.isEmpty { Text(msg).font(.inter(12.5, .semibold)).foregroundColor(pal.red) }
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 16).fill(pal.surface))
        .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(pal.line, lineWidth: 1))
        .padding(.horizontal, 16).padding(.top, 14)
    }

    private func trim(_ v: Double) -> String {
        let s = String(format: "%.2f", v)
        return s.hasSuffix(".00") ? String(s.dropLast(3)) : s.hasSuffix("0") ? String(s.dropLast()) : s
    }

    private func crField<L: View>(label: Text, text: Binding<String>, unit: String, disabled: Bool, @ViewBuilder leading: () -> L = { EmptyView() }) -> some View {
        HStack(spacing: 10) {
            leading()
            label.font(.inter(14)).foregroundColor(pal.ink2)
            TextField("", text: text).font(.inter(17, .semibold)).monospacedDigit().multilineTextAlignment(.trailing)
                .keyboardType(.decimalPad).foregroundColor(pal.ink).disabled(disabled).opacity(disabled ? 0.55 : 1)
            Text(unit).font(.inter(13)).foregroundColor(pal.muted)
        }
        .padding(.horizontal, 14).frame(height: 48)
        .background(RoundedRectangle(cornerRadius: 12).fill(pal.surface2))
    }

    private func quick(_ title: String, _ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title).font(.inter(13, .semibold)).foregroundColor(pal.ink2)
                .frame(maxWidth: .infinity).frame(height: 36)
                .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(pal.line, lineWidth: 1))
        }
        .buttonStyle(PlainTap())
    }

    private var tabs: some View {
        HStack(spacing: 6) {
            tabButton("players", .users, prefs.t("cr_players"))
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
            if tab == "players", let s {
                HStack {
                    Text("\(s["players"].int) \(prefs.t("cr_people"))")
                    Spacer()
                    Text("\(prefs.t("cr_total")) ") + Text("\(prefs.num(s["wagered"].double)) USDT").foregroundColor(pal.ink).font(.inter(12.5, .semibold))
                }
                .font(.inter(12.5)).foregroundColor(pal.muted).padding(.vertical, 6)
                if s["bets"].array.isEmpty { EmptyNote(text: prefs.t("cr_noBets"), pad: 24) }
                ForEach(Array(s["bets"].array.enumerated()), id: \.offset) { _, b in
                    let cash = b["cash"].double
                    row(Text(b["nick"].string).foregroundColor(pal.ink), prefs.num(b["amount"].double),
                        cash > 0 ? "\(CrashPage.fmtX(cash)) · +\(prefs.num(b["payout"].double - b["amount"].double))" : s["phase"].string == "crashed" ? "−\(prefs.num(b["amount"].double))" : "—",
                        cash > 0 ? pal.green : s["phase"].string == "crashed" ? pal.red : pal.muted)
                }
            } else if tab == "mine" {
                if session.me == nil { EmptyNote(text: prefs.t("cr_login"), pad: 24) }
                else if mine.isEmpty { EmptyNote(text: prefs.t("cr_noBets"), pad: 24) }
                ForEach(Array(mine.enumerated()), id: \.offset) { _, r in
                    let refund = r["refund"].bool, cash = r["cash"].double
                    row(Text("#\(r["round"].int) · \(refund ? prefs.t("cr_refund") : CrashPage.fmtX(r["point"].double))").foregroundColor(pal.muted),
                        prefs.num(r["amount"].double),
                        refund ? "±0" : cash > 0 ? "\(CrashPage.fmtX(cash)) · +\(prefs.num(r["payout"].double - r["amount"].double))" : "−\(prefs.num(r["amount"].double))",
                        refund ? pal.muted : cash > 0 ? pal.green : pal.red)
                }
            } else if tab == "fair", let s {
                Text(prefs.t("cr_rules")).font(.inter(12.5)).foregroundColor(pal.ink).padding(.vertical, 6)
                Text(prefs.t("cr_fairHow")).font(.inter(12.5)).foregroundColor(pal.muted).padding(.vertical, 6)
                kv(Text("\(prefs.t("cr_hash")) #\(s["round"].int)").font(.inter(12.5)).foregroundColor(pal.muted), s["hash"].string)
                ForEach(Array(s["history"].array.enumerated()), id: \.offset) { _, r in
                    let id = r["id"].int
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 8) {
                            chip(r["point"].double)
                            Text("#\(id)").font(.inter(12.5)).foregroundColor(pal.ink)
                            Spacer()
                            Button {
                                checked[id] = Fair.verifyCrash(seed: r["seed"].string, hash: r["hash"].string, round: id, point: r["point"].double)
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

    private func row(_ left: Text, _ mid: String, _ right: String, _ rightColor: Color) -> some View {
        HStack(spacing: 10) {
            left.lineLimit(1).frame(maxWidth: .infinity, alignment: .leading)
            Text(mid).monospacedDigit().foregroundColor(pal.ink)
            Text(right).monospacedDigit().foregroundColor(rightColor).lineLimit(1).frame(maxWidth: .infinity, alignment: .trailing)
        }
        .font(.inter(14))
        .padding(.vertical, 10)
        .overlay(alignment: .bottom) { Hairline() }
    }

    private func kv(_ label: Text, _ code: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            label
            Text(code).font(.system(size: 11, design: .monospaced)).foregroundColor(pal.ink).textSelection(.enabled)
        }
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .overlay(alignment: .bottom) { Hairline() }
    }

    private func act(_ path: String, _ body: [String: Any] = [:]) async {
        busy = true; msg = ""
        defer { busy = false }
        do {
            _ = try await API.shared.post("/games/crash/\(path)", body)
            Haptic.success()
        } catch {
            let code = (error as? APIError)?.code ?? "service_unavailable"
            msg = prefs.has("err_\(code)") ? prefs.t("err_\(code)") : code
            Haptic.error()
        }
        await model.load()
        await session.refresh()
    }

    private func placeBet() async {
        let amt = Double(amount.replacingOccurrences(of: ",", with: ".")) ?? 0
        let autoX = Double(auto.replacingOccurrences(of: ",", with: ".")) ?? 0
        await act("bet", ["amount": String(floor(amt * 1e4) / 1e4), "auto": autoOn ? String(format: "%.2f", autoX) : ""])
    }

    private func press(_ s: JSON?, amt: Double, autoX: Double, avail: Double, minBet: Double, maxBet: Double, phase: String, hasBet: Bool, riding: Bool) {
        if session.me == nil { router.open(.login); return }
        guard s != nil else { return }
        func valid() -> Bool {
            if !(amt >= minBet && amt <= maxBet) {
                msg = prefs.t("cr_range").replacingOccurrences(of: "{a}", with: prefs.num(minBet)).replacingOccurrences(of: "{b}", with: prefs.num(maxBet))
                return false
            }
            if amt > avail { msg = prefs.t("err_crash_insufficient"); return false }
            if autoOn && !(autoX >= 1.01) { msg = prefs.t("err_crash_invalid_auto"); return false }
            return true
        }
        if phase == "betting" && hasBet { Task { await act("cancel") }; return }
        if phase == "betting" { if valid() { Task { await placeBet() } }; return }
        if riding { Task { await act("cashout") }; return }
        if queued { queued = false; return }
        if valid() { queued = true }
    }
}

/// The live curve and headline (Crash.tsx CrashChart), drawn per frame.
struct CrashCanvas: View {
    @Environment(Prefs.self) private var prefs
    @Environment(\.pal) private var pal
    let s: JSON
    let now: Double

    static let xSteps: [Double] = [0.25, 0.5, 1, 2, 5, 10, 20, 50, 100, 200, 500, 1000, 2000, 5000, 10000, 100000]
    static let tSteps: [Double] = [2000, 5000, 10000, 15000, 30000, 60000, 120000, 300000, 600000]
    static func nice(_ span: Double, _ n: Double, _ steps: [Double]) -> Double { steps.first { span / $0 <= n } ?? steps.last! }

    var body: some View {
        let phase = s["phase"].string
        let growth = s["growth"].double
        var el = 0.0, m = 1.0
        if phase == "running", s["start"].exists { el = now - s["start"].double; m = exp(growth * max(0, el)) }
        if phase == "crashed", s["point"].double > 0 { m = s["point"].double; el = log(m) / max(growth, 1e-9) }
        let busted = phase == "crashed"
        let betLeft = max(0, s["betEnd"].double - now)
        return ZStack(alignment: .top) {
            Canvas { ctx, size in
                let W = size.width, H = size.height
                let xMax = max(10000, el * 1.15)
                let yMax = max(2, 1 + (m - 1) * 1.25)
                let L = 44.0, R = 12.0, T = 14.0, B = 26.0
                func px(_ ms: Double) -> Double { L + ms / xMax * (W - L - R) }
                func py(_ v: Double) -> Double { H - B - (v - 1) / (yMax - 1) * (H - T - B) }
                let ys = CrashCanvas.nice(yMax - 1, 4, CrashCanvas.xSteps)
                var v = 1.0
                while v <= yMax + 1e-9 {
                    let y = py(v).rounded() + 0.5
                    ctx.stroke(Path { p in p.move(to: CGPoint(x: L, y: y)); p.addLine(to: CGPoint(x: W - R, y: y)) }, with: .color(pal.line), lineWidth: 1)
                    let label = v >= 100 ? "\(Int(v.rounded()))x" : "\(String(format: "%g", (v * 100).rounded() / 100))x"
                    ctx.draw(Text(label).font(.system(size: 11)).foregroundColor(pal.muted), at: CGPoint(x: L - 6, y: y), anchor: .trailing)
                    v += ys
                }
                let xs = CrashCanvas.nice(xMax, 5, CrashCanvas.tSteps)
                var ms = 0.0
                while ms <= xMax {
                    ctx.draw(Text("\(Int((ms / 1000).rounded()))s").font(.system(size: 11)).foregroundColor(pal.muted), at: CGPoint(x: px(ms), y: H - B + 7), anchor: .top)
                    ms += xs
                }
                if el > 0 {
                    let col = busted ? pal.red : pal.gold
                    var curve = Path()
                    curve.move(to: CGPoint(x: px(0), y: py(1)))
                    for i in 1...80 {
                        let t = el * Double(i) / 80
                        curve.addLine(to: CGPoint(x: px(t), y: py(min(m, exp(growth * t)))))
                    }
                    var area = curve
                    area.addLine(to: CGPoint(x: px(el), y: py(1)))
                    area.closeSubpath()
                    ctx.fill(area, with: .color(col.opacity(0.16)))
                    ctx.stroke(curve, with: .color(col), style: StrokeStyle(lineWidth: 3, lineJoin: .round))
                    let r = busted ? 5.0 : 6.0
                    let dot = Path(ellipseIn: CGRect(x: px(el) - r, y: py(m) - r, width: 2 * r, height: 2 * r))
                    if !busted {
                        var glow = ctx
                        glow.addFilter(.shadow(color: col, radius: 7))
                        glow.fill(dot, with: .color(col))
                    } else {
                        ctx.fill(dot, with: .color(col))
                    }
                }
            }
            GeometryReader { g in
                VStack(spacing: 0) {
                    Text(phase == "betting" ? prefs.t("cr_starting") : busted ? prefs.t("cr_busted") : " ")
                        .font(.inter(13, .semibold)).foregroundColor(pal.muted).frame(minHeight: 18)
                    Text(phase == "betting" ? String(format: "%.1fs", betLeft / 1000) : CrashPage.fmtX(m))
                        .font(.inter(min(64, max(40, UIScreen.main.bounds.width * 0.11)), .heavy)).monospacedDigit()
                        .foregroundColor(phase == "betting" ? pal.ink : busted ? pal.red : pal.gold)
                    if phase == "betting" {
                        ZStack(alignment: .leading) {
                            Capsule().fill(pal.surface2)
                            Capsule().fill(pal.gold).frame(width: 140 * min(1, betLeft / 7000))
                        }
                        .frame(width: 140, height: 4).padding(.top, 8)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.top, g.size.height * 0.18)
            }
        }
    }
}
