import SwiftUI

/// pages/Predict.tsx.
struct PredictPage: View {
    @Environment(Prefs.self) private var prefs
    @Environment(Session.self) private var session
    @Environment(Router.self) private var router
    @Environment(\.pal) private var pal
    @State var tab = "all"
    @State var markets: [JSON]?
    @State var orders: [JSON]?
    @State var marketError = false
    @State var historyError = false
    @State var query = ""
    @State var favOnly = false
    @State var favs: [String] = (UserDefaults.standard.string(forKey: "sky.predictFav")
        .flatMap { try? JSONSerialization.jsonObject(with: Data($0.utf8)) as? [String] }) ?? []
    @State var selected: (market: JSON, outcome: Int)?
    @State var now = Date()

    static let scale = 1_000_000.0
    static let usdt = 100_000_000.0

    func label(_ l: String, price: Bool) -> String { price ? prefs.t(l == "up" ? "pr_up" : "pr_down") : l }

    var body: some View {
        ZStack {
            pal.bg.ignoresSafeArea()
            VStack(spacing: 0) {
                CoverHeader(title: prefs.t("pr_title")) { EmptyView() } right: {
                    IconButton(.x, size: 22) { router.closeCover() }
                }
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 20) {
                        ForEach(["all", "price", "event", "history"], id: \.self) { id in
                            Button { tab = id } label: {
                                Text(prefs.t(["all": "pr_all", "price": "pr_updown", "event": "pr_events", "history": "pr_history"][id]!))
                                    .font(.inter(17, .semibold)).foregroundColor(tab == id ? pal.ink : pal.muted).frame(height: 40)
                            }
                            .buttonStyle(PlainTap())
                        }
                    }
                    .padding(.horizontal, 16)
                }
                ScrollView {
                    if tab == "history" { history } else { marketList }
                }
            }
        }
        .onReceive(Timer.publish(every: 1, on: .main, in: .common).autoconnect()) { now = $0 }
        .task {
            while !Task.isCancelled {
                do { markets = try await API.shared.get("/predictions").array; marketError = false } catch { marketError = true }
                try? await Task.sleep(nanoseconds: 3_000_000_000)
            }
        }
        .task(id: tab) {
            guard tab == "history", session.me != nil else { return }
            while !Task.isCancelled {
                do { orders = try await API.shared.get("/predictions/me").array; historyError = false } catch { historyError = true }
                try? await Task.sleep(nanoseconds: 5_000_000_000)
            }
        }
        .sheet(isPresented: Binding(get: { selected != nil }, set: { if !$0 { selected = nil } })) {
            if let sel = selected {
                BetSheet(market: sel.market, current: markets?.first { $0["id"].string == sel.market["id"].string }, outcome: sel.outcome) {
                    selected = nil; tab = "history"
                }
            }
        }
    }

    private var history: some View {
        VStack(alignment: .leading, spacing: 14) {
            if session.me == nil {
                Button(prefs.t("login")) { router.open(.login) }.btn(.gold)
            } else if historyError {
                Text(prefs.t("pr_failed")).foregroundColor(pal.ink)
            } else if let orders {
                if orders.isEmpty { Text(prefs.t("pr_no_orders")).foregroundColor(pal.ink) }
                ForEach(Array(orders.enumerated()), id: \.offset) { _, o in
                    let status = o["status"].string
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(alignment: .top) {
                            Text("\(o["title"].string) · \(label(o["label"].string, price: o["source"].string == "Binance Spot"))").font(.inter(13, .semibold)).foregroundColor(pal.ink)
                            Spacer()
                            Text(prefs.t("pr_status_\(status)")).foregroundColor(pal.ink)
                        }
                        Text("\(date(o["at"].double)) · \(o["source"].string) · ×\(prefs.num(PredictPage.scale / max(o["probability"].double, 1), 6))")
                            .font(.inter(12.5)).foregroundColor(pal.muted)
                        let paid = status == "refunded" ? o["amount"].double : status == "lost" ? 0 : o["payout"].double
                        Text("\(prefs.t("pr_stake")) \(prefs.num(o["amount"].double / PredictPage.usdt, 8)) USDT · \(prefs.t(status == "pending" ? "pr_payout" : "pr_paid")) \(prefs.num(paid / PredictPage.usdt, 8)) USDT")
                            .foregroundColor(pal.ink)
                        if o["result"].exists { Text(o["result"]["evidence"].string).font(.inter(12.5)).foregroundColor(pal.muted) }
                    }
                    .font(.inter(13))
                    .modifier(PrCard())
                }
            } else {
                Text(prefs.t("connecting")).foregroundColor(pal.ink)
            }
        }
        .font(.inter(13))
        .padding(.horizontal, 16).padding(.vertical, 12)
    }

    private var marketList: some View {
        let q = query.trimmingCharacters(in: .whitespaces).lowercased()
        let shown = (markets ?? []).filter { m in
            (tab == "all" || m["kind"].string == tab)
                && (!favOnly || favs.contains(m["id"].string) || favs.contains("\(m["symbol"].string)|\(m["interval"].string)"))
                && ([m["title"].string, m["symbol"].string] + m["outcomes"].array.map { $0["label"].string }).contains { q.isEmpty || $0.lowercased().contains(q) }
        }
        let nowMs = now.timeIntervalSince1970 * 1000
        return VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 10) {
                Icon(.search, 19).foregroundColor(pal.muted)
                TextField("", text: $query, prompt: Text(prefs.t("pr_search")).foregroundColor(pal.muted)).font(.inter(16)).foregroundColor(pal.ink)
            }
            .padding(.horizontal, 14).frame(height: 46)
            .background(RoundedRectangle(cornerRadius: 12).fill(pal.surface2))
            .padding(.horizontal, 16).padding(.top, 6).padding(.bottom, 14)
            Button { favOnly.toggle() } label: {
                HStack(spacing: 6) {
                    Icon(.star, 16).foregroundColor(pal.gold)
                    Text(prefs.t("pr_favorites")).font(.inter(15, favOnly ? .semibold : .regular)).foregroundColor(favOnly ? pal.ink : pal.ink2)
                }
                .padding(.horizontal, 12).frame(height: 36)
                .background(RoundedRectangle(cornerRadius: 9).fill(favOnly ? pal.surface2 : .clear))
            }
            .buttonStyle(PlainTap())
            .padding(.horizontal, 16).padding(.top, 8).padding(.bottom, 4)
            VStack(alignment: .leading, spacing: 14) {
                if marketError { Text(prefs.t("pr_failed")).font(.inter(13)).foregroundColor(pal.ink) }
                if markets == nil && !marketError { Text(prefs.t("connecting")).font(.inter(13)).foregroundColor(pal.ink) }
                if markets != nil && shown.isEmpty { EmptyNote(text: prefs.t("pr_empty")) }
                ForEach(Array(shown.enumerated()), id: \.offset) { _, m in card(m, nowMs: nowMs) }
            }
            .padding(.horizontal, 16).padding(.vertical, 12)
        }
    }

    private func card(_ m: JSON, nowMs: Double) -> some View {
        let id = m["id"].string
        let price = m["kind"].string == "price"
        let open = !marketError && m["status"].string == "open" && nowMs < m["closes"].double
        let fav = favs.contains(id)
        return VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 12) {
                Text(m["title"].string).font(.inter(17, .semibold)).foregroundColor(pal.ink)
                Spacer()
                Button {
                    if fav { favs.removeAll { $0 == id } } else { favs.append(id) }
                    if let d = try? JSONSerialization.data(withJSONObject: favs) { UserDefaults.standard.set(String(data: d, encoding: .utf8), forKey: "sky.predictFav") }
                } label: { Icon(.star, 17, filled: fav).foregroundColor(fav ? pal.gold : pal.muted).padding(4) }
                .buttonStyle(PlainTap())
            }
            Text("\(price ? "Binance Spot · \(m["symbol"].string) · \(m["interval"].string)" : "Polymarket") · \(date(m["closes"].double))")
                .font(.inter(12.5)).foregroundColor(pal.muted)
            if !m["rules"].string.isEmpty {
                DisclosureGroup(prefs.t("pr_rules")) {
                    Text(m["rules"].string).font(.inter(13)).foregroundColor(pal.ink).frame(maxWidth: .infinity, alignment: .leading)
                }
                .font(.inter(13)).foregroundColor(pal.ink).tint(pal.muted)
            }
            if !m["quote"]["openPrice"].string.isEmpty {
                Text("\(prefs.t("pr_open")) \(m["quote"]["openPrice"].string) · \(prefs.t("price")) \(m["quote"]["price"].string)").font(.inter(12.5)).foregroundColor(pal.muted)
            }
            HStack(spacing: 14) {
                ForEach(Array(m["outcomes"].array.enumerated()), id: \.offset) { i, o in
                    let p = m["quote"]["probabilities"][i].double
                    VStack(spacing: 10) {
                        Text(open && p > 0 ? "\(prefs.num(p / 10000, 2))% · ×\(prefs.num(PredictPage.scale / p, 6))" : "—")
                            .font(.inter(24, .bold)).monospacedDigit().foregroundColor(pal.ink).lineLimit(1).minimumScaleFactor(0.5)
                        Button {
                            if session.me != nil { selected = (market: m, outcome: i) } else { router.open(.login) }
                        } label: {
                            Text(label(o["label"].string, price: price)).font(.inter(18, .semibold))
                                .foregroundColor(i == 0 ? pal.green : pal.red)
                                .frame(maxWidth: .infinity).frame(height: 46)
                                .background(RoundedRectangle(cornerRadius: 10).fill(i == 0 ? pal.greenTint : pal.redTint))
                        }
                        .buttonStyle(PlainTap())
                        .disabled(!open || p <= 0)
                        .opacity(!open || p <= 0 ? 0.5 : 1)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .padding(.top, 10)
            HStack(spacing: 6) {
                Icon(.chartNoAxesColumn, 15)
                Text("\(prefs.t("pr_status_\(m["status"].string)"))\(open ? " · \(prefs.t("pr_left")) \(max(0, Int(ceil((m["closes"].double - nowMs) / 1000))))s" : "")")
                    .monospacedDigit().lineLimit(1)
            }
            .font(.inter(13)).foregroundColor(pal.muted)
            .padding(.top, 8)
            if m["result"].exists {
                let w = m["result"]["winner"].int
                Text("\(w < 0 ? prefs.t("pr_status_refunded") : label(m["outcomes"][w]["label"].string, price: price)) · \(m["result"]["evidence"].string)")
                    .font(.inter(12.5)).foregroundColor(pal.ink)
            }
        }
        .modifier(PrCard())
    }

    private func date(_ ms: Double) -> String {
        let f = DateFormatter(); f.dateStyle = .short; f.timeStyle = .medium; f.locale = Locale(identifier: prefs.lang)
        return f.string(from: Date(timeIntervalSince1970: ms / 1000))
    }
}

struct PrCard: ViewModifier {
    @Environment(\.pal) private var pal
    func body(content: Content) -> some View {
        content
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 16).fill(pal.surface))
            .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(pal.line, lineWidth: 1))
            .shadow(color: pal.dark ? .black.opacity(0.28) : Color(r: 70, g: 60, b: 30, a: 0.08), radius: 9, x: 0, y: 6)
    }
}

/// Stake sheet (Predict.tsx BetSheet).
struct BetSheet: View {
    @Environment(Prefs.self) private var prefs
    @Environment(\.pal) private var pal
    let market: JSON
    let current: JSON?
    let outcome: Int
    let onPlaced: () -> Void
    @State var quote: JSON?
    @State var amount = ""
    @State var available: Double?
    @State var requestId = UUID().uuidString.lowercased()
    @State var busy = false
    @State var error = ""
    @State var now = Date()

    var body: some View {
        let q = quote ?? market["quote"]
        let probability = q["probabilities"][outcome].double
        let odds = probability > 0 ? PredictPage.scale / probability : 0
        let decimal = amount.trimmingCharacters(in: .whitespaces).replacingOccurrences(of: ",", with: ".")
        let value = Double(decimal) ?? 0
        let valid = decimal.range(of: "^\\d+(?:\\.\\d{1,8})?$", options: .regularExpression) != nil && value > 0
        let nowMs = now.timeIntervalSince1970 * 1000
        let cur = current?["quote"]
        let changed = !q.exists || nowMs - q["at"].double >= 15000 || q["round"].string != cur?["round"].string
            || probability != cur?["probabilities"][outcome].double || nowMs >= (current?["closes"].double ?? 0)
        let price = market["kind"].string == "price"
        let outLabel = price ? prefs.t(market["outcomes"][outcome]["label"].string == "up" ? "pr_up" : "pr_down") : market["outcomes"][outcome]["label"].string
        SkySheet(title: "\(market["title"].string) · \(outLabel)") {
            Text(price ? "Binance Spot" : "Polymarket").font(.inter(12.5)).foregroundColor(pal.muted)
            PcFacts(rows: [(prefs.t("pr_odds"), "×\(prefs.num(odds, 6))", nil),
                           (prefs.t("available"), "\(available.map { prefs.num($0, 8) } ?? "—") USDT", nil)])
            PcField(label: prefs.t("pr_stake"), text: Binding(get: { amount }, set: { amount = $0; requestId = UUID().uuidString.lowercased() }), placeholder: "")
            PcFacts(rows: [(prefs.t("pr_payout"), "\(valid ? prefs.num(value * odds, 8) : "—") USDT", nil)])
            Text(prefs.t("pr_no_fee")).font(.inter(12.5)).foregroundColor(pal.muted)
            if !error.isEmpty { Text(prefs.t(error)).foregroundColor(pal.ink) }
            if changed {
                Button(prefs.t("pr_requote")) { quote = current?["quote"]; requestId = UUID().uuidString.lowercased(); error = "" }
                    .btn(.plain, wide: true)
                    .disabled(busy || cur?.exists != true || cur?["round"].string != market["quote"]["round"].string || nowMs >= (current?["closes"].double ?? 0))
            }
            PcPrimary(title: prefs.t("pc_confirm")) { Task { await submit(q, probability: probability, decimal: decimal) } }
                .disabled(busy || changed || !valid || odds == 0)
        }
        .onReceive(Timer.publish(every: 1, on: .main, in: .common).autoconnect()) { now = $0 }
        .task {
            if quote == nil { quote = market["quote"] }
            if let a = try? await API.shared.get("/account") { available = a["available"].double }
        }
    }

    private func submit(_ q: JSON, probability: Double, decimal: String) async {
        guard q.exists, !busy else { return }
        busy = true; error = ""
        defer { busy = false }
        do {
            _ = try await API.shared.post("/predictions/orders", ["id": requestId, "market": market["id"].string, "round": q["round"].string,
                                                                  "outcome": outcome, "quoteAt": q["at"].double, "probability": probability, "amount": decimal])
            Haptic.success()
            onPlaced()
        } catch {
            let code = (error as? APIError)?.code ?? ""
            self.error = code == "prediction_insufficient_funds" ? "pr_insufficient" : code == "prediction_quote_changed" ? "pr_requote" : "pr_failed"
        }
    }
}
