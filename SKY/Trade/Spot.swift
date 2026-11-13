import SwiftUI

/// pages/Spot.tsx, phone layout.
struct SpotPage: View {
    @Environment(Prefs.self) private var prefs
    @Environment(Session.self) private var session
    @Environment(Router.self) private var router
    @Environment(\.pal) private var pal
    let sym: String

    @State var feed = MarketFeed()
    @State var bookModel = BookModel()
    @State var klines = Klines()
    @State var tf = "15m"
    @State var kind = "limit"
    @State var tab = "orders"
    @State var msg = ""
    @State var side = "buy"
    @State var showChart = false
    @State var px = ""
    @State var picker = false
    @State var stepOpen = false

    var body: some View {
        let snap = feed.snap
        let pd = snap?.priceDec ?? 2
        let last = snap.map { $0.last != 0 ? $0.last : $0.mark } ?? 0
        let chg = (snap?.open ?? 0) > 0 ? (last - (snap?.open ?? 0)) / (snap?.open ?? 1) * 100 : 0
        let book = bookModel.book(snap, rows: 8)
        ScrollView {
            VStack(alignment: .leading, spacing: 6) {
                sectionTabs
                head(snap)
                stats(snap, last: last, chg: chg, pd: pd)
                if showChart {
                    VStack(alignment: .leading, spacing: 4) {
                        TimeframeTabs(tf: $tf)
                        if klines.candles.isEmpty {
                            EmptyNote(text: prefs.t(snap != nil && snap?.ref.isEmpty == true ? "collecting" : "connecting"))
                        } else {
                            CandleChart(data: klines.live(last, src: snap?.src ?? ""))
                        }
                    }
                    .padding(.horizontal, 6).padding(.top, 6).padding(.bottom, 2)
                    .background(RoundedRectangle(cornerRadius: 8).fill(pal.surface))
                }
                Columns(ratios: [1.15, 1], spacing: 8) {
                    form(snap, last: last, pd: pd)
                    MiniBook(book: book, last: last, up: chg >= 0, rows: 8, lastText: prefs.num(last, pd), sub: nil,
                             qd: max(0, snap?.qtyDec ?? 3), stepOpen: $stepOpen) { p in
                        kind = "limit"; px = String(format: "%.\(pd)f", p)
                    }
                }
                .padding(8)
                .background(RoundedRectangle(cornerRadius: 8).fill(pal.surface))
                lists
            }
            .font(.inter(11.5))
            .padding(.horizontal, 4).padding(.top, 2).padding(.bottom, 12)
        }
        .onAppear { feed.start(sym, spot: true); bookModel.setSym(sym) }
        .onDisappear { feed.stop(); bookModel.stop(); klines.stop() }
        .onChange(of: last) { _, _ in
            bookModel.follow(feed.snap, fast: bookModel.coarse(feed.snap))
            if showChart { klines.follow(feed.snap, tf: tf) }
        }
        .onChange(of: showChart) { _, on in if on { klines.follow(feed.snap, tf: tf) } }
        .onChange(of: tf) { _, _ in klines.follow(feed.snap, tf: tf) }
        .sheet(isPresented: $picker) { PairPickerSheet(sym: sym, spot: true) }
        .sheet(isPresented: $stepOpen) {
            SkySheet(title: prefs.t("bk_group")) {
                StepList(steps: book.steps, step: book.step) { v in bookModel.setStep(v); stepOpen = false }
            }
        }
    }

    /// 现货 | 预测 | 游戏 (.tt-tabs)
    private var sectionTabs: some View {
        HStack(spacing: 22) {
            Text(prefs.t("spot")).foregroundColor(pal.ink)
            Button(prefs.t("predictNav")) { router.open(.predict) }.foregroundColor(pal.muted).buttonStyle(PlainTap())
            Button(prefs.t("gamesNav")) { router.open(.games) }.foregroundColor(pal.muted).buttonStyle(PlainTap())
        }
        .font(.inter(19, .bold))
        .padding(.horizontal, 14).padding(.top, 6).padding(.bottom, 2)
    }

    private func head(_ snap: Snapshot?) -> some View {
        let cat = snap?.cat ?? "crypto"
        let sub = snap != nil ? "\(prefs.t("spot")) · \(prefs.t(cat == "crypto" ? "crypto" : cat))" : prefs.t("spot")
        let base = snap?.base ?? sym.replacingOccurrences(of: "USDT$", with: "", options: .regularExpression)
        return HStack {
            PairHeader(sym: sym, base: base, icon: snap?.icon ?? "", sub: sub, cat: cat, catSub: snap?.sub ?? "", spot: true, pickerOpen: $picker)
            Spacer()
            IconButton(.chartCandlestick, size: 18, color: showChart ? pal.gold : pal.ink2) { showChart.toggle() }
        }
        .padding(.horizontal, 2).padding(.top, 4)
    }

    private func stats(_ snap: Snapshot?, last: Double, chg: Double, pd: Int) -> some View {
        HStack(alignment: .center, spacing: 8) {
            VStack(alignment: .leading, spacing: 2) {
                Text(last > 0 ? prefs.num(last, pd) : "—").font(.inter(19, .semibold)).monospacedDigit()
                    .foregroundColor(pal.dir(chg)).lineLimit(1).minimumScaleFactor(0.6)
                Text(Fmt.pct(chg)).font(.inter(11)).monospacedDigit().foregroundColor(pal.dir(chg))
                    .padding(.horizontal, 6).padding(.vertical, 1)
                    .background(RoundedRectangle(cornerRadius: 6).fill(pal.dirTint(chg)))
            }
            Spacer(minLength: 0)
            Grid(alignment: .leading, horizontalSpacing: 10, verticalSpacing: 1) {
                GridRow {
                    Text(prefs.t("dayHigh")).foregroundColor(pal.muted)
                    Text((snap?.high ?? 0) > 0 ? prefs.num(snap!.high, pd) : "—").gridColumnAlignment(.trailing)
                }
                GridRow {
                    Text(prefs.t("dayLow")).foregroundColor(pal.muted)
                    Text((snap?.low ?? 0) > 0 ? prefs.num(snap!.low, pd) : "—").gridColumnAlignment(.trailing)
                }
                GridRow {
                    Text(prefs.t("dayVolume")).foregroundColor(pal.muted)
                    Text(prefs.num(snap?.volUsdt ?? 0, 0)).gridColumnAlignment(.trailing)
                }
            }
            .font(.inter(10.5)).monospacedDigit().foregroundColor(pal.ink).lineLimit(1)
        }
        .padding(.horizontal, 4)
    }

    private func form(_ snap: Snapshot?, last: Double, pd: Int) -> some View {
        let acct = session.account
        let tier = VIP.of(acct).spot
        let bal = acct?.balances.first { $0.sym == sym }
        let fee = kind == "market" ? tier.spotTaker : tier.spotMaker
        return VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 2) {
                sideButton("buy", prefs.t("buyBtn"), pal.green)
                sideButton("sell", prefs.t("sellBtn"), pal.red)
            }
            .padding(2)
            .background(RoundedRectangle(cornerRadius: 6).fill(pal.surface2))
            Tabs(items: [("limit", prefs.t("limit")), ("market", prefs.t("market"))], value: $kind, size: 12, gap: 14, padBottom: 4)
            SideForm(side: side, kind: kind, base: snap?.base ?? "", pd: pd, qd: snap?.qtyDec ?? 3, last: last, px: $px,
                     free: side == "buy" ? (acct?.available ?? 0) : (bal?.free ?? 0),
                     live: feed.state == "live", fee: fee) { s, q, p in
                await submit(s, q, p)
            }
            .id(side + sym)
            if !msg.isEmpty { Text(msg).font(.inter(11.5)).foregroundColor(pal.red).frame(maxWidth: .infinity) }
        }
    }

    private func sideButton(_ id: String, _ label: String, _ color: Color) -> some View {
        Button { side = id; Haptic.tap() } label: {
            Text(label).font(.inter(12, .semibold)).foregroundColor(side == id ? .white : pal.muted)
                .frame(maxWidth: .infinity).frame(height: 26)
                .background(RoundedRectangle(cornerRadius: 5).fill(side == id ? color : .clear))
        }
        .buttonStyle(PlainTap())
    }

    private func submit(_ s: String, _ q: Double, _ p: Double) async {
        msg = ""
        let r = await session.place(["market": "spot", "symbol": sym, "side": s, "type": kind, "price": p, "qty": q])
        if !r.ok {
            msg = "\(prefs.t("rejected")): \(r.reason.isEmpty ? r.json["status"].string : prefs.t("err_\(r.reason)"))"
            Haptic.error()
        } else {
            Haptic.success()
            if r.json["rested"].bool { tab = "orders" }
        }
    }

    private var lists: some View {
        let acct = session.account
        let orders = (acct?.orders ?? []).filter { $0.spot }
        let balances = acct?.balances ?? []
        return VStack(alignment: .leading, spacing: 0) {
            ScrollView(.horizontal, showsIndicators: false) {
                Tabs(items: [("orders", withCount(prefs.t("orders"), orders.count)),
                             ("holdings", "\(prefs.t("holdingsSpot")) (\(balances.count))")],
                     value: $tab, size: 12, gap: 16, padBottom: 6)
            }
            .overlay(alignment: .bottom) { Hairline() }
            if tab == "orders" {
                if orders.isEmpty { EmptyNote(text: "—", pad: 20) }
                ForEach(Array(orders.enumerated()), id: \.element.id) { i, o in
                    MItem(title: "\(o.sym.replacingOccurrences(of: "USDT$", with: "", options: .regularExpression))/USDT",
                          tag: (o.side == "buy" ? prefs.t("buyBtn") : prefs.t("sellBtn"), o.side == "buy"),
                          action: (prefs.t("cancel"), { Task { await session.cancel(o.id) } }),
                          onTitle: { router.go(.spot(o.sym)) },
                          fields: [(prefs.t("price"), prefs.num(o.price, o.priceDec), nil),
                                   (prefs.t("quantity"), prefs.num(o.qty, max(0, o.qtyDec)), nil),
                                   (prefs.t("orderTotal"), prefs.num(o.price * o.qty, 2), nil)])
                    if i < orders.count - 1 { Hairline() }
                }
            } else {
                if balances.isEmpty { EmptyNote(text: "—", pad: 20) }
                ForEach(Array(balances.enumerated()), id: \.element.id) { i, b in
                    MItem(title: b.base, onTitle: { router.go(.spot(b.sym)) },
                          fields: [(prefs.t("available"), prefs.num(b.free, max(0, b.qtyDec)), nil),
                                   (prefs.t("avgCost"), prefs.num(b.avgCost, b.priceDec), nil),
                                   (prefs.t("value"), prefs.num(b.value), nil),
                                   (prefs.t("pnl"), "\(b.pnl >= 0 ? "+" : "−")\(prefs.num(abs(b.pnl)))", pal.dir(b.pnl))])
                    if i < balances.count - 1 { Hairline() }
                }
            }
        }
        .padding(.horizontal, 10).padding(.top, 8).padding(.bottom, 2)
        .background(RoundedRectangle(cornerRadius: 8).fill(pal.surface))
    }
}

/// One side of the spot order form (Spot.tsx SideForm).
struct SideForm: View {
    @Environment(Prefs.self) private var prefs
    @Environment(Session.self) private var session
    @Environment(Router.self) private var router
    @Environment(\.pal) private var pal
    let side: String
    let kind: String
    let base: String
    let pd: Int
    let qd: Int
    let last: Double
    @Binding var px: String
    let free: Double
    let live: Bool
    let fee: Double
    let onSubmit: (String, Double, Double) async -> Void
    @State var amt = ""

    var body: some View {
        let loggedIn = session.me != nil
        let qDigits = max(0, qd)
        let step = pow(10, -Double(qd))
        let price = kind == "market" ? last : ((Double(px) ?? 0) > 0 ? Double(px)! : last)
        let qty = Double(amt) ?? 0
        let total = price * qty
        let fit: (Double) -> String = { String(format: "%.\(qDigits)f", floor($0 / step) * step) }
        let maxQty = price <= 0 ? 0 : side == "buy" ? free / price / (1 + max(fee, 0)) : free
        let pctNow = maxQty > 0 ? min(100, qty / maxQty * 100) : 0
        let enough = side == "buy" ? total * (1 + max(fee, 0)) <= free : qty <= free + 1e-12
        let ok = loggedIn && live && qty > 0 && enough
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(prefs.t("available")).foregroundColor(pal.muted)
                Spacer()
                Text("\(prefs.num(free, side == "buy" ? 2 : qDigits)) \(side == "buy" ? "USDT" : base)").monospacedDigit().foregroundColor(pal.ink)
            }
            .font(.inter(11)).lineLimit(1)
            FormInput(label: prefs.t("price"), text: kind == "market" ? .constant(prefs.t("market")) : $px,
                      placeholder: last > 0 ? String(format: "%.\(pd)f", last) : "", unit: "USDT", disabled: kind == "market")
            FormInput(label: prefs.t("quantity"), text: $amt, unit: base)
            PctSlider(value: pctNow, disabled: !loggedIn || maxQty <= 0) { v in
                if price > 0 { amt = v <= 0 ? "" : fit(maxQty * v / 100) }
            }
            FormInput(label: prefs.t("orderTotal"),
                      text: Binding(get: { total > 0 ? String(format: "%.2f", total) : "" },
                                    set: { s in if price > 0 { amt = fit((Double(s) ?? 0) / price) } }),
                      placeholder: "0.00", unit: "USDT")
            HStack {
                Text(prefs.t("fee"))
                Spacer()
                Text("≈ \(prefs.num(total * fee, 4)) USDT").monospacedDigit()
            }
            .font(.inter(11.5)).foregroundColor(pal.muted)
            if loggedIn {
                Button("\(side == "buy" ? prefs.t("buyBtn") : prefs.t("sellBtn")) \(base)") {
                    Task { await onSubmit(side, qty, price); amt = "" }
                }
                .btn(side == "buy" ? .long : .short, wide: true)
                .disabled(!ok)
            } else {
                Button(prefs.t("login")) { router.open(.login) }.btn(.gold, wide: true)
            }
        }
    }
}
