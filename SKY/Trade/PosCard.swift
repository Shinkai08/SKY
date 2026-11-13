import SwiftUI

/// Margin ratio as exchanges show it (PosCard.tsx marginRatio).
func marginRatio(_ ps: Position, _ acct: Account?) -> Double {
    if ps.isolated { return ps.maint > 0 ? (ps.margin + ps.upnl) / ps.maint : 0 }
    let positions = acct?.positions ?? []
    let iso = positions.filter { $0.isolated }.reduce(0) { $0 + $1.margin + $1.upnl }
    let maint = positions.filter { !$0.isolated }.reduce(0) { $0 + $1.maint }
    return maint > 0 ? ((acct?.equity ?? 0) - iso) / maint : 0
}

/// Platinum card frame (.pc).
struct PlatCard: ViewModifier {
    @Environment(\.pal) private var pal
    func body(content: Content) -> some View {
        content
            .padding(.horizontal, 14).padding(.top, 14).padding(.bottom, 16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 16).fill(
                    pal.dark
                        ? LinearGradient(stops: [.init(color: Color(hex: 0x1d2025), location: 0), .init(color: Color(hex: 0x15171b), location: 0.42), .init(color: Color(hex: 0x14161a), location: 1)], startPoint: .top, endPoint: .bottom)
                        : LinearGradient(stops: [.init(color: .white, location: 0), .init(color: Color(hex: 0xfbfaf7), location: 0.55), .init(color: Color(hex: 0xf4f1ea), location: 1)], startPoint: .top, endPoint: .bottom)
                )
            )
            .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(pal.platLine, lineWidth: 1))
            .shadow(color: pal.dark ? .black.opacity(0.28) : Color(r: 70, g: 60, b: 30, a: 0.08), radius: 9, x: 0, y: 6)
            .padding(.vertical, 8)
    }
}

extension View { func platCard() -> some View { modifier(PlatCard()) } }

/// Open-position card (PosCard.tsx).
struct PosCard: View {
    @Environment(Prefs.self) private var prefs
    @Environment(Session.self) private var session
    @Environment(\.pal) private var pal
    let ps: Position
    let acct: Account?
    var maxLev: Double = 200
    let onOpen: () -> Void
    let notice: (String) -> Void

    @State var closing = false
    @State var pctSel = 100
    @State var busy = false
    @State var sheet: String?
    @State var poster = false

    var body: some View {
        let long = ps.long
        let qd = max(0, ps.qtyDec)
        let step = pow(10, -Double(ps.qtyDec))
        let roe = ps.margin > 0 ? ps.upnl / ps.margin * 100 : 0
        let ratio = marginRatio(ps, acct)
        let notional = abs(ps.qty) * ps.mark
        let closeQty = min(abs(ps.qty), floor((abs(ps.qty) * Double(pctSel) / 100) / step + 1e-9) * step)
        let tooled = ps.realized != nil
        let hasTrig = ps.tp > 0 || ps.sl > 0
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 10) {
                VStack(alignment: .leading, spacing: 8) {
                    Button(action: onOpen) {
                        HStack(spacing: 2) {
                            Text("\(ps.base)USDT \(prefs.t("pc_perp"))").font(.inter(16, .bold)).foregroundColor(pal.ink).lineLimit(1)
                            Icon(.chevronRight, 18).foregroundColor(pal.muted)
                        }
                    }
                    .buttonStyle(PlainTap())
                    HStack(spacing: 5) {
                        tag(long ? prefs.t("pc_long") : prefs.t("pc_short"), kind: long ? 1 : -1)
                        tag(prefs.t(ps.isolated ? "isolated" : "cross"))
                        if tooled && ps.maxLev != nil {
                            Button { sheet = "lev" } label: {
                                HStack(spacing: 4) { Text("\(Int(ps.lev))x"); Icon(.pencil, 12).opacity(0.7) }
                                    .modifier(TagStyle(kind: 0))
                            }
                            .buttonStyle(PlainTap())
                        } else {
                            tag("\(Int(ps.lev))x")
                        }
                        RiskBars(ratio: ratio).padding(.leading, 2)
                    }
                }
                Spacer(minLength: 0)
                VStack(alignment: .trailing, spacing: 6) {
                    HStack(spacing: 6) {
                        Text(prefs.t("pc_pnl")).font(.inter(12.5)).foregroundColor(pal.muted).lineLimit(1)
                        if session.me != nil {
                            Button { poster = true } label: { Icon(.share, 17).foregroundColor(pal.ink2) }
                                .buttonStyle(PlainTap())
                        }
                    }
                    Text("\(sign(ps.upnl)) (\(sign(roe))%)").font(.inter(15, .bold)).monospacedDigit()
                        .foregroundColor(pal.dir(ps.upnl)).lineLimit(1).fixedSize()
                }
            }

            Grid(alignment: .leading, horizontalSpacing: 8, verticalSpacing: 14) {
                GridRow {
                    cell(prefs.t("pc_size"), prefs.num(notional))
                    VStack(alignment: .leading, spacing: 4) {
                        Text(prefs.t("pc_margin")).font(.inter(12)).foregroundColor(pal.muted).lineLimit(1)
                        HStack(spacing: 6) {
                            Text(prefs.num(ps.margin)).font(.inter(15, .semibold)).monospacedDigit().foregroundColor(pal.ink).lineLimit(1)
                            if tooled && ps.isolated {
                                Button { sheet = "margin" } label: { Icon(.circlePlus, 17).foregroundColor(pal.gold) }
                                    .buttonStyle(PlainTap())
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    cell(prefs.t("pc_mmr"), ratio > 0 ? "\(prefs.num(ratio * 100, 2))%" : "—", right: true)
                }
                GridRow {
                    cell(prefs.t("pc_entry"), prefs.num(ps.entry, ps.priceDec))
                    cell(prefs.t("pc_mark"), prefs.num(ps.mark, ps.priceDec))
                    cell(prefs.t("pc_liq"), ps.liq > 0 ? prefs.num(ps.liq, ps.priceDec) : "—", color: pal.gold, right: true)
                }
            }
            .contentShape(Rectangle())
            .onTapGesture(perform: onOpen)

            if tooled || hasTrig {
                VStack(alignment: .leading, spacing: 0) {
                    Hairline().padding(.bottom, 12)
                    HStack(spacing: 18) {
                        if tooled {
                            HStack(alignment: .firstTextBaseline, spacing: 8) {
                                Text(prefs.t("pc_realized")).font(.inter(12)).foregroundColor(pal.muted)
                                Text(sign(ps.realized ?? 0)).font(.inter(13.5, .semibold)).monospacedDigit().foregroundColor(pal.dir(ps.realized ?? 0))
                            }
                        }
                        if hasTrig {
                            HStack(alignment: .firstTextBaseline, spacing: 8) {
                                Text("\(prefs.t("pc_tp")) / \(prefs.t("pc_sl"))").font(.inter(12)).foregroundColor(pal.muted)
                                (Text(ps.tp > 0 ? prefs.num(ps.tp, ps.priceDec) : "—").foregroundColor(pal.green)
                                 + Text(" / ").foregroundColor(pal.ink)
                                 + Text(ps.sl > 0 ? prefs.num(ps.sl, ps.priceDec) : "—").foregroundColor(pal.red))
                                    .font(.inter(13.5, .semibold)).monospacedDigit()
                            }
                        }
                    }
                }
            }

            if closing {
                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 6) {
                        ForEach([25, 50, 75, 100], id: \.self) { v in
                            Button { pctSel = v } label: {
                                Text("\(v)%").font(.inter(12.5)).foregroundColor(pctSel == v ? pal.gold : pal.muted)
                                    .frame(maxWidth: .infinity).frame(height: 30)
                                    .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(pctSel == v ? pal.gold : pal.line, lineWidth: 1))
                            }
                            .buttonStyle(PlainTap())
                        }
                    }
                    HStack {
                        Text(prefs.t("quantity")).foregroundColor(pal.muted)
                        Spacer()
                        Text("\(prefs.num(closeQty, qd)) \(ps.base)").monospacedDigit().foregroundColor(pal.ink)
                    }
                    .font(.inter(12.5))
                    HStack(spacing: 10) {
                        pill(prefs.t("pc_back"), bg: pal.surface) { closing = false }
                        pill(prefs.t("pc_closeMarket"), solid: long ? pal.red : pal.green) { Task { await run(closeQty) } }
                            .disabled(busy || closeQty <= 0)
                    }
                }
                .padding(12)
                .background(RoundedRectangle(cornerRadius: 12).fill(pal.surface2))
            }

            HStack(spacing: 8) {
                pill(prefs.t("pc_add"), action: onOpen)
                pill(prefs.t("pc_tpsl"), on: hasTrig) {
                    if tooled { sheet = "tpsl" } else { notice(prefs.t("pc_tpslSoon")) }
                }
                pill(prefs.t("pc_close"), on: closing) { pctSel = 100; closing.toggle() }
                pill(prefs.t("pc_closeAll")) { Task { await run(abs(ps.qty)) } }.disabled(busy)
            }
        }
        .font(.inter(13))
        .platCard()
        .sheet(isPresented: Binding(get: { sheet == "margin" }, set: { if !$0 { sheet = nil } })) {
            MarginSheet(ps: ps, acct: acct, notice: notice)
        }
        .sheet(isPresented: Binding(get: { sheet == "tpsl" }, set: { if !$0 { sheet = nil } })) {
            TpslSheet(ps: ps, notice: notice)
        }
        .sheet(isPresented: Binding(get: { sheet == "lev" }, set: { if !$0 { sheet = nil } })) {
            LeverageSheet(ps: ps, acct: acct, cap: ps.maxLev ?? maxLev, notice: notice)
        }
        .sheet(isPresented: $poster) {
            PosterSheet(position: PosterPosition(perp: ps, t: { prefs.t($0) }))
        }
    }

    private func sign(_ v: Double) -> String {
        let d = v != 0 && abs(v) < 0.01 ? 4 : 2
        return (v >= 0 ? "+" : "−") + prefs.num(abs(v), d)
    }

    private func run(_ qty: Double) async {
        guard !busy, qty > 0 else { return }
        busy = true
        let r = await session.place(["symbol": ps.sym, "side": ps.long ? "sell" : "buy", "type": "market", "qty": qty, "reduceOnly": true])
        busy = false
        if r.ok { closing = false; notice(prefs.t("pc_closed")); Haptic.success() } else {
            notice("\(prefs.t("rejected")): \(r.reason.isEmpty ? "" : prefs.t("err_\(r.reason)"))"); Haptic.error()
        }
    }

    private func tag(_ text: String, kind: Int = 0) -> some View {
        Text(text).modifier(TagStyle(kind: kind))
    }

    private func cell(_ k: String, _ v: String, color: Color? = nil, right: Bool = false) -> some View {
        VStack(alignment: right ? .trailing : .leading, spacing: 4) {
            Text(k).font(.inter(12)).foregroundColor(pal.muted).lineLimit(1)
            Text(v).font(.inter(15, .semibold)).monospacedDigit().foregroundColor(color ?? pal.ink).lineLimit(1).minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity, alignment: right ? .trailing : .leading)
    }

    private func pill(_ text: String, on: Bool = false, bg: Color? = nil, solid: Color? = nil, action: @escaping () -> Void) -> some View {
        Button(action: { Haptic.tap(); action() }) {
            Text(text).font(.inter(13.5, .semibold)).lineLimit(1).minimumScaleFactor(0.8)
                .foregroundColor(solid != nil ? .white : on ? pal.gold : pal.ink)
                .padding(.horizontal, 6)
                .frame(maxWidth: .infinity).frame(height: 38)
                .background(Capsule().fill(solid ?? bg ?? pal.surface2))
                .overlay(Capsule().strokeBorder(solid != nil ? .clear : on ? pal.gold : pal.line, lineWidth: 1))
        }
        .buttonStyle(PlainTap())
    }
}

struct TagStyle: ViewModifier {
    @Environment(\.pal) private var pal
    let kind: Int
    func body(content: Content) -> some View {
        content
            .font(.inter(12, .medium)).lineLimit(1)
            .foregroundColor(kind > 0 ? pal.green : kind < 0 ? pal.red : pal.ink2)
            .padding(.horizontal, 7).frame(height: 24)
            .background(RoundedRectangle(cornerRadius: 7).fill(kind > 0 ? pal.greenTint : kind < 0 ? pal.redTint : pal.surface2))
            .overlay(RoundedRectangle(cornerRadius: 7).strokeBorder(kind == 0 ? pal.line : .clear, lineWidth: 1))
    }
}

struct RiskBars: View {
    @Environment(\.pal) private var pal
    let ratio: Double
    var body: some View {
        let risk = ratio > 0 ? 1 / ratio : 0
        let n = max(1, min(5, Int(ceil(risk * 5))))
        let color = risk >= 0.7 ? pal.red : risk >= 0.4 ? pal.gold : pal.green
        HStack(spacing: 2) {
            ForEach(0..<5, id: \.self) { i in
                RoundedRectangle(cornerRadius: 1).fill(i < n ? color : pal.line).frame(width: 3, height: 13)
            }
        }
    }
}

// MARK: - sheets

/// .pc-field
struct PcField: View {
    @Environment(\.pal) private var pal
    let label: String
    @Binding var text: String
    var placeholder = "0.00"
    var unit = "USDT"
    var maxLabel: String?
    var onMax: (() -> Void)?
    var note: (String, Color)?
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label).font(.inter(12.5)).foregroundColor(pal.muted)
            HStack(spacing: 8) {
                TextField("", text: $text, prompt: Text(placeholder).font(.inter(18)).foregroundColor(pal.muted))
                    .font(.inter(18, .semibold)).monospacedDigit().keyboardType(.decimalPad).foregroundColor(pal.ink)
                    .frame(height: 30)
                Text(unit).foregroundColor(pal.muted)
                if let maxLabel, let onMax {
                    Button(maxLabel, action: onMax).font(.inter(14, .semibold)).foregroundColor(pal.gold).buttonStyle(PlainTap())
                }
            }
            if let note { Text(note.0).font(.inter(12.5)).monospacedDigit().foregroundColor(note.1) }
        }
        .padding(.horizontal, 12).padding(.vertical, 10)
        .background(RoundedRectangle(cornerRadius: 12).fill(pal.surface2))
        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(pal.line, lineWidth: 1))
    }
}

/// .pc-facts
struct PcFacts: View {
    @Environment(\.pal) private var pal
    let rows: [(String, String, Color?)]
    var body: some View {
        VStack(spacing: 8) {
            ForEach(rows.indices, id: \.self) { i in
                HStack {
                    Text(rows[i].0).foregroundColor(pal.muted)
                    Spacer()
                    Text(rows[i].1).font(.inter(14, .semibold)).monospacedDigit().foregroundColor(rows[i].2 ?? pal.ink)
                }
            }
        }
        .font(.inter(14))
    }
}

/// .pc-primary
struct PcPrimary: View {
    @Environment(\.pal) private var pal
    @Environment(\.isEnabled) private var enabled
    let title: String
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            Text(title).font(.inter(15.5, .bold)).foregroundColor(pal.onGold)
                .frame(maxWidth: .infinity).frame(height: 46)
                .background(RoundedRectangle(cornerRadius: 12).fill(pal.goldGrad))
                .opacity(enabled ? 1 : 0.45)
        }
        .buttonStyle(PlainTap())
    }
}

func toNum(_ s: String) -> Double {
    let v = Double(s.replacingOccurrences(of: ",", with: ".")) ?? 0
    return v.isFinite && v > 0 ? v : 0
}

struct MarginSheet: View {
    @Environment(Prefs.self) private var prefs
    @Environment(Session.self) private var session
    @Environment(\.pal) private var pal
    @Environment(\.dismiss) private var dismiss
    let ps: Position
    let acct: Account?
    let notice: (String) -> Void
    @State var add = true
    @State var amt = ""
    @State var err = ""
    @State var busy = false

    var body: some View {
        let max = Swift.max(0, floor((add ? acct?.available ?? 0 : ps.removable) * 100) / 100)
        let v = toNum(amt)
        SkySheet(title: "\(prefs.t("pc_marginTitle")) · \(ps.base)USDT") {
            PcSeg(items: [prefs.t("pc_marginAdd"), prefs.t("pc_marginRemove")], index: Binding(get: { add ? 0 : 1 }, set: { add = $0 == 0; amt = ""; err = "" }))
            PcField(label: prefs.t("pc_amount"), text: $amt, maxLabel: prefs.t("pc_max")) { amt = String(format: "%.2f", max) }
            PcFacts(rows: [
                (prefs.t("pc_curMargin"), "\(prefs.num(ps.margin)) USDT", nil),
                (prefs.t(add ? "pc_canAdd" : "pc_canRemove"), "\(prefs.num(max)) USDT", nil),
                (prefs.t("pc_liq"), ps.liq > 0 ? prefs.num(ps.liq, ps.priceDec) : "—", pal.gold),
            ])
            if !err.isEmpty { Text(err).font(.inter(13)).foregroundColor(pal.red) }
            PcPrimary(title: prefs.t("pc_confirm")) {
                Task {
                    busy = true; err = ""
                    let r = await session.tool("/position/margin", ["symbol": ps.sym, "amount": add ? v : -v])
                    busy = false
                    if r.ok { notice(prefs.t("pc_marginSaved")); dismiss() } else { err = prefs.t("err_\(r.reason.isEmpty ? "service_unavailable" : r.reason)") }
                }
            }
            .disabled(busy || v <= 0 || v > max + 1e-9)
        }
    }
}

struct TpslSheet: View {
    @Environment(Prefs.self) private var prefs
    @Environment(Session.self) private var session
    @Environment(\.pal) private var pal
    @Environment(\.dismiss) private var dismiss
    let ps: Position
    let notice: (String) -> Void
    @State var tp = ""
    @State var sl = ""
    @State var err = ""
    @State var busy = false
    @State var loaded = false

    var body: some View {
        SkySheet(title: "\(prefs.t("pc_tpsl")) · \(ps.base)USDT") {
            PcFacts(rows: [(prefs.t("pc_entry"), prefs.num(ps.entry, ps.priceDec), nil), (prefs.t("pc_mark"), prefs.num(ps.mark, ps.priceDec), nil)])
            PcField(label: prefs.t("pc_tpPrice"), text: $tp, placeholder: prefs.num(ps.mark, ps.priceDec), note: est(tp))
            PcField(label: prefs.t("pc_slPrice"), text: $sl, placeholder: prefs.num(ps.mark, ps.priceDec), note: est(sl))
            Text(prefs.t("pc_tpslHint")).font(.inter(12.5)).foregroundColor(pal.muted)
            if !err.isEmpty { Text(err).font(.inter(13)).foregroundColor(pal.red) }
            HStack(spacing: 10) {
                if ps.tp > 0 || ps.sl > 0 {
                    Button { save(0, 0) } label: {
                        Text(prefs.t("pc_clear")).font(.inter(13.5, .semibold)).foregroundColor(pal.ink)
                            .frame(maxWidth: .infinity).frame(height: 46)
                            .background(RoundedRectangle(cornerRadius: 12).fill(pal.surface2))
                            .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(pal.line, lineWidth: 1))
                    }
                    .buttonStyle(PlainTap()).disabled(busy)
                }
                PcPrimary(title: prefs.t("pc_confirm")) { save(toNum(tp), toNum(sl)) }.disabled(busy)
                    .frame(maxWidth: .infinity).layoutPriority(1)
            }
        }
        .onAppear {
            guard !loaded else { return }
            loaded = true
            if ps.tp > 0 { tp = "\(ps.tp)" }
            if ps.sl > 0 { sl = "\(ps.sl)" }
        }
    }

    private func est(_ s: String) -> (String, Color)? {
        let p = toNum(s)
        guard p > 0 else { return nil }
        let v = (p - ps.entry) * ps.qty
        return ("\(prefs.t("pc_estPnl")) \(v >= 0 ? "+" : "−")\(prefs.num(abs(v)))", pal.dir(v))
    }

    private func save(_ a: Double, _ b: Double) {
        Task {
            busy = true; err = ""
            let r = await session.tool("/position/tpsl", ["symbol": ps.sym, "tp": a, "sl": b])
            busy = false
            if r.ok { notice(prefs.t("pc_tpslSaved")); dismiss() } else { err = prefs.t("err_\(r.reason.isEmpty ? "service_unavailable" : r.reason)") }
        }
    }
}

struct LeverageSheet: View {
    @Environment(Prefs.self) private var prefs
    @Environment(Session.self) private var session
    @Environment(\.pal) private var pal
    @Environment(\.dismiss) private var dismiss
    let ps: Position
    let acct: Account?
    let cap: Double
    let notice: (String) -> Void
    @State var lev: Double = 0
    @State var err = ""
    @State var busy = false

    var body: some View {
        let l = lev > 0 ? lev : ps.lev
        let notional = abs(ps.qty) * ps.mark
        let cost = abs(ps.qty) * ps.entry
        var next = ps.isolated ? cost / l : notional / l
        if ps.isolated && next < ps.margin {
            let spare = max(0, min(ps.margin, ps.margin + ps.upnl - notional / l))
            next = ps.margin - min(ps.margin - next, spare)
        }
        let delta = next - ps.margin
        let avail = acct?.available ?? 0
        let short = delta > 0 && delta > avail + 1e-9
        return SkySheet(title: "\(prefs.t("pc_levTitle")) · \(ps.base)USDT") {
            Text("\(Int(l))x").font(.inter(30, .bold)).foregroundColor(pal.gold).frame(maxWidth: .infinity)
            LeverageRow(lev: Binding(get: { l }, set: { lev = $0 }), cap: cap)
            if l > 100 { Text(prefs.t("highLevWarn")).font(.inter(11.5)).foregroundColor(pal.red) }
            PcFacts(rows: [
                (prefs.t("pc_curMargin"), "\(prefs.num(ps.margin)) USDT", nil),
                (prefs.t("pc_newMargin"), "\(prefs.num(next)) USDT", nil),
                (prefs.t(delta >= 0 ? "pc_levAdd" : "pc_levFree"), "\(prefs.num(abs(delta))) USDT", delta > 0 ? pal.red : delta < 0 ? pal.green : nil),
                (prefs.t("available"), "\(prefs.num(avail)) USDT", nil),
            ])
            Text(prefs.t(ps.isolated ? "pc_levHintIso" : "pc_levHintCross")).font(.inter(12.5)).foregroundColor(pal.muted)
            if short { Text(prefs.t("err_insufficient_margin")).font(.inter(13)).foregroundColor(pal.red) }
            if !err.isEmpty { Text(err).font(.inter(13)).foregroundColor(pal.red) }
            PcPrimary(title: prefs.t("pc_confirm")) {
                Task {
                    busy = true; err = ""
                    let r = await session.tool("/position/leverage", ["symbol": ps.sym, "leverage": Int(l)])
                    busy = false
                    if r.ok { notice(prefs.t("pc_levSaved")); dismiss() } else { err = prefs.t("err_\(r.reason.isEmpty ? "service_unavailable" : r.reason)") }
                }
            }
            .disabled(busy || Int(l) == Int(ps.lev) || short)
        }
    }
}

/// Range slider + number box + 1x…200x marks (.lev-row / .lev-marks).
struct LeverageRow: View {
    @Environment(\.pal) private var pal
    @Binding var lev: Double
    let cap: Double
    var disabled = false
    var compact = false
    var body: some View {
        VStack(spacing: compact ? 6 : 10) {
            HStack(spacing: compact ? 6 : 8) {
                Slider(value: Binding(get: { lev }, set: { lev = $0.rounded() }), in: 1...max(1.0001, cap), step: 1)
                    .tint(pal.gold)
                    .disabled(disabled)
                    .controlSize(compact ? .mini : .regular)
                HStack(spacing: 2) {
                    TextField("", text: Binding(get: { "\(Int(lev))" }, set: { s in
                        let v = Double(Int(s.filter(\.isNumber)) ?? 0)
                        if v >= 1 { lev = min(cap, v) }
                    }))
                    .font(.inter(12)).monospacedDigit().multilineTextAlignment(.trailing).keyboardType(.numberPad)
                    .frame(width: 42)
                    .disabled(disabled)
                    Text("x").font(.inter(12))
                }
                .foregroundColor(pal.ink)
                .padding(.horizontal, 8).frame(height: compact ? 26 : 30)
                .background(RoundedRectangle(cornerRadius: 6).fill(pal.surface2))
            }
            if !disabled {
                HStack {
                    ForEach([1.0, 20, 50, 100, 150, 200].filter { $0 <= cap }, id: \.self) { m in
                        Button { lev = m; Haptic.tap() } label: {
                            Text("\(Int(m))x").font(.inter(10.5)).foregroundColor(Int(lev) == Int(m) ? pal.gold : pal.muted)
                        }
                        .buttonStyle(PlainTap())
                        if m != [1.0, 20, 50, 100, 150, 200].filter({ $0 <= cap }).last { Spacer(minLength: 0) }
                    }
                }
            }
        }
    }
}

/// .pc-seg two-way switch.
struct PcSeg: View {
    @Environment(\.pal) private var pal
    let items: [String]
    @Binding var index: Int
    var body: some View {
        HStack(spacing: 0) {
            ForEach(items.indices, id: \.self) { i in
                Button { index = i; Haptic.tap() } label: {
                    Text(items[i]).font(.inter(14, .semibold)).foregroundColor(index == i ? pal.gold : pal.muted)
                        .frame(maxWidth: .infinity).frame(height: 36)
                        .background(RoundedRectangle(cornerRadius: 9).fill(index == i ? pal.surface : .clear)
                            .shadow(color: .black.opacity(index == i ? 0.18 : 0), radius: 1.5, x: 0, y: 1))
                }
                .buttonStyle(PlainTap())
            }
        }
        .padding(3)
        .background(RoundedRectangle(cornerRadius: 12).fill(pal.surface2))
    }
}

/// USDT futures balance card (UsdtCard).
struct UsdtCard: View {
    @Environment(Prefs.self) private var prefs
    @Environment(\.pal) private var pal
    let acct: Account?
    var body: some View {
        let rate = acct?.usdtUsd ?? 0
        let upnl = acct?.upnl ?? 0
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 10) {
                TetherLogo(size: 34)
                Text("USDT").font(.inter(17, .semibold)).foregroundColor(pal.ink)
            }
            Grid(alignment: .leading, horizontalSpacing: 8, verticalSpacing: 14) {
                GridRow {
                    cell(prefs.t("acc_equity"), acct?.equity ?? 0, rate)
                    cell(prefs.t("acc_used"), acct?.margin ?? 0, rate)
                    cell(prefs.t("acc_avail"), acct?.available ?? 0, rate, right: true)
                }
                GridRow {
                    cell(prefs.t("acc_upnl"), upnl, rate, color: pal.dir(upnl))
                    cell(prefs.t("acc_balance"), acct?.wallet ?? 0, rate)
                    Color.clear.frame(height: 1)
                }
            }
        }
        .font(.inter(13))
        .platCard()
    }

    private func cell(_ k: String, _ v: Double, _ rate: Double, color: Color? = nil, right: Bool = false) -> some View {
        VStack(alignment: right ? .trailing : .leading, spacing: 4) {
            Text(k).font(.inter(12)).foregroundColor(pal.muted).lineLimit(1)
            Text(prefs.num(v)).font(.inter(15, .semibold)).monospacedDigit().foregroundColor(color ?? pal.ink).lineLimit(1).minimumScaleFactor(0.7)
            if rate > 0 {
                let d = abs(v) * rate
                Text(d > 0 && d < 0.01 ? "<$0.01" : "\(v < 0 ? "−" : "")$\(prefs.num(d))").font(.inter(12)).monospacedDigit().foregroundColor(pal.muted)
            }
        }
        .frame(maxWidth: .infinity, alignment: right ? .trailing : .leading)
    }
}

/// The Tether mark used on the USDT card.
struct TetherLogo: View {
    var size: CGFloat = 34
    var body: some View {
        Canvas { ctx, s in
            let k = s.width / 32
            ctx.fill(Path(ellipseIn: CGRect(origin: .zero, size: s)), with: .color(Color(hex: 0x26a17b)))
            var p = Path()
            // Simplified Tether glyph (T with the ring), drawn in the 32-unit grid.
            p.addRect(CGRect(x: 9.3 * k, y: 8.6 * k, width: 13.4 * k, height: 3.2 * k))
            p.addRect(CGRect(x: 14.1 * k, y: 11.6 * k, width: 3.8 * k, height: 12.9 * k))
            ctx.fill(p, with: .color(.white))
            ctx.stroke(Path(ellipseIn: CGRect(x: 7.6 * k, y: 13.6 * k, width: 16.8 * k, height: 4.3 * k)), with: .color(.white), lineWidth: 1.6 * k)
        }
        .frame(width: size, height: size)
    }
}
