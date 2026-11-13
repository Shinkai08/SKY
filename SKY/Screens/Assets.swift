import SwiftUI

/// pages/Assets.tsx: total value, today's P&L, four actions, balances.
struct AssetsPage: View {
    @Environment(Prefs.self) private var prefs
    @Environment(Session.self) private var session
    @Environment(Router.self) private var router
    @Environment(\.pal) private var pal
    @State private var panel = ""
    @State private var today: (pnl: Double, ret: Double)?

    var body: some View {
        if session.me == nil {
            VStack(alignment: .leading, spacing: 16) {
                Text(prefs.t("loginToTrade")).font(.inter(16, .semibold)).foregroundColor(pal.ink)
                HStack(spacing: 10) {
                    Button(prefs.t("login")) { router.open(.login) }.btn(.gold)
                    Button(prefs.t("register")) { router.open(.register) }.btn()
                }
            }
            .padding(20)
            .card(0)
        } else {
            wallet
        }
    }

    private var wallet: some View {
        let a = session.account
        let hide = prefs.hideBalance
        let v: (Double, Int) -> String = { n, d in hide ? "******" : prefs.num(n, d) }
        let pnl = today?.pnl ?? 0, ret = today?.ret ?? 0
        return VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Button { prefs.hideBalance.toggle() } label: {
                        HStack(spacing: 8) {
                            Text(prefs.t("totalValue")).font(.inter(16)).foregroundColor(pal.ink)
                            Icon(hide ? .eyeOff : .eye, 16).foregroundColor(pal.muted)
                        }
                    }
                    .buttonStyle(PlainTap())
                    Spacer()
                    IconButton(.history, size: 20) { panel = panel == "history" ? "" : "history" }
                }
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(v(a?.total ?? 0, 2)).font(.inter(32, .bold)).monospacedDigit().foregroundColor(pal.ink)
                        .lineLimit(1).minimumScaleFactor(0.5)
                    HStack(spacing: 2) {
                        Text("USDT")
                        Icon(.chevronDown, 14)
                    }
                    .font(.inter(15, .semibold)).foregroundColor(pal.ink2)
                }
                HStack(spacing: 8) {
                    Text(prefs.t("todayPnl")).foregroundColor(pal.muted)
                        .overlay(alignment: .bottom) {
                            Line().stroke(pal.muted, style: StrokeStyle(lineWidth: 1, dash: [1, 2])).frame(height: 1).offset(y: 1)
                        }
                    Text(hide ? "******" : "\(pnl >= 0 ? "+" : "−")\(prefs.num(abs(pnl))) USDT (\(ret >= 0 ? "+" : "−")\(prefs.num(abs(ret), 2))%)")
                        .monospacedDigit().foregroundColor(pal.dir(pnl))
                }
                .font(.inter(12.5))
            }
            .padding(.horizontal, 2).padding(.vertical, 4)

            HStack(spacing: 8) {
                action("deposit", .arrowDown, prefs.t("deposit"))
                action("withdraw", .arrowUp, prefs.t("withdraw"))
                action("transfer", .arrowLeftRight, prefs.t("transfer"))
                action("trade", .candlestickChart, prefs.t("trade"))
            }

            if !panel.isEmpty {
                ZStack(alignment: .topTrailing) {
                    VStack(alignment: .leading, spacing: 8) {
                        switch panel {
                        case "deposit": DepositPanel()
                        case "withdraw":
                            Text(prefs.t("withdraw")).font(.inter(14.5, .semibold)).foregroundColor(pal.ink)
                            Text(prefs.t("demoNote")).font(.inter(12.5)).foregroundColor(pal.muted)
                        case "transfer":
                            Text(prefs.t("transfer")).font(.inter(14.5, .semibold)).foregroundColor(pal.ink)
                            Text(prefs.t("transferNote")).font(.inter(12.5)).foregroundColor(pal.muted)
                        default: DepositHistory()
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    IconButton(.x, size: 18) { panel = "" }
                }
                .card()
            }

            VStack(alignment: .leading, spacing: 0) {
                Text(prefs.t("balance")).font(.inter(15, .medium)).foregroundColor(pal.muted)
                    .padding(.bottom, 6)
                balanceRow(sym: "USDT", name: "TetherUS", amount: v(a?.equity ?? 0, 8), value: v(a?.equity ?? 0, 2), first: true) {
                    router.go(.trade("BTCUSDT"))
                }
                ForEach(a?.balances ?? []) { b in
                    balanceRow(sym: b.base, name: b.sym == "SKY-STOCKUSDT" ? "SKY" : prefs.t(b.cat == "crypto" ? "crypto" : b.cat),
                               amount: hide ? "******" : prefs.num(b.free + b.locked, max(0, b.qtyDec)), value: v(b.value, 2), first: false) {
                        router.go(.spot(b.sym))
                    }
                }
            }
            .card()
        }
        .task(id: session.me?.id) {
            guard let me = session.me else { return }
            while !Task.isCancelled {
                if let p = try? await API.shared.get("/users/\(me.id)/perf?days=1") {
                    today = (pnl: p["rangePnl"].double, ret: p["rangeRet"].double)
                }
                try? await Task.sleep(nanoseconds: 15_000_000_000)
            }
        }
    }

    private func action(_ id: String, _ icon: Lucide, _ label: String) -> some View {
        let on = panel == id
        return Button {
            Haptic.tap()
            if id == "trade" { router.go(.trade("BTCUSDT")) } else { panel = on ? "" : id }
        } label: {
            VStack(spacing: 8) {
                Icon(icon, 22, stroke: 1.8)
                    .foregroundColor(on ? pal.gold : pal.ink)
                    .frame(width: 52, height: 52)
                    .background(RoundedRectangle(cornerRadius: 16).fill(on ? pal.goldTint : pal.surface2))
                Text(label).font(.inter(14)).foregroundColor(pal.ink).lineLimit(1)
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(PlainTap())
    }

    private func balanceRow(sym: String, name: String, amount: String, value: String, first: Bool, trade: @escaping () -> Void) -> some View {
        VStack(spacing: 0) {
            if !first { Hairline() }
            HStack(alignment: .top, spacing: 12) {
                Token(sym: sym, size: 36)
                VStack(alignment: .leading, spacing: 4) {
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 0) {
                            Text(sym).font(.inter(16, .semibold)).foregroundColor(pal.ink)
                            Text(name).font(.inter(12.5)).foregroundColor(pal.muted)
                        }
                        Spacer()
                        VStack(alignment: .trailing, spacing: 0) {
                            Text(amount).font(.inter(16, .semibold)).monospacedDigit().foregroundColor(pal.ink).lineLimit(1).minimumScaleFactor(0.6)
                            Text("≈ \(value) USDT").font(.inter(12.5)).monospacedDigit().foregroundColor(pal.muted).lineLimit(1)
                        }
                    }
                    HStack {
                        Spacer()
                        Button(prefs.t("trade"), action: trade).btn(.plain, .sm).frame(minWidth: 84)
                    }
                    .padding(.top, 6)
                }
            }
            .padding(.vertical, 14)
        }
    }
}

struct Line: Shape {
    func path(in r: CGRect) -> Path { Path { p in p.move(to: CGPoint(x: 0, y: r.midY)); p.addLine(to: CGPoint(x: r.width, y: r.midY)) } }
}

private struct DepMeta {
    var assets: [(symbol: String, name: String, chains: [String], min: Double)] = []
    var chains: [String: (name: String, network: String, confirmations: Int)] = [:]
    var simulate = false
    init() {}
    init(_ j: JSON) {
        assets = j["assets"].array.map { a in
            (symbol: a["symbol"].string, name: a["name"].string, chains: a["chains"].array.map { $0.string }, min: a["minDeposit"].double)
        }
        for (k, c) in j["chains"].dict {
            chains[k] = (name: c["name"].string, network: c["network"].string, confirmations: c["confirmations"].int)
        }
        simulate = j["simulate"].bool
    }
}

/// Deposit form (Assets.tsx DepositPanel).
struct DepositPanel: View {
    @Environment(Prefs.self) private var prefs
    @Environment(\.pal) private var pal
    @State private var meta = DepMeta()
    @State private var asset = "USDT"
    @State private var chain = "TRX"
    @State private var addr: (address: String, demo: Bool)?
    @State private var addrErr = ""
    @State private var copied = false
    @State private var amount = "100"
    @State private var msg = ""

    var body: some View {
        let cur = meta.assets.first { $0.symbol == asset }
        let ch = meta.chains[chain]
        VStack(alignment: .leading, spacing: 12) {
            Text(prefs.t("deposit")).font(.inter(14.5, .semibold)).foregroundColor(pal.ink)
            field(prefs.t("selectAsset")) {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 2), spacing: 6) {
                    ForEach(meta.assets.indices, id: \.self) { i in
                        let x = meta.assets[i]
                        net(x.symbol, x.name, on: asset == x.symbol) { asset = x.symbol }
                    }
                }
            }
            field(prefs.t("network")) {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 2), spacing: 8) {
                    ForEach(cur?.chains ?? [], id: \.self) { c in
                        net(meta.chains[c]?.name ?? c, meta.chains[c]?.network ?? "", on: chain == c) { chain = c }
                    }
                }
            }
            field(prefs.t("depositAddress")) {
                HStack(spacing: 8) {
                    Text(addr?.address ?? (addrErr.isEmpty ? "…" : addrErr))
                        .font(.system(size: 12, design: .monospaced)).foregroundColor(pal.ink)
                        .textSelection(.enabled)
                        .padding(.horizontal, 12).padding(.vertical, 10)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(RoundedRectangle(cornerRadius: 8).fill(pal.surface2))
                    Button {
                        guard let a = addr?.address else { return }
                        UIPasteboard.general.string = a
                        copied = true
                        Haptic.success()
                    } label: {
                        HStack(spacing: 6) { Icon(copied ? .check : .copy, 14); Text(copied ? prefs.t("copied") : prefs.t("copy")) }
                    }
                    .btn(.plain, .sm).disabled(addr == nil)
                }
            }
            if let addr {
                HStack(alignment: .top, spacing: 8) {
                    Icon(.triangleAlert, 15).padding(.top, 1)
                    Text(addr.demo ? prefs.t("demoAddrWarn")
                         : prefs.t("liveAddrNote", ["asset": asset, "network": "\(ch?.name ?? chain) (\(ch?.network ?? ""))"]))
                        .font(.inter(12.5))
                }
                .foregroundColor(addr.demo ? pal.red : pal.gold)
                .padding(.horizontal, 12).padding(.vertical, 10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(RoundedRectangle(cornerRadius: 8).fill(addr.demo ? pal.redTint : pal.goldTint))
            }
            VStack(spacing: 6) {
                KV(k: prefs.t("minDeposit"), v: "\(cur.map { prefs.num($0.min, $0.min < 1 ? 4 : 0) } ?? "") \(asset)", size: 12.5)
                KV(k: prefs.t("confirmations"), v: "\(ch?.confirmations ?? 0)", size: 12.5)
            }
            Text(prefs.t("convertNote")).font(.inter(11.5)).foregroundColor(pal.muted)
            if meta.simulate {
                VStack(alignment: .leading, spacing: 8) {
                    Text(prefs.t("simulateDeposit")).font(.inter(12.5)).foregroundColor(pal.ink)
                    HStack(spacing: 10) {
                        FormInput(label: prefs.t("amount"), text: $amount, unit: asset, height: 38)
                        Button(prefs.t("submit")) { Task { await simulate() } }.btn(.gold)
                    }
                    if !msg.isEmpty { Text(msg).font(.inter(12.5)).foregroundColor(pal.ink) }
                }
                .padding(12)
                .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(pal.line, style: StrokeStyle(lineWidth: 1, dash: [4, 3])))
            }
        }
        .task {
            if let j = try? await API.shared.get("/deposit/assets") { meta = DepMeta(j) }
        }
        .task(id: "\(asset)|\(chain)|\(meta.assets.count)") {
            guard let cur = meta.assets.first(where: { $0.symbol == asset }) else { return }
            if !cur.chains.contains(chain) { chain = cur.chains.first ?? chain; return }
            addr = nil; addrErr = ""
            do {
                let j = try await API.shared.get("/deposit/address?asset=\(asset)&chain=\(chain)")
                addr = (address: j["address"].string, demo: j["demo"].bool)
            } catch let e as APIError {
                let k = "err_\(e.code)"
                addrErr = prefs.has(k) ? prefs.t(k) : e.code
            } catch {}
        }
        .task(id: copied) {
            guard copied else { return }
            try? await Task.sleep(nanoseconds: 1_500_000_000)
            copied = false
        }
    }

    private func simulate() async {
        msg = ""
        do {
            _ = try await API.shared.post("/deposit/simulate", ["asset": asset, "chain": chain, "amount": Double(amount) ?? 0])
            msg = prefs.t("saved")
        } catch let e as APIError { msg = e.code } catch { msg = "error" }
    }

    private func field<C: View>(_ label: String, @ViewBuilder _ content: () -> C) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label).font(.inter(12.5)).foregroundColor(pal.muted)
            content()
        }
    }

    private func net(_ title: String, _ sub: String, on: Bool, _ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 0) {
                Text(title).font(.inter(13, .semibold)).foregroundColor(pal.ink)
                Text(sub).font(.inter(11.5)).foregroundColor(pal.muted).lineLimit(1)
            }
            .padding(.horizontal, 10).padding(.vertical, 8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 8).fill(on ? pal.goldTint : pal.surface2))
            .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(on ? pal.gold : .clear, lineWidth: 1))
        }
        .buttonStyle(PlainTap())
    }
}

/// Deposit records (Assets.tsx DepositHistory).
struct DepositHistory: View {
    @Environment(Prefs.self) private var prefs
    @Environment(\.pal) private var pal
    @State private var deps: [JSON] = []
    @State private var chains: [String: String] = [:]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(prefs.t("depositRecords")).font(.inter(14.5, .semibold)).foregroundColor(pal.ink)
            if deps.isEmpty {
                Text(prefs.t("noData")).font(.inter(12.5)).foregroundColor(pal.muted)
            } else {
                ForEach(deps.indices, id: \.self) { i in
                    let d = deps[i]
                    VStack(spacing: 0) {
                        Hairline()
                        HStack(alignment: .top, spacing: 10) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("\(d["amount"].string) \(d["asset"].string)").font(.inter(13, .semibold)).foregroundColor(pal.ink)
                                Text("\(chains[d["chain"].string] ?? d["chain"].string) · \(d["created"].string.prefix(19).replacingOccurrences(of: "T", with: " "))")
                                    .font(.inter(11.5)).foregroundColor(pal.muted)
                            }
                            Spacer()
                            VStack(alignment: .trailing, spacing: 2) {
                                if d["status"].string == "credited" {
                                    statusTag(prefs.t("status_credited"), pal.green, pal.greenTint)
                                    Text("+\(prefs.num(d["creditUsdt"].double)) USDT").font(.inter(11.5)).monospacedDigit().foregroundColor(pal.muted)
                                } else {
                                    statusTag("\(prefs.t("status_confirming")) \(d["confirmations"].int)/\(d["required"].int)", pal.gold, pal.goldTint)
                                }
                            }
                        }
                        .padding(.vertical, 10)
                    }
                }
            }
        }
        .task {
            if let m = try? await API.shared.get("/deposit/assets") {
                for (k, c) in m["chains"].dict { chains[k] = c["name"].string }
            }
            while !Task.isCancelled {
                if let d = try? await API.shared.get("/deposits") { deps = d.array }
                try? await Task.sleep(nanoseconds: 3_000_000_000)
            }
        }
    }

    private func statusTag(_ s: String, _ fg: Color, _ bg: Color) -> some View {
        Text(s).font(.inter(12)).foregroundColor(fg).padding(.horizontal, 8).padding(.vertical, 2)
            .background(RoundedRectangle(cornerRadius: 4).fill(bg))
    }
}
