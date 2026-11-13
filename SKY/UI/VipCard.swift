import SwiftUI

// VIP 悦享卡 (VipCard.tsx): artwork + overlays positioned in card-width units (1 cqw = width / 100).

enum CardTier: String, CaseIterable {
    case bronze, silver, gold, platinum, blackgold

    var en: String {
        switch self {
        case .bronze: return "BRONZE"
        case .silver: return "SILVER"
        case .gold: return "GOLD"
        case .platinum: return "PLATINUM"
        case .blackgold: return "BLACK GOLD"
        }
    }
    var levels: (Int, Int) {
        switch self {
        case .bronze: return (0, 1)
        case .silver: return (2, 3)
        case .gold: return (4, 5)
        case .platinum: return (6, 7)
        case .blackgold: return (8, 9)
        }
    }
    /// --tint
    var tint: Color {
        switch self {
        case .bronze: return Color(r: 241, g: 190, b: 157)
        case .silver: return Color(r: 226, g: 233, b: 243)
        case .gold: return Color(r: 255, g: 224, b: 150)
        case .platinum: return Color(r: 219, g: 238, b: 253)
        case .blackgold: return Color(r: 245, g: 213, b: 143)
        }
    }
    static func forLevel(_ level: Int) -> CardTier {
        allCases.first { level >= $0.levels.0 && level <= $0.levels.1 } ?? .bronze
    }
}

func tierName(_ level: Int, _ prefs: Prefs) -> String { level == 0 ? prefs.t("regular") : "VIP \(level)" }

private extension View {
    /// Place text so its baseline sits at (x, y) — the CSS translateY(-.86em) on a 1em line box.
    func baselineAt(_ x: CGFloat, _ y: CGFloat) -> some View {
        // A zero-size anchor at (x, y); the text hangs off it by its baseline, so it never changes the card's layout box.
        Color.clear.frame(width: 0, height: 0)
            .overlay(alignment: .bottomLeading) {
                self.fixedSize().alignmentGuide(.bottom) { $0[.firstTextBaseline] }
            }
            .offset(x: x, y: y)
    }
}

struct JoyCard: View {
    @Environment(Prefs.self) private var prefs
    let tier: CardTier
    var level: Int?
    var radius: CGFloat?
    var compact = false

    var body: some View {
        GeometryReader { g in
            let w = g.size.width
            let u = w / 100
            let tint = tier.tint
            let ink = Color(r: 249, g: 245, b: 236)
            ZStack(alignment: .topLeading) {
                WebImg(name: "vip-cards-\(tier.rawValue).webp")
                    .frame(width: w, height: g.size.height)
                    .clipped()
                LinearGradient(stops: [
                    .init(color: Color(r: 7, g: 9, b: 14, a: 0.68), location: 0),
                    .init(color: Color(r: 7, g: 9, b: 14, a: 0.30), location: 0.55),
                    .init(color: Color(r: 7, g: 9, b: 14, a: 0), location: 1),
                ], startPoint: .leading, endPoint: .trailing)
                RoundedRectangle(cornerRadius: 2.5625 * u)
                    .strokeBorder(tint.opacity(0.5), lineWidth: max(1, 0.125 * u))
                    .frame(width: w - 4.75 * u, height: g.size.height - 4.75 * u)
                    .offset(x: 2.375 * u, y: 2.375 * u)
                Rectangle().fill(tint.opacity(0.6))
                    .frame(width: 25.3125 * u, height: max(1, 0.125 * u))
                    .offset(x: 6.875 * u, y: 48.5625 * u)
                WebImg(name: "vip-cards-emblem.png", mode: .fit)
                    .frame(width: 5.75 * u, height: 5.75 * u)
                    .offset(x: 6.875 * u, y: 6.5 * u)
                Text("SKY").font(.custom("ArialMT", fixedSize: 2.6875 * u)).foregroundColor(ink)
                    .baselineAt(14 * u, 10.625 * u)
                Text(prefs.t("vipJoyCard")).font(.system(size: 7.75 * u)).tracking(0.0775 * u).foregroundColor(ink)
                    .baselineAt(6.75 * u, 28.9375 * u)
                Text(prefs.t("vipTier_\(tier.rawValue)")).font(.system(size: 5.25 * u)).foregroundColor(tint)
                    .baselineAt(6.875 * u, 38.0625 * u)
                Text(tier.en).font(.custom("ArialMT", fixedSize: 2.4375 * u)).tracking(0.04875 * u).foregroundColor(tint)
                    .baselineAt(7.0625 * u, 44.875 * u)
                Text("SKYLINE EXCHANGE").font(.custom("ArialMT", fixedSize: 1.5625 * u)).tracking(0.0625 * u).foregroundColor(ink)
                    .baselineAt(7 * u, 53.8125 * u)
            }
            .overlay(alignment: .topTrailing) {
                if let level {
                    Text(tierName(level, prefs))
                        .font(.custom("Arial-BoldMT", fixedSize: 2.2 * u))
                        .foregroundColor(tint)
                        .padding(.horizontal, 1.6 * u).padding(.vertical, 0.9 * u)
                        .background(Capsule().fill(Color(r: 7, g: 9, b: 14, a: 0.35)))
                        .overlay(Capsule().strokeBorder(tint.opacity(0.55), lineWidth: max(1, 0.12 * u)))
                        .fixedSize()
                        .offset(x: -6.5 * u, y: 10.625 * u - 2.6 * u)
                }
            }
            .frame(width: w, height: g.size.height, alignment: .topLeading)
            .background(Color(hex: 0x0b0b0d))
            .clipShape(RoundedRectangle(cornerRadius: radius ?? 2.6 * u))
        }
        .aspectRatio(16.0 / 10.0, contentMode: .fit)
        .shadow(color: .black.opacity(compact ? 0.45 : 0.55), radius: compact ? 9 : 20, x: 0, y: compact ? 8 : 14)
    }
}
