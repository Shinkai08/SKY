import SwiftUI

/// "持仓 (0)" → "持仓 (3)".
func withCount(_ label: String, _ n: Int) -> String {
    label.replacingOccurrences(of: "\\(\\d+\\)", with: "(\(n))", options: .regularExpression)
}

/// pages/Trade.tsx, phone layout (.m-trade).
struct TradePage: View {
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
    @State var lev: Double = 20
    @State var mode = UserDefaults.standard.string(forKey: "sky.marginMode") == "cross" ? "cross" : "isolated"
    @State var limitPx = ""
    @State var size = ""
    @State var tab = "pos"
    @State var msg = ""
    @State var showChart = Demo.arg("-screen") == "trade-chart"
    @State var notice = ""
    @State var picker = false
    @State var stepOpen = false
    @State var levSheet = false
    @State var now = Date()

    var body: some View {
        let snap = feed.snap
        let pd = snap?.priceDec ?? 2
        let last = snap.map { $0.last != 0 ? $0.last : $0.mark } ?? 0
        let mark = snap?.mark ?? 0
        let chg = (snap?.open ?? 0) > 0 ? (last - (snap?.open ?? 0)) / (snap?.open ?? 1) * 100 : 0
        let book = bookModel.book(snap, rows: 9)
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 6) {
                    Color.clear.frame(height: 0).id("top")
                    head(snap)
                    stats(snap, last: last, mark: mark, chg: chg, pd: pd)
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
                    HStack(alignment: .top, spacing: 8) {
                        form(snap, last: last, pd: pd, book: book)
                            .frame(maxWidth: .infinity)
                            .layoutPriority(1.15)
                        MiniBook(book: book, last: last, up: chg >= 0, rows: 9, lastText: prefs.num(last, pd),
                                 sub: mark > 0 ? prefs.num(mark, pd) : nil, qd: max(0, snap?.qtyDec ?? 3), stepOpen: $stepOpen) { p in
                            kind = "limit"; limitPx = String(format: "%.\(pd)f", p)
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .padding(8)
                    .background(RoundedRectangle(cornerRadius: 8).fill(pal.surface))
                    lists { proxy.scrollTo("top", anchor: .top) }
                }
                .font(.inter(11.5))
                .padding(.horizontal, 4).padding(.top, 2).padding(.bottom, 12)
            }
        }
        .toast($notice)
        .onAppear {
            feed.start(sym, spot: false)
            bookModel.setSym(sym)
        }
        .onDisappear { feed.stop(); bookModel.stop(); klines.stop() }
        .onChange(of: feed.state) { _, s in
            guard s == "live", let snap = feed.snap else { return }
            lev = max(1, min(lev, snap.maxLev > 0 ? snap.maxLev : 200))
            if size.isEmpty {
                let step = pow(10, -Double(snap.qtyDec))
                size = String(format: "%.\(max(0, snap.qtyDec))f", max(step, floor(100 / max(snap.mark, 1e-9) / step) * step))
            }
        }
        .onChange(of: last) { _, _ in
            bookModel.follow(feed.snap, fast: bookModel.coarse(feed.snap))
            if showChart { klines.follow(feed.snap, tf: tf) }
        }
        .onChange(of: showChart) { _, on in if on { klines.follow(feed.snap, tf: tf) } }
        .onChange(of: tf) { _, _ in klines.follow(feed.snap, tf: tf) }
        .onReceive(Timer.publish(every: 1, on: .main, in: .common).autoconnect()) { now = $0 }
        .sheet(isPresented: $picker) { PairPickerSheet(sym: sym) }
        .sheet(isPresented: $stepOpen) {
            SkySheet(title: prefs.t("bk_group")) {
                StepList(steps: book.steps, step: book.step) { v in bookModel.setStep(v); stepOpen = false }
            }
        }
        .sheet(isPresented: $levSheet) {
            if let pos = session.account?.positions.first(where: { $0.sym == sym }) {
                LeverageSheet(ps: pos, acct: session.account, cap: pos.maxLev ?? (snap?.maxLev ?? 200)) { notice = $0 }
            }
        }
    }

    // MARK: header

    private func head(_ snap: Snapshot?) -> some View {
        let cat = snap?.cat ?? "crypto"
        let catText = cat == "onchain" ? (snap?.sub.isEmpty == false ? snap!.sub : prefs.t("onchain")) : prefs.t(cat == "crypto" ? "crypto" : cat)
        let sub = snap != nil ? "\(prefs.t("perpetual")) · \(catText)" : prefs.t("perpetual")
        let base = snap?.base ?? sym.replacingOccurrences(of: "USDT$|@.*$", with: "", options: .regularExpression)
        return HStack {
            PairHeader(sym: sym, base: base, icon: snap?.icon ?? "", sub: sub, cat: cat, catSub: snap?.sub ?? "", pickerOpen: $picker)
            Spacer()
            IconButton(.chartCandlestick, size: 18, color: showChart ? pal.gold : pal.ink2) { showChart.toggle() }
        }
        .padding(.horizontal, 2).padding(.top, 4)
    }

    private func stats(_ snap: Snapshot?, last: Double, mark: Double, chg: Double, pd: Int) -> some View {
        let s = Int(max(0, ((snap?.nextFunding ?? 0) - now.timeIntervalSince1970 * 1000) / 1000))
        let countdown = String(format: "%02d:%02d:%02d", s / 3600, (s % 3600) / 60, s % 60)
        return HStack(alignment: .center, spacing: 8) {
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
                    Text(prefs.t("mark")).foregroundColor(pal.muted)
                    Text(mark > 0 ? prefs.num(mark, pd) : "—").gridColumnAlignment(.trailing)
                }
                GridRow {
                    Text(prefs.t("funding")).foregroundColor(pal.muted)
                    (Text(VIP.pct(snap?.funding ?? 0)).foregroundColor(pal.gold) + Text(" · \(countdown)"))
                        .gridColumnAlignment(.trailing)
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

    // MARK: order form

    @ViewBuilder private func form(_ snap: Snapshot?, last: Double, pd: Int, book: GroupedBook) -> some View {
        let acct = session.account
        let loggedIn = session.me != nil
        let qd = snap?.qtyDec ?? 3
        let qDigits = max(0, qd)
        let step = pow(10, -Double(qd))
        let tier = VIP.of(acct).perp
        let maxLev = snap?.maxLev ?? 200
        let myPos = acct?.positions.first { $0.sym == sym }
        let bestAsk = snap?.asks.first?.p ?? last, bestBid = snap?.bids.first?.p ?? last
        let px = kind == "market" ? last : (Double(limitPx) ?? 0) > 0 ? Double(limitPx)! : last
        let qty = Double(size) ?? 0
        let notional = px * qty
        let useLev = myPos?.lev ?? lev
        let useMode = myPos.map { $0.isolated ? "isolated" : "cross" } ?? mode
        let margin = notional / max(useLev, 1)
        let takerLong = kind == "market" || px >= bestAsk
        let takerShort = kind == "market" || px <= bestBid
        let rateLong = takerLong ? tier.perpTaker : tier.perpMaker
        let rateShort = takerShort ? tier.perpTaker : tier.perpMaker
        let estFee = notional * max(rateLong, rateShort)
        let avail = acct?.available ?? 0
        let liq = { (long: Bool) -> Double in
            if px <= 0 || qty <= 0 { return 0 }
            if useMode == "isolated" { return isolatedLiq(entry: px, lev: useLev, long: long) }
            let cross = (acct?.positions ?? []).filter { !$0.isolated && $0.sym != sym }
            let eq = avail + cross.reduce(0) { $0 + $1.margin } - max(0, estFee)
            let maint = cross.reduce(0) { $0 + $1.maint } + mmrFor(useLev) * notional
            let q = long ? qty : -qty
            let v = px + (maint - eq) / (q - mmrFor(useLev) * qty)
            return v > 0 && v.isFinite ? v : 0
        }
        let liqLong = liq(true), liqShort = liq(false)
        let canOpen = loggedIn && feed.state == "live" && qty > 0 && margin + max(0, estFee) <= avail
        let maxQty = px > 0 ? (avail * useLev * 0.98) / px : 0
        let pctNow = maxQty > 0 ? min(100, qty / maxQty * 100) : 0
        let p: (Double) -> String = { prefs.num($0, pd) }

        VStack(alignment: .leading, spacing: 6) {
            // cross / isolated
            HStack(spacing: 4) {
                ForEach(["cross", "isolated"], id: \.self) { m in
                    Button {
                        mode = m
                        UserDefaults.standard.set(m, forKey: "sky.marginMode")
                    } label: {
                        Text(prefs.t(m)).font(.inter(11)).foregroundColor(useMode == m ? pal.ink : pal.muted)
                            .frame(maxWidth: .infinity).frame(height: 22)
                            .background(RoundedRectangle(cornerRadius: 6).fill(useMode == m ? pal.hover : .clear)
                                .shadow(color: .black.opacity(useMode == m ? 0.2 : 0), radius: 1, x: 0, y: 1))
                    }
                    .buttonStyle(PlainTap())
                    .disabled(myPos != nil)
                }
            }
            .padding(3)
            .background(RoundedRectangle(cornerRadius: 8).fill(pal.surface2))

            LeverageRow(lev: Binding(get: { useLev }, set: { if myPos == nil { lev = min(maxLev, max(1, $0)) } }),
                        cap: maxLev, disabled: myPos != nil, compact: true)
            if let myPos, myPos.maxLev != nil {
                Button(prefs.t("pc_levTitle")) { levSheet = true }
                    .font(.inter(12)).foregroundColor(pal.gold)
                    .padding(.horizontal, 10).frame(height: 26)
                    .overlay(RoundedRectangle(cornerRadius: 7).strokeBorder(pal.gold, lineWidth: 1))
                    .buttonStyle(PlainTap())
            }
            if useLev > 100 { Text(prefs.t("highLevWarn")).font(.inter(11.5)).foregroundColor(pal.red) }

            Tabs(items: [("limit", prefs.t("limit")), ("market", prefs.t("market"))], value: $kind, size: 12, gap: 14, padBottom: 4)
            HStack {
                Text(prefs.t("available")).foregroundColor(pal.muted)
                Spacer()
                Text("\(prefs.num(avail)) USDT").monospacedDigit().foregroundColor(pal.ink)
            }
            .font(.inter(11))
            FormInput(label: prefs.t("orderPrice"), text: kind == "market" ? .constant(prefs.t("market")) : $limitPx,
                      placeholder: last > 0 ? String(format: "%.\(pd)f", last) : "", unit: "USDT", disabled: kind == "market")
            FormInput(label: prefs.t("size"), text: $size, unit: snap?.base ?? "")
            PctSlider(value: pctNow, disabled: !loggedIn || maxQty <= 0) { v in
                size = v <= 0 ? "" : String(format: "%.\(qDigits)f", floor((maxQty * v / 100) / step) * step)
            }
            if !loggedIn {
                VStack(spacing: 6) {
                    Text(prefs.t("loginToTrade")).font(.inter(11)).foregroundColor(pal.muted).frame(maxWidth: .infinity)
                    Button(prefs.t("login")) { router.open(.login) }.btn(.gold, wide: true).controlSize(.small)
                    Button(prefs.t("register")) { router.open(.register) }.btn(.plain, wide: true)
                }
            } else {
                HStack(spacing: 5) {
                    Button(prefs.t("long")) { Task { await open(true, px: px, qty: qty, lev: useLev, mode: useMode, pd: pd) } }
                        .btn(.long, wide: true).disabled(!canOpen)
                    Button(prefs.t("short")) { Task { await open(false, px: px, qty: qty, lev: useLev, mode: useMode, pd: pd) } }
                        .btn(.short, wide: true).disabled(!canOpen)
                }
            }
            if !msg.isEmpty { Text(msg).font(.inter(11)).foregroundColor(pal.red).frame(maxWidth: .infinity) }
            VStack(spacing: 2) {
                KV(k: prefs.t("estimate"), v: "\(prefs.num(margin)) USDT")
                KV(k: prefs.t("fee"), v: "\(prefs.num(estFee, 4)) USDT")
                KV(k: "\(prefs.t("feeRate")) · \(tierName(tier.level, prefs))", v: "\(VIP.pct(tier.perpMaker)) / \(VIP.pct(tier.perpTaker))")
                KV(k: "\(prefs.t("liqPrice")) · \(prefs.t("long"))",
                   v: myPos != nil ? (myPos!.liq > 0 ? p(myPos!.liq) : "—") : liqLong > 0 ? p(liqLong) : "—", color: pal.red)
                KV(k: "\(prefs.t("liqPrice")) · \(prefs.t("short"))",
                   v: myPos != nil ? (myPos!.liq > 0 ? p(myPos!.liq) : "—") : liqShort > 0 ? p(liqShort) : "—", color: pal.red)
                KV(k: prefs.t("maintMargin"), v: "\(prefs.num(mmrFor(useLev) * 100, 2))%")
            }
        }
        .font(.inter(11))
    }

    private func open(_ long: Bool, px: Double, qty: Double, lev: Double, mode: String, pd: Int) async {
        msg = ""
        let r = await session.place(["symbol": sym, "side": long ? "buy" : "sell", "type": kind, "price": px, "qty": qty,
                                     "leverage": Int(lev), "marginMode": mode])
        if !r.ok {
            msg = "\(prefs.t("rejected")): \(r.reason.isEmpty ? r.json["status"].string : prefs.t("err_\(r.reason)"))"
            Haptic.error()
        } else {
            Haptic.success()
            tab = r.json["rested"].bool ? "orders" : "pos"
            let filled = r.json["filled"].double, price = r.json["price"].double
            msg = ""
            if filled > 0 && price > 0 { notice = "\(prefs.t("filledAt")) \(prefs.num(price, pd)) · \(prefs.t("houseFill"))" }
            else if r.json["status"].string == "cancelled" { notice = prefs.t("orderCancelled") }
        }
    }

    // MARK: positions / orders

    private func lists(_ toTop: @escaping () -> Void) -> some View {
        let acct = session.account
        let perpOrders = (acct?.orders ?? []).filter { !$0.spot }
        let maxLev = feed.snap?.maxLev ?? 200
        return VStack(alignment: .leading, spacing: 0) {
            ScrollView(.horizontal, showsIndicators: false) {
                Tabs(items: [("pos", withCount(prefs.t("positions"), acct?.positions.count ?? 0)),
                             ("orders", withCount(prefs.t("orders"), perpOrders.count))],
                     value: $tab, size: 12, gap: 16, padBottom: 6)
            }
            .overlay(alignment: .bottom) { Hairline() }
            if tab == "pos" {
                if let positions = acct?.positions, !positions.isEmpty {
                    ForEach(positions) { ps in
                        PosCard(ps: ps, acct: acct, maxLev: ps.sym == sym ? maxLev : 200,
                                onOpen: { if ps.sym != sym { router.go(.trade(ps.sym)) } else { withAnimation { toTop() } } },
                                notice: { notice = $0 })
                    }
                } else {
                    EmptyNote(text: "—", pad: 20)
                }
            } else if perpOrders.isEmpty {
                EmptyNote(text: "—", pad: 20)
            } else {
                ForEach(Array(perpOrders.enumerated()), id: \.element.id) { i, o in
                    MItem(title: o.sym.replacingOccurrences(of: "@.*", with: "", options: .regularExpression),
                          tag: (o.side == "buy" ? prefs.t("long") : prefs.t("short"), o.side == "buy"),
                          action: (prefs.t("cancel"), { Task { await session.cancel(o.id) } }),
                          onTitle: { router.go(.trade(o.sym)) },
                          fields: [(prefs.t("orderPrice"), prefs.num(o.price, o.priceDec), nil),
                                   (prefs.t("quantity"), prefs.num(o.qty, max(0, o.qtyDec)), nil)])
                    if i < perpOrders.count - 1 { Hairline() }
                }
            }
            if session.me != nil { UsdtCard(acct: acct) }
        }
        .padding(.horizontal, 10).padding(.top, 8).padding(.bottom, 2)
        .background(RoundedRectangle(cornerRadius: 8).fill(pal.surface))
    }
}
