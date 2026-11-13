import SwiftUI

// MARK: - live market (market/sky.ts useMarket: 1 s snapshot polling)

@MainActor
@Observable
final class MarketFeed {
    var snap: Snapshot?
    var state = "loading"
    @ObservationIgnored private var task: Task<Void, Never>?

    func start(_ sym: String, spot: Bool) {
        task?.cancel()
        snap = nil
        state = "loading"
        let q = "sym=\(sym.addingPercentEncoding(withAllowedCharacters: .alphanumerics) ?? sym)\(spot ? "&type=spot" : "")"
        task = Task { [weak self] in
            while !Task.isCancelled {
                do {
                    let j = try await API.shared.get("/snapshot?\(q)")
                    self?.snap = Snapshot(j)
                    self?.state = "live"
                } catch let e as APIError where e.status == 404 {
                    self?.state = "missing"
                    return
                } catch {
                    if self?.state != "missing" { self?.state = "offline" }
                }
                if Demo.on { return }
                try? await Task.sleep(nanoseconds: 1_000_000_000)
            }
        }
    }

    func stop() { task?.cancel(); task = nil }
}

// MARK: - order-book grouping (BookTools.tsx)

struct BookLevel: Identifiable {
    var id: Double { p }
    var p: Double, q: Double, cum: Double
}

enum BookMath {
    static func clean(_ v: Double) -> Double { Double(String(format: "%.12g", v)) ?? v }
    static func stepDigits(_ step: Double) -> Int { max(0, Int(ceil(-log10(step) - 1e-9))) }

    static func groupSteps(_ price: Double, _ pd: Int) -> [Double] {
        let tick = clean(pow(10, -Double(pd)))
        let cap = max(tick, price * 0.02)
        var out: [Double] = []
        var d = tick
        while d <= cap * (1 + 1e-9) && out.count < 16 {
            out.append(d)
            if d > tick && d * 5 <= cap { out.append(clean(d * 5)) }
            d = clean(d * 10)
        }
        out.sort()
        while out.count > 7 {
            let i = out.firstIndex { v in
                let s = String(format: "%.12g", v).replacingOccurrences(of: "0", with: "").replacingOccurrences(of: ".", with: "")
                return s.hasPrefix("5")
            }
            out.remove(at: i ?? 1)
        }
        return out
    }

    static func groupLevels(_ levels: [Level], _ step: Double, ask: Bool, rows: Int) -> [BookLevel] {
        var m: [Double: Double] = [:]
        var far = ask ? -Double.infinity : Double.infinity
        for l in levels {
            let k = clean((ask ? ceil(l.p / step - 1e-9) : floor(l.p / step + 1e-9)) * step)
            m[k, default: 0] += l.q
            far = ask ? max(far, l.p) : min(far, l.p)
        }
        var keys = m.sorted { ask ? $0.key < $1.key : $0.key > $1.key }
        if keys.count > 1, let last = keys.last,
           ask ? far < last.key - step * 1e-6 : far > last.key + step * 1e-6 {
            keys.removeLast()
        }
        var c = 0.0
        var out: [BookLevel] = []
        for kv in keys.prefix(rows) {
            c += kv.value
            out.append(BookLevel(p: kv.key, q: kv.value, cum: c))
        }
        return out
    }

    static func span(bids: [Level], asks: [Level]) -> Double {
        guard let amax = asks.map({ $0.p }).max(), let amin = asks.map({ $0.p }).min(),
              let bmax = bids.map({ $0.p }).max(), let bmin = bids.map({ $0.p }).min() else { return 0 }
        return min(amax - amin, bmax - bmin)
    }
}

struct GroupedBook {
    var asks: [BookLevel] = []
    var bids: [BookLevel] = []
    var max: Double = 1e-12
    var buyPct: Int = 50
    var step: Double = 0.01
    var steps: [Double] = []
    var digits: Int = 2
}

/// useGroupedBook: grouped book plus Binance's deeper depth for coarse steps.
@MainActor
@Observable
final class BookModel {
    var chosen: Double = 0
    var wide: (bids: [Level], asks: [Level])?
    @ObservationIgnored private var sym = ""
    @ObservationIgnored private var task: Task<Void, Never>?
    @ObservationIgnored private var wideKey = ""

    func setSym(_ s: String) {
        guard s != sym else { return }
        sym = s
        chosen = UserDefaults.standard.double(forKey: "sky.bookStep." + s)
        wide = nil
    }

    func setStep(_ v: Double) {
        chosen = v
        UserDefaults.standard.set(v, forKey: "sky.bookStep." + sym)
    }

    /// Keeps Binance's 1,000-level book for listed symbols (every 2 s on coarse steps, else every 30 s).
    func follow(_ snap: Snapshot?, fast: Bool) {
        guard let snap, !snap.ref.isEmpty, snap.src == "spot" || snap.src == "perp", !Demo.on else { return }
        let perp = snap.src == "perp"
        let key = "\(snap.ref)|\(perp)|\(fast)"
        guard key != wideKey else { return }
        wideKey = key
        task?.cancel()
        let ref = snap.ref
        task = Task { [weak self] in
            while !Task.isCancelled {
                let url = perp ? "\(Binance.perpREST)/fapi/v1/depth?symbol=\(ref)&limit=1000" : "\(Binance.spotREST)/api/v3/depth?symbol=\(ref)&limit=1000"
                if let d = try? await API.shared.fetch(url) {
                    let lv: (JSON) -> [Level] = { side in side.array.map { (p: $0[0].double, q: $0[1].double) } }
                    self?.wide = (bids: lv(d["bids"]), asks: lv(d["asks"]))
                }
                try? await Task.sleep(nanoseconds: fast ? 2_000_000_000 : 30_000_000_000)
            }
        }
    }

    func stop() { task?.cancel(); task = nil; wideKey = "" }

    func book(_ snap: Snapshot?, rows: Int) -> GroupedBook {
        let pd = snap?.priceDec ?? 2
        let ref = snap.map { $0.last != 0 ? $0.last : $0.mark } ?? 0
        let all = BookMath.groupSteps(ref, pd)
        let src: (bids: [Level], asks: [Level]) = wide ?? (bids: snap?.bids ?? [], asks: snap?.asks ?? [])
        let span = BookMath.span(bids: src.bids, asks: src.asks)
        let steps = all.enumerated().filter { i, v in i == 0 || span / v >= 3 }.map { $0.element }
        let step = steps.contains(chosen) ? chosen : (steps.first ?? pow(10, -Double(pd)))
        let a = BookMath.groupLevels(src.asks, step, ask: true, rows: rows)
        let b = BookMath.groupLevels(src.bids, step, ask: false, rows: rows)
        let sa = a.last?.cum ?? 0, sb = b.last?.cum ?? 0
        var g = GroupedBook()
        g.asks = a.reversed()
        g.bids = b
        g.max = Swift.max(sa, sb, 1e-12)
        g.buyPct = sa + sb > 0 ? Int((sb / (sa + sb) * 100).rounded()) : 50
        g.step = step
        g.steps = steps
        g.digits = min(pd, BookMath.stepDigits(step))
        return g
    }

    func coarse(_ snap: Snapshot?) -> Bool {
        let pd = snap?.priceDec ?? 2
        let ref = snap.map { $0.last != 0 ? $0.last : $0.mark } ?? 0
        return chosen >= (BookMath.groupSteps(ref, pd).first ?? 0) * 10
    }
}

// MARK: - mini book (Mobile.tsx MiniBook)

struct MiniBook: View {
    @Environment(Prefs.self) private var prefs
    @Environment(\.pal) private var pal
    let book: GroupedBook
    let last: Double
    let up: Bool
    let rows: Int
    let lastText: String
    var sub: String?
    let qd: Int
    @Binding var stepOpen: Bool
    let onPick: (Double) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text(prefs.t("price"))
                Spacer()
                Text(prefs.t("quantity"))
            }
            .font(.inter(10)).foregroundColor(pal.muted)
            .padding(.bottom, 3)
            ForEach(book.asks.suffix(rows)) { r in row(r, ask: true) }
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(last > 0 ? lastText : "—").font(.inter(13.5, .semibold)).monospacedDigit()
                    .foregroundColor(up ? pal.green : pal.red).lineLimit(1)
                if let sub { Text(sub).font(.inter(10)).monospacedDigit().foregroundColor(pal.muted).lineLimit(1) }
            }
            .padding(.vertical, 3)
            ForEach(book.bids.prefix(rows)) { r in row(r, ask: false) }
            RatioBar(buyPct: book.buyPct).padding(.top, 6)
            Button { stepOpen = true } label: {
                HStack {
                    Text(prefs.num(book.step, BookMath.stepDigits(book.step))).font(.inter(11.5)).monospacedDigit()
                    Spacer()
                    Icon(.chevronDown, 14)
                }
                .foregroundColor(pal.ink)
                .padding(.horizontal, 10)
                .frame(height: 26)
                .background(RoundedRectangle(cornerRadius: 8).fill(pal.surface2))
            }
            .buttonStyle(PlainTap())
            .padding(.top, 6)
        }
    }

    private func row(_ r: BookLevel, ask: Bool) -> some View {
        Button { onPick(r.p) } label: {
            HStack(spacing: 4) {
                Text(prefs.num(r.p, book.digits)).foregroundColor(ask ? pal.red : pal.green)
                Spacer(minLength: 2)
                Text(prefs.num(r.q, qd)).foregroundColor(pal.ink)
            }
            .font(.inter(10.5)).monospacedDigit().lineLimit(1)
            .frame(height: 16.8)
            .background(alignment: .trailing) {
                GeometryReader { g in
                    Rectangle().fill((ask ? pal.red : pal.green).opacity(0.16))
                        .frame(width: g.size.width * CGFloat(min(1, r.cum / book.max)))
                        .frame(maxWidth: .infinity, alignment: .trailing)
                }
            }
        }
        .buttonStyle(PlainTap())
    }
}

/// Buy / sell share (RatioBar).
struct RatioBar: View {
    @Environment(\.pal) private var pal
    let buyPct: Int
    var body: some View {
        GeometryReader { g in
            HStack(spacing: 3) {
                HStack(spacing: 4) {
                    box("B")
                    Text("\(buyPct)%").monospacedDigit()
                }
                .foregroundColor(pal.green)
                .padding(.horizontal, 4)
                .frame(width: max(42, (g.size.width - 3) * CGFloat(buyPct) / 100), alignment: .leading)
                .frame(maxHeight: .infinity)
                .background(RoundedRectangle(cornerRadius: 3).fill(pal.greenTint))
                HStack(spacing: 4) {
                    Spacer(minLength: 0)
                    Text("\(100 - buyPct)%").monospacedDigit()
                    box("S")
                }
                .foregroundColor(pal.red)
                .padding(.horizontal, 4)
                .frame(minWidth: 42, maxWidth: .infinity, maxHeight: .infinity)
                .background(RoundedRectangle(cornerRadius: 3).fill(pal.redTint))
            }
        }
        .font(.inter(10.5, .semibold))
        .frame(height: 18)
    }
    private func box(_ s: String) -> some View {
        Text(s).font(.inter(9.5, .semibold)).frame(width: 14, height: 14)
            .overlay(RoundedRectangle(cornerRadius: 3).strokeBorder(lineWidth: 1))
    }
}

/// 0–100% slider with stops at 0/25/50/75/100, snapping within 3% (PctSlider).
struct PctSlider: View {
    @Environment(\.pal) private var pal
    let value: Double
    var disabled = false
    var height: CGFloat = 22
    let onChange: (Double) -> Void

    var body: some View {
        let v = max(0, min(100, value.rounded()))
        HStack(spacing: 10) {
            GeometryReader { g in
                let w = g.size.width - 14
                ZStack(alignment: .leading) {
                    Capsule().fill(pal.line).frame(height: 2).padding(.horizontal, 7)
                    Capsule().fill(pal.gold).frame(width: w * v / 100, height: 2).padding(.leading, 7)
                    ForEach([0.0, 25, 50, 75, 100], id: \.self) { m in
                        Circle().fill(pal.surface)
                            .overlay(Circle().strokeBorder(v >= m ? pal.gold : pal.line, lineWidth: 2))
                            .frame(width: 9, height: 9)
                            .position(x: 7 + w * m / 100, y: g.size.height / 2)
                    }
                    Circle().fill(pal.surface)
                        .overlay(Circle().strokeBorder(pal.gold, lineWidth: 3))
                        .frame(width: 16, height: 16)
                        .shadow(color: .black.opacity(0.25), radius: 1.5, x: 0, y: 1)
                        .position(x: 7 + w * v / 100, y: g.size.height / 2)
                }
                .contentShape(Rectangle())
                .gesture(DragGesture(minimumDistance: 0).onChanged { d in
                    guard !disabled, w > 0 else { return }
                    let n = max(0, min(100, (d.location.x - 7) / w * 100)).rounded()
                    let snap = [0.0, 25, 50, 75, 100].first { abs($0 - n) <= 3 }
                    onChange(snap ?? n)
                })
            }
            Text("\(Int(v))%").font(.inter(10.5)).monospacedDigit().foregroundColor(pal.muted)
                .frame(minWidth: 30, alignment: .trailing)
        }
        .frame(height: height)
        .opacity(disabled ? 0.5 : 1)
    }
}

/// Step picker list (sheet content).
struct StepList: View {
    @Environment(Prefs.self) private var prefs
    @Environment(\.pal) private var pal
    let steps: [Double]
    let step: Double
    let pick: (Double) -> Void
    var body: some View {
        VStack(spacing: 0) {
            ForEach(Array(steps.enumerated()), id: \.offset) { i, v in
                Button { pick(v) } label: {
                    HStack {
                        Text(prefs.num(v, BookMath.stepDigits(v))).font(.inter(17, v == step ? .semibold : .regular)).monospacedDigit()
                            .foregroundColor(pal.ink)
                        Spacer()
                        if v == step {
                            Icon(.check, 14).foregroundColor(pal.onGold).padding(2).background(Circle().fill(pal.gold))
                        }
                    }
                    .padding(.horizontal, 4)
                    .frame(height: 56)
                    .overlay(alignment: .bottom) { if i < steps.count - 1 { Hairline() } }
                }
                .buttonStyle(PlainTap())
            }
        }
    }
}

// MARK: - bottom sheet (Sheet.tsx: title, close button, content)

struct SkySheet<Content: View>: View {
    @Environment(\.pal) private var pal
    @Environment(\.dismiss) private var dismiss
    let title: String
    @ViewBuilder var content: () -> Content

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Text(title).font(.inter(17, .semibold)).foregroundColor(pal.ink).lineLimit(1)
                    Spacer()
                    IconButton(.x, size: 20) { dismiss() }
                }
                content()
            }
            .font(.inter(14))
            .padding(16)
            .padding(.bottom, 2)
        }
        .scrollBounceBehavior(.basedOnSize)
        .presentationDetents([.medium, .large])
        .presentationCornerRadius(20)
        .presentationBackground(pal.surface)
        .presentationDragIndicator(.hidden)
    }
}

// MARK: - toast (.sx-toast)

struct Toast: ViewModifier {
    @Environment(\.pal) private var pal
    @Binding var text: String
    func body(content: Content) -> some View {
        content.overlay(alignment: .bottom) {
            if !text.isEmpty {
                Text(text).font(.inter(14, .semibold)).foregroundColor(pal.bg).lineLimit(1)
                    .padding(.horizontal, 18).padding(.vertical, 10)
                    .background(RoundedRectangle(cornerRadius: 12).fill(pal.ink))
                    .shadow(color: .black.opacity(0.35), radius: 12, x: 0, y: 6)
                    .padding(.bottom, 24)
                    .transition(.opacity)
                    .task(id: text) {
                        try? await Task.sleep(nanoseconds: 1_800_000_000)
                        text = ""
                    }
            }
        }
        .animation(.easeOut(duration: 0.2), value: text)
    }
}

extension View {
    func toast(_ text: Binding<String>) -> some View { modifier(Toast(text: text)) }
}

// MARK: - candles (ui.tsx CandleChart), drawn in the same 760-wide frame

struct CandleChart: View {
    @Environment(\.pal) private var pal
    let data: [Candle]
    var height: CGFloat = 560
    @State private var n: Int = 90
    @State private var end: Int = 0
    @State private var pinchN: Int?
    @State private var dragEnd: Int?

    var body: some View {
        GeometryReader { g in
            let scale = g.size.width / 760
            let total = data.count
            let count = max(min(12, total), min(n, total))
            let e = max(0, min(end, total - count))
            let vis = Array(data[max(0, total - e - count)..<max(0, total - e)])
            Canvas { ctx, size in
                draw(ctx, vis: vis, scale: scale, size: size)
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 4)
                    .onChanged { d in
                        let start = dragEnd ?? e
                        if dragEnd == nil { dragEnd = e }
                        let bar = g.size.width / CGFloat(max(count, 1))
                        let shift = Int((d.translation.width / bar).rounded())
                        end = max(0, min(total - count, start + shift))
                    }
                    .onEnded { _ in dragEnd = nil }
            )
            .simultaneousGesture(
                MagnificationGesture()
                    .onChanged { m in
                        let base = pinchN ?? count
                        if pinchN == nil { pinchN = count }
                        n = Int(max(12, min(Double(max(total, 12)), Double(base) / Double(m))))
                    }
                    .onEnded { _ in pinchN = nil }
            )
            .overlay(alignment: .topTrailing) {
                HStack(spacing: 2) {
                    zoomButton(.zoomIn) { n = max(12, Int((Double(n) / 1.5).rounded())) }
                    zoomButton(.zoomOut) { n = min(max(total, 12), Int((Double(n) * 1.5).rounded())) }
                    zoomButton(.maximize2) { n = 90; end = 0 }
                }
                .padding(6)
            }
        }
        .aspectRatio(760 / height, contentMode: .fit)
    }

    private func zoomButton(_ icon: Lucide, _ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Icon(icon, 15).foregroundColor(pal.muted).frame(width: 26, height: 24)
                .background(RoundedRectangle(cornerRadius: 6).fill(pal.surface2.opacity(0.9)))
        }
        .buttonStyle(PlainTap())
    }

    private func draw(_ ctx: GraphicsContext, vis: [Candle], scale k: CGFloat, size: CGSize) {
        let W: CGFloat = 760, H = height, VH: CGFloat = 54, top: CGFloat = 8, bottom = H - VH - 18
        let hi = vis.map { $0.h }.max() ?? 1, lo0 = vis.map { $0.l }.min() ?? 0
        let span = max(hi - lo0, abs((hi + lo0) / 2) * 0.002, 0.00000001)
        let lo = (hi + lo0 - span) / 2
        func y(_ v: Double) -> CGFloat { (top + (1 - CGFloat((v - lo) / span)) * (bottom - top)) * k }
        let bw = W / CGFloat(max(vis.count, 12))
        let maxV = max(1, vis.map { $0.v }.max() ?? 1)
        for i in 0..<4 {
            let yy = (top + (bottom - top) / 3 * CGFloat(i)) * k
            ctx.stroke(Path { p in p.move(to: CGPoint(x: 0, y: yy)); p.addLine(to: CGPoint(x: W * k, y: yy)) }, with: .color(pal.line), lineWidth: 1)
        }
        for (i, c) in vis.enumerated() {
            let x = (CGFloat(i) * bw + bw / 2) * k
            let col = c.c >= c.o ? pal.green : pal.red
            ctx.stroke(Path { p in p.move(to: CGPoint(x: x, y: y(c.h))); p.addLine(to: CGPoint(x: x, y: y(c.l))) }, with: .color(col), lineWidth: max(1, k))
            let bodyTop = y(max(c.o, c.c))
            let bodyH = max(1, abs(y(c.o) - y(c.c)))
            ctx.fill(Path(CGRect(x: x - bw * 0.32 * k, y: bodyTop, width: bw * 0.64 * k, height: bodyH)), with: .color(col))
            let vh = CGFloat(c.v / maxV) * VH
            ctx.fill(Path(CGRect(x: x - bw * 0.32 * k, y: (H - 18 - vh) * k, width: bw * 0.64 * k, height: vh * k)), with: .color(col.opacity(0.28)))
        }
        guard !vis.isEmpty else { return }
        let fmt: (Double) -> String = { v in
            let f = NumberFormatter(); f.maximumSignificantDigits = 8; f.usesSignificantDigits = true; f.numberStyle = .decimal
            return f.string(from: NSNumber(value: v)) ?? "\(v)"
        }
        ctx.draw(Text(fmt(hi)).font(.inter(10 * max(k, 0.9))).foregroundColor(pal.muted), at: CGPoint(x: 4 * k, y: (top + 11) * k), anchor: .bottomLeading)
        ctx.draw(Text(fmt(lo0)).font(.inter(10 * max(k, 0.9))).foregroundColor(pal.muted), at: CGPoint(x: 4 * k, y: (bottom - 3) * k), anchor: .bottomLeading)
        if let last = data.last, last.c >= lo, last.c <= lo + span {
            let ly = y(last.c)
            ctx.stroke(Path { p in p.move(to: CGPoint(x: 0, y: ly)); p.addLine(to: CGPoint(x: W * k, y: ly)) },
                       with: .color(pal.ink.opacity(0.5)), style: StrokeStyle(lineWidth: 1, dash: [3, 3]))
            ctx.draw(Text(fmt(last.c)).font(.inter(11 * max(k, 0.9))).foregroundColor(pal.ink),
                     at: CGPoint(x: (W - 4) * k, y: max((top + 12) * k, ly - 5 * k)), anchor: .bottomTrailing)
        }
    }
}

/// Chart history (useKlines): Binance via skyd for listed symbols, SKY's own otherwise.
@MainActor
@Observable
final class Klines {
    var candles: [Candle] = []
    @ObservationIgnored private var task: Task<Void, Never>?
    @ObservationIgnored private var key = ""

    static let tf: [String: (String, Int)] = ["1m": ("1m", 1), "5m": ("5m", 5), "15m": ("15m", 15), "1h": ("1h", 60), "4h": ("4h", 240), "1d": ("1d", 1440)]

    func follow(_ snap: Snapshot?, tf: String) {
        guard let snap else { return }
        let k = "\(snap.sym)|\(snap.src)|\(snap.ref)|\(snap.spot)|\(tf)"
        guard k != key else { return }
        key = k
        candles = []
        task?.cancel()
        let t = Klines.tf[tf] ?? ("1h", 60)
        let listed = !snap.ref.isEmpty && ["spot", "perp", "alpha"].contains(snap.src)
        let path = listed
            ? "/klines/ref?sym=\(snap.ref)&i=\(t.0)\(snap.src == "perp" ? "&perp=1" : "")"
            : "/klines?sym=\(snap.sym)&m=\(t.1)\(snap.spot ? "&type=spot" : "")"
        let every: UInt64 = snap.src == "local" ? 5 : 30
        task = Task { [weak self] in
            while !Task.isCancelled {
                if let rows = try? await API.shared.get(path) {
                    self?.candles = rows.array.map { r in
                        listed
                            ? Candle(t: r[0].double, o: r[1].double, h: r[2].double, l: r[3].double, c: r[4].double, v: r[5].double)
                            : Candle(t: r["t"].double, o: r["o"].double, h: r["h"].double, l: r["l"].double, c: r["c"].double, v: r["v"].double)
                    }
                }
                try? await Task.sleep(nanoseconds: every * 1_000_000_000)
            }
        }
    }

    func stop() { task?.cancel(); task = nil; key = "" }

    /// SKY's last trade drives the live candle.
    func live(_ last: Double, src: String) -> [Candle] {
        guard var c = candles.last, last > 0, src != "local" else { return candles }
        c.c = last; c.h = max(c.h, last); c.l = min(c.l, last)
        return Array(candles.dropLast()) + [c]
    }
}

/// Timeframe pills under the chart.
struct TimeframeTabs: View {
    @Environment(Prefs.self) private var prefs
    @Binding var tf: String
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            PillTabs(items: [("1m", prefs.t("min1")), ("5m", prefs.t("min5")), ("15m", prefs.t("min15")),
                             ("1h", prefs.t("hour")), ("4h", prefs.t("hour4")), ("1d", prefs.t("day"))], value: $tf)
        }
    }
}

// MARK: - pair header + picker (PairPicker.tsx)

struct PairHeader: View {
    @Environment(Prefs.self) private var prefs
    @Environment(\.pal) private var pal
    let sym: String
    let base: String
    let icon: String
    let sub: String
    let cat: String
    let catSub: String
    var spot = false
    @Binding var pickerOpen: Bool

    var body: some View {
        let watch = Watchlist.shared
        HStack(spacing: 10) {
            Button { pickerOpen = true } label: {
                HStack(spacing: 8) {
                    MarketIcon(base: base, icon: icon, cat: cat, sub: catSub, size: 24)
                    VStack(alignment: .leading, spacing: 0) {
                        Text("\(base)\(spot ? "/" : "")USDT").font(.inter(14, .semibold)).foregroundColor(pal.ink).lineLimit(1)
                        Text(sub).font(.inter(10.5)).foregroundColor(pal.muted).lineLimit(1)
                    }
                    Icon(.chevronDown, 14).foregroundColor(pal.ink)
                }
            }
            .buttonStyle(PlainTap())
            Button { watch.toggle(sym); Haptic.tap() } label: {
                Icon(.star, 15, filled: watch.stars.contains(sym))
                    .foregroundColor(watch.stars.contains(sym) ? pal.gold : pal.muted)
                    .padding(4)
            }
            .buttonStyle(PlainTap())
        }
    }
}

struct PairPickerSheet: View {
    @Environment(Prefs.self) private var prefs
    @Environment(Router.self) private var router
    @Environment(\.pal) private var pal
    @Environment(\.dismiss) private var dismiss
    let sym: String
    var spot = false
    @State private var cat = "crypto"
    @State private var q = ""
    @State private var catalog = Catalog()

    var body: some View {
        let watch = Watchlist.shared
        let tabs: [(String, String)] = [("fav", "★"), ("crypto", prefs.t("crypto")), ("tradfi", prefs.t("tradfi")),
                                         ("commodities", prefs.t("commodities")), ("onchain", prefs.t("onchain"))]
            .filter { !spot || $0.0 != "onchain" }
        let items: [CatItem] = cat == "fav"
            ? ["tradfi", "crypto", "commodities", "onchain"].flatMap { catalog.items[$0] ?? [] }
            : catalog.items[cat] ?? []
        let qq = q.trimmingCharacters(in: .whitespaces).lowercased()
        var seen = Set<String>()
        let rows = items.filter { x in
            guard !seen.contains(x.sym) else { return false }
            seen.insert(x.sym)
            return (spot ? x.spot : x.tradable) && (cat != "fav" || watch.stars.contains(x.sym))
                && (qq.isEmpty || x.base.lowercased().contains(qq) || x.name.lowercased().contains(qq))
        }.prefix(120)
        return VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Icon(.search, 15).foregroundColor(pal.muted)
                TextField("", text: $q, prompt: Text(prefs.t("search")).foregroundColor(pal.muted))
                    .font(.inter(13)).textInputAutocapitalization(.never).autocorrectionDisabled()
                IconButton(.x, size: 18) { dismiss() }
            }
            .padding(.leading, 12)
            .frame(height: 38)
            .background(RoundedRectangle(cornerRadius: 8).fill(pal.surface2))
            ScrollView(.horizontal, showsIndicators: false) {
                Tabs(items: tabs.map { ($0.0, $0.1) }, value: $cat, gap: 14, padBottom: 6)
            }
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(Array(rows)) { x in
                        Button {
                            dismiss()
                            router.go(spot ? .spot(x.sym) : .trade(x.sym))
                        } label: {
                            HStack(spacing: 8) {
                                if watch.stars.contains(x.sym) { Icon(.star, 12, filled: true).foregroundColor(pal.gold) }
                                MarketIcon(base: x.base, icon: x.icon, cat: x.cat, sub: x.sub, chain: x.chain, size: 18)
                                Text(x.base).font(.inter(13, .semibold)).foregroundColor(pal.ink)
                                Text(x.chain.isEmpty ? "USDT" : x.chain).font(.inter(11.5)).foregroundColor(pal.muted)
                                Spacer(minLength: 4)
                                Num(priceFmt(x.price, prefs), 13)
                                Chg(v: x.chg, plain: true, size: 13).frame(width: 70, alignment: .trailing)
                            }
                            .padding(.horizontal, 8).padding(.vertical, 8)
                            .background(RoundedRectangle(cornerRadius: 6).fill(x.sym == sym ? pal.surface2 : .clear))
                        }
                        .buttonStyle(PlainTap())
                    }
                    if rows.isEmpty {
                        Text(prefs.t("noData")).font(.inter(12.5)).foregroundColor(pal.muted).padding(.vertical, 14)
                    }
                }
            }
        }
        .padding(12)
        .background(pal.surface)
        .presentationDetents([.large])
        .presentationCornerRadius(20)
        .presentationBackground(pal.surface)
        .task(id: cat) {
            if cat == "fav" {
                for c in ["crypto", "tradfi", "commodities", "onchain"] { await catalog.load(c) }
            } else {
                await catalog.load(cat)
            }
        }
    }
}

// MARK: - form pieces (phone .m-form)

/// .input: label, right-aligned value, unit.
struct FormInput: View {
    @Environment(\.pal) private var pal
    let label: String
    @Binding var text: String
    var placeholder = ""
    var unit = ""
    var disabled = false
    var height: CGFloat = 32

    var body: some View {
        HStack(spacing: 4) {
            Text(label).font(.inter(10.5)).foregroundColor(pal.muted).lineLimit(1).fixedSize()
            TextField("", text: $text, prompt: Text(placeholder).foregroundColor(pal.muted))
                .font(.inter(12)).monospacedDigit()
                .multilineTextAlignment(.trailing)
                .keyboardType(.decimalPad)
                .foregroundColor(disabled ? pal.muted : pal.ink)
                .disabled(disabled)
            if !unit.isEmpty { Text(unit).font(.inter(10.5)).foregroundColor(pal.ink2).lineLimit(1).fixedSize() }
        }
        .padding(.horizontal, 7)
        .frame(height: height)
        .background(RoundedRectangle(cornerRadius: 8).fill(pal.surface2))
    }
}

/// .kvs rows (label left, value right).
struct KV: View {
    @Environment(\.pal) private var pal
    let k: String
    let v: String
    var color: Color?
    var size: CGFloat = 10.5
    var body: some View {
        HStack(spacing: 6) {
            Text(k).foregroundColor(pal.muted).lineLimit(1).truncationMode(.tail)
            Spacer(minLength: 4)
            Text(v).monospacedDigit().foregroundColor(color ?? pal.ink).lineLimit(1).fixedSize()
        }
        .font(.inter(size))
    }
}

/// .m-item card row of the order / holding lists.
struct MItem: View {
    @Environment(\.pal) private var pal
    let title: String
    var tag: (String, Bool)?
    var action: (String, () -> Void)?
    var onTitle: (() -> Void)?
    let fields: [(String, String, Color?)]

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack {
                HStack(spacing: 10) {
                    Button { onTitle?() } label: { Text(title).font(.inter(11.5, .semibold)).foregroundColor(pal.ink) }
                        .buttonStyle(PlainTap())
                    if let tag {
                        Text(tag.0).font(.inter(10.5)).foregroundColor(tag.1 ? pal.green : pal.red)
                            .padding(.horizontal, 6).padding(.vertical, 1)
                            .background(RoundedRectangle(cornerRadius: 4).fill(tag.1 ? pal.greenTint : pal.redTint))
                    }
                }
                Spacer()
                if let action {
                    Button(action.0, action: action.1)
                        .font(.inter(11, .semibold)).foregroundColor(pal.ink)
                        .padding(.horizontal, 10).frame(minHeight: 24)
                        .background(RoundedRectangle(cornerRadius: 8).fill(pal.surface2))
                        .buttonStyle(PlainTap())
                }
            }
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 5), count: 3), alignment: .leading, spacing: 5) {
                ForEach(fields.indices, id: \.self) { i in
                    VStack(alignment: i % 3 == 2 ? .trailing : .leading, spacing: 1) {
                        Text(fields[i].0).font(.inter(10)).foregroundColor(pal.muted).lineLimit(1)
                        Text(fields[i].1).font(.inter(11.5)).monospacedDigit().foregroundColor(fields[i].2 ?? pal.ink).lineLimit(1)
                    }
                    .frame(maxWidth: .infinity, alignment: i % 3 == 2 ? .trailing : .leading)
                }
            }
        }
        .padding(.vertical, 8)
    }
}
