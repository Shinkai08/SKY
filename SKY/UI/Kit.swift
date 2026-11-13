import SwiftUI

// Building blocks matching the website's primitives (styles.css, phone sizes ≤720px).

/// A Lucide icon drawn from its 24×24 path; the stroke scales with the size like lucide-react.
struct Icon: View {
    let icon: Lucide
    var size: CGFloat = 16
    var stroke: CGFloat = 2
    var filled = false

    init(_ icon: Lucide, _ size: CGFloat = 16, stroke: CGFloat = 2, filled: Bool = false) {
        self.icon = icon; self.size = size; self.stroke = stroke; self.filled = filled
    }

    var body: some View {
        let s = size / 24
        let path = icon.path.applying(CGAffineTransform(scaleX: s, y: s))
        ZStack {
            if filled { path.fill() }
            path.stroke(style: StrokeStyle(lineWidth: stroke * s, lineCap: .round, lineJoin: .round))
        }
        .frame(width: size, height: size)
    }
}

/// A number in Inter with tabular digits that never wraps (`.number`).
struct Num: View {
    @Environment(\.pal) private var pal
    let text: String
    var size: CGFloat = 13
    var weight: Font.Weight = .regular
    var color: Color?
    init(_ text: String, _ size: CGFloat = 13, _ weight: Font.Weight = .regular, color: Color? = nil) {
        self.text = text; self.size = size; self.weight = weight; self.color = color
    }
    var body: some View {
        Text(text).font(.inter(size, weight)).monospacedDigit().foregroundColor(color ?? pal.ink)
            .lineLimit(1).fixedSize(horizontal: true, vertical: false)
    }
}

// MARK: card

struct CardStyle: ViewModifier {
    @Environment(\.pal) private var pal
    var padding: CGFloat = 12
    var tint = false
    func body(content: Content) -> some View {
        content
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background {
                RoundedRectangle(cornerRadius: 10).fill(pal.surface)
                if tint { RoundedRectangle(cornerRadius: 10).fill(pal.champagne) }
            }
            .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(pal.line, lineWidth: 1))
    }
}

extension View {
    func card(_ padding: CGFloat = 12, tint: Bool = false) -> some View { modifier(CardStyle(padding: padding, tint: tint)) }

    @ViewBuilder func `if`<V: View>(_ cond: Bool, _ apply: (Self) -> V) -> some View {
        if cond { apply(self) } else { self }
    }
}

// MARK: buttons (.btn)

enum BtnKind { case plain, gold, ghost, long, short }
enum BtnSize { case sm, md, lg }

struct BtnStyle: ButtonStyle {
    @Environment(\.pal) private var pal
    @Environment(\.isEnabled) private var enabled
    var kind: BtnKind = .plain
    var size: BtnSize = .md
    var wide = false

    func makeBody(configuration: Configuration) -> some View {
        let h: CGFloat = size == .lg ? 40 : size == .sm ? 28 : 36
        let font: CGFloat = size == .lg ? 14 : size == .sm ? 12 : 13
        let padX: CGFloat = size == .lg ? 20 : size == .sm ? 10 : 14
        let fg: Color = kind == .gold ? pal.onGold : (kind == .long || kind == .short) ? .white : pal.ink
        return configuration.label
            .font(.inter(font, .semibold))
            .lineLimit(1)
            .foregroundColor(fg)
            .padding(.horizontal, padX)
            .frame(minHeight: h)
            .frame(maxWidth: wide ? .infinity : nil)
            .background {
                switch kind {
                case .gold: RoundedRectangle(cornerRadius: 8).fill(pal.goldGrad)
                case .long: RoundedRectangle(cornerRadius: 8).fill(pal.green)
                case .short: RoundedRectangle(cornerRadius: 8).fill(pal.red)
                case .ghost: RoundedRectangle(cornerRadius: 8).strokeBorder(pal.line, lineWidth: 1)
                case .plain: RoundedRectangle(cornerRadius: 8).fill(configuration.isPressed ? pal.hover : pal.surface2)
                }
            }
            .opacity(enabled ? (configuration.isPressed && kind != .plain ? 0.9 : 1) : 0.4)
            .contentShape(Rectangle())
    }
}

extension View {
    func btn(_ kind: BtnKind = .plain, _ size: BtnSize = .md, wide: Bool = false) -> some View {
        buttonStyle(BtnStyle(kind: kind, size: size, wide: wide))
    }
}

/// Plain tap target without the default button highlight.
struct PlainTap: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.contentShape(Rectangle()).opacity(configuration.isPressed ? 0.7 : 1)
    }
}

// MARK: tabs (.tabs)

struct Tabs<ID: Hashable>: View {
    @Environment(\.pal) private var pal
    let items: [(id: ID, label: String)]
    @Binding var value: ID
    var size: CGFloat = 13
    var gap: CGFloat = 16
    var padBottom: CGFloat = 9

    var body: some View {
        HStack(spacing: gap) {
            ForEach(items.indices, id: \.self) { i in
                let it = items[i]
                let on = it.id == value
                Button { value = it.id; Haptic.tap() } label: {
                    Text(it.label)
                        .font(.inter(size, .medium))
                        .foregroundColor(on ? pal.ink : pal.muted)
                        .lineLimit(1)
                        .fixedSize()
                        .padding(.bottom, padBottom)
                        .overlay(alignment: .bottom) {
                            if on {
                                GeometryReader { g in
                                    RoundedRectangle(cornerRadius: 2).fill(pal.gold)
                                        .frame(width: g.size.width * 0.5, height: 3)
                                        .position(x: g.size.width / 2, y: g.size.height - 1.5)
                                }
                            }
                        }
                }
                .buttonStyle(PlainTap())
            }
        }
    }
}

/// .tabs.pill
struct PillTabs<ID: Hashable>: View {
    @Environment(\.pal) private var pal
    let items: [(id: ID, label: String)]
    @Binding var value: ID
    var body: some View {
        HStack(spacing: 2) {
            ForEach(items.indices, id: \.self) { i in
                let it = items[i]
                let on = it.id == value
                Button { value = it.id; Haptic.tap() } label: {
                    Text(it.label).font(.inter(11.5, .medium))
                        .foregroundColor(on ? pal.gold : pal.muted)
                        .padding(.horizontal, 8).padding(.vertical, 3)
                        .background(RoundedRectangle(cornerRadius: 6).fill(on ? pal.surface2 : .clear))
                }
                .buttonStyle(PlainTap())
            }
        }
    }
}

// MARK: change chip (.chg)

struct Chg: View {
    @Environment(\.pal) private var pal
    let v: Double
    var plain = false
    var size: CGFloat = 12
    var body: some View {
        let text = Fmt.pct(v)
        if plain {
            Num(text, size, color: pal.dir(v))
        } else {
            Num(text, 12, color: pal.dir(v))
                .padding(.horizontal, 8).padding(.vertical, 2)
                .background(RoundedRectangle(cornerRadius: 6).fill(pal.dirTint(v)))
        }
    }
}

// MARK: avatar (Social.tsx Avatar)

struct AvatarView: View {
    @Environment(\.pal) private var pal
    let a: Author
    var size: CGFloat = 40

    static let frames = ["orbit", "frost", "jade", "noir", "crown"]

    var body: some View {
        let frame = AvatarView.frames.contains(a.frame) ? a.frame : ""
        let face = frame.isEmpty ? size : size * (frame == "crown" ? 0.65 : 0.69)
        ZStack {
            faceView(face)
                .offset(x: frame == "crown" ? -size * 0.015 : 0, y: frame == "crown" ? size * 0.10 : 0)
            if !frame.isEmpty {
                WebImg(name: "avatar-frames-\(frame).\(frame == "crown" ? "png" : "webp")", mode: .fit)
                    .frame(width: size, height: size)
            }
        }
        .frame(width: size, height: size)
    }

    @ViewBuilder private func faceView(_ s: CGFloat) -> some View {
        if a.photo.hasPrefix("/api/v1/avatars/"), let url = API.asset(a.photo) {
            AsyncImage(url: url) { img in
                img.resizable().scaledToFill()
            } placeholder: { pal.surface2 }
            .frame(width: s, height: s)
            .clipShape(Circle())
            .overlay(Circle().strokeBorder(pal.line, lineWidth: 1))
        } else if !a.avatar.isEmpty {
            Text(a.avatar).font(.system(size: s * 0.56))
                .frame(width: s, height: s)
                .background(Circle().fill(pal.surface2))
                .overlay(Circle().strokeBorder(pal.line, lineWidth: 1))
        } else {
            Text(String(a.nick.first.map { String($0) } ?? "?").uppercased())
                .font(.inter(s * 0.42, .bold))
                .foregroundColor(pal.onGold)
                .frame(width: s, height: s)
                .background(Circle().fill(pal.goldGrad))
        }
    }
}

// MARK: market icons (MarketIcon.tsx, ui.tsx Token)

enum Logos {
    static let companies: [String: String] = [
        "AAPL": "apple.com", "NVDA": "nvidia.com", "MSFT": "microsoft.com", "AMZN": "amazon.com",
        "GOOG": "google.com", "GOOGL": "google.com", "AVGO": "broadcom.com", "META": "meta.com",
        "TSLA": "tesla.com", "BRK": "berkshirehathaway.com", "BRKB": "berkshirehathaway.com",
        "LLY": "lilly.com", "JPM": "jpmorganchase.com", "AMD": "amd.com", "MU": "micron.com",
        "V": "visa.com", "JNJ": "jnj.com", "XOM": "exxonmobil.com", "WMT": "walmart.com",
        "MA": "mastercard.com", "ABBV": "abbvie.com", "COST": "costco.com", "CVX": "chevron.com",
        "PG": "pg.com", "PLTR": "palantir.com", "CSCO": "cisco.com", "KO": "coca-colacompany.com",
        "INTC": "intel.com", "ORCL": "oracle.com", "IBM": "ibm.com", "NFLX": "netflix.com",
        "NKE": "nike.com", "HD": "homedepot.com", "DIS": "disney.com", "UBER": "uber.com",
        "COIN": "coinbase.com", "MSTR": "strategy.com", "HOOD": "robinhood.com", "QCOM": "qualcomm.com",
        "TSM": "tsmc.com", "BABA": "alibabagroup.com", "ASML": "asml.com", "CRM": "salesforce.com",
        "ADBE": "adobe.com", "ARM": "arm.com", "MRK": "merck.com", "UNH": "unitedhealthgroup.com",
        "BAC": "bankofamerica.com", "GS": "goldmansachs.com", "MCD": "mcdonalds.com",
        "SKHYNIX": "skhynix.com", "SAMSUNG": "samsung.com", "SAMSUNGEM": "samsungsem.com",
        "HYUNDAI": "hyundai.com", "HANMI": "hanmisemi.com", "LGELECTRONICS": "lg.com",
        "NAVER": "naver.com", "KODEX200": "samsungfund.com", "TENCENT": "tencent.com",
        "HK0700": "tencent.com", "HK1810": "mi.com", "BYD": "byd.com", "HK0992": "lenovo.com",
        "POPMART": "popmart.com", "MEITUAN": "meituan.com", "KUAISHOU": "kuaishou.com",
        "OPENAI": "openai.com", "ANTHROPIC": "anthropic.com", "OURA": "ouraring.com",
        "UNITREE": "unitree.com", "CXMT": "cxmt.com", "MINIMAX": "minimax.io",
        "QQQ": "invesco.com", "SPY": "ssga.com", "IWM": "ishares.com", "EWY": "ishares.com", "EWJ": "ishares.com",
    ]
    static let country: [String: String] = [
        "EUR": "eu", "USD": "us", "GBP": "gb", "JPY": "jp", "CHF": "ch", "CAD": "ca", "AUD": "au", "NZD": "nz",
        "CNY": "cn", "HKD": "hk", "SGD": "sg", "KRW": "kr", "INR": "in", "BRL": "br", "MXN": "mx",
        "ZAR": "za", "SEK": "se", "NOK": "no", "DKK": "dk", "PLN": "pl", "CZK": "cz", "HUF": "hu",
        "RON": "ro", "TRY": "tr", "THB": "th", "IDR": "id", "MYR": "my", "PHP": "ph", "ILS": "il", "UAH": "ua",
    ]

    static func url(base raw: String, icon: String, cat: String, sub: String, chain: String) -> URL? {
        let base = raw.uppercased().replacingOccurrences(of: "[\\s.-]", with: "", options: .regularExpression)
        if !icon.isEmpty { return URL(string: icon.hasPrefix("/") ? API.site.absoluteString + icon : icon) }
        if sub == "fx" {
            guard let flag = country[String(base.prefix(3))] else { return nil }
            return URL(string: "https://flagcdn.com/w80/\(flag).png")
        }
        if chain.isEmpty && (cat == "crypto" || sub == "spot"),
           base.range(of: "^[A-Z0-9]{2,12}$", options: .regularExpression) != nil {
            return URL(string: "https://cdn.jsdelivr.net/npm/cryptocurrency-icons@0.18.1/128/color/\(base.lowercased()).png")
        }
        if chain.isEmpty, let domain = companies[base] {
            return URL(string: "https://www.google.com/s2/favicons?domain=\(domain)&sz=64")
        }
        return nil
    }
}

struct MarketIcon: View {
    @Environment(\.pal) private var pal
    let base: String
    var icon = ""
    var cat = "crypto"
    var sub = ""
    var chain = ""
    var size: CGFloat = 26

    var body: some View {
        let clean = base.uppercased().replacingOccurrences(of: "[\\s.-]", with: "", options: .regularExpression)
        Group {
            if let url = Logos.url(base: base, icon: icon, cat: cat, sub: sub, chain: chain) {
                AsyncImage(url: url) { phase in
                    if let img = phase.image {
                        img.resizable().scaledToFill()
                    } else if phase.error != nil {
                        fallback(clean)
                    } else {
                        Circle().fill(pal.surface2)
                    }
                }
            } else {
                fallback(clean)
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
    }

    @ViewBuilder private func fallback(_ b: String) -> some View {
        let hue = b.unicodeScalars.reduce(0) { ($0 * 31 + Int($1.value)) % 360 }
        let glyph: Lucide? = ["CL", "BZ", "WTI", "BRENT"].contains(b) ? .droplet : b == "NATGAS" ? .flame
            : ["XAU", "XAG", "XPT", "XPD"].contains(b) ? .gem : b == "COPPER" ? .layers : nil
        ZStack {
            Circle().fill(Color.hsl(Double(hue), 0.48, 0.36))
            if let glyph {
                Icon(glyph, (size * 0.57).rounded()).foregroundColor(.white)
            } else {
                Text(String(b.prefix(2))).font(.inter(size * 0.35, .semibold)).foregroundColor(.white)
            }
        }
    }
}

/// ui.tsx Token: coloured letter coin for the home list.
struct Token: View {
    let sym: String
    var size: CGFloat = 28
    static let colors: [String: UInt32] = ["BTC": 0xb48a38, "ETH": 0x7d87a3, "SOL": 0x806da3, "XRP": 0x2a2d31,
                                           "DOGE": 0xc79a3a, "AVAX": 0xc76c75, "LINK": 0x6481b2]
    var body: some View {
        let bg = sym == "USDT" ? Color(hex: 0x3fae95) : Color(hex: Token.colors[sym] ?? 0x6a737e)
        Text(sym == "USDT" ? "T" : String(sym.prefix(1)))
            .font(.inter(size * 0.42, .semibold))
            .foregroundColor(.white)
            .frame(width: size, height: size)
            .background(Circle().fill(bg))
    }
}

// MARK: haptics

enum Haptic {
    static var enabled = true
    static func tap() {
        guard enabled else { return }
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }
    static func success() {
        guard enabled else { return }
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }
    static func error() {
        guard enabled else { return }
        UINotificationFeedbackGenerator().notificationOccurred(.error)
    }
}

// MARK: misc

extension Color {
    /// CSS hsl(h s% l%).
    static func hsl(_ h: Double, _ s: Double, _ l: Double, _ a: Double = 1) -> Color {
        let v = l + s * min(l, 1 - l)
        let sv = v == 0 ? 0 : 2 * (1 - l / v)
        return Color(hue: (h.truncatingRemainder(dividingBy: 360)) / 360, saturation: sv, brightness: v, opacity: a)
    }
}

struct Hairline: View {
    @Environment(\.pal) private var pal
    var body: some View { Rectangle().fill(pal.line).frame(height: 1) }
}

/// Loading / empty placeholder (`.empty`).
struct EmptyNote: View {
    @Environment(\.pal) private var pal
    let text: String
    var pad: CGFloat = 40
    var body: some View {
        Text(text).font(.inter(13)).foregroundColor(pal.muted)
            .frame(maxWidth: .infinity).padding(.vertical, pad)
    }
}

/// Gold-gradient text (.gold-text).
struct GoldText: View {
    @Environment(\.pal) private var pal
    let text: String
    let font: Font
    var tracking: CGFloat = 0
    var body: some View {
        Text(text).font(font).tracking(tracking)
            .foregroundStyle(pal.goldGrad)
    }
}
