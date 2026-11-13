import SwiftUI
import CoreText

// Design tokens from the website (design/tokens.css), dark and light.

extension Color {
    init(hex: UInt32, alpha: Double = 1) {
        self.init(.sRGB,
                  red: Double((hex >> 16) & 0xff) / 255,
                  green: Double((hex >> 8) & 0xff) / 255,
                  blue: Double(hex & 0xff) / 255,
                  opacity: alpha)
    }
    init(r: Double, g: Double, b: Double, a: Double = 1) {
        self.init(.sRGB, red: r / 255, green: g / 255, blue: b / 255, opacity: a)
    }
}

struct Palette {
    var dark: Bool
    var bg: Color
    var surface: Color
    var surface2: Color
    var hover: Color
    var ink: Color
    var ink2: Color
    var muted: Color
    var line: Color
    var gold: Color
    var goldStrong: Color
    var goldTint: Color
    var onGold: Color
    var green: Color
    var red: Color
    var greenTint: Color
    var redTint: Color

    /// --gold-grad (135deg).
    var goldGrad: LinearGradient {
        LinearGradient(stops: [
            .init(color: Color(hex: 0xf3dc9a), location: 0),
            .init(color: Color(hex: 0xd2a94e), location: 0.55),
            .init(color: Color(hex: 0xb8892f), location: 1),
        ], startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    /// --plat-line: the hairline border of platinum cards and the tab bar.
    var platLine: LinearGradient {
        dark
            ? LinearGradient(stops: [
                .init(color: Color(r: 255, g: 255, b: 255, a: 0.30), location: 0),
                .init(color: Color(r: 255, g: 255, b: 255, a: 0.07), location: 0.38),
                .init(color: Color(r: 217, g: 181, b: 96, a: 0.10), location: 0.70),
                .init(color: Color(r: 217, g: 181, b: 96, a: 0.34), location: 1),
            ], startPoint: .topLeading, endPoint: .bottomTrailing)
            : LinearGradient(stops: [
                .init(color: Color(hex: 0xffffff), location: 0),
                .init(color: Color(hex: 0xdcdad4), location: 0.34),
                .init(color: Color(hex: 0xd8d2c2), location: 0.68),
                .init(color: Color(hex: 0xc9b27a), location: 1),
            ], startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    /// --champagne background (tinted cards).
    var champagne: AnyShapeStyle {
        if dark {
            return AnyShapeStyle(RadialGradient(stops: [
                .init(color: Color(r: 217, g: 181, b: 96, a: 0.18), location: 0),
                .init(color: Color(r: 217, g: 181, b: 96, a: 0.04), location: 0.45),
                .init(color: Color(r: 217, g: 181, b: 96, a: 0), location: 0.70),
            ], center: .topLeading, startRadius: 0, endRadius: 420))
        }
        return AnyShapeStyle(LinearGradient(stops: [
            .init(color: Color(hex: 0xf6f1e6), location: 0),
            .init(color: Color(hex: 0xecdfc6), location: 0.55),
            .init(color: Color(hex: 0xf8f5ee), location: 1),
        ], startPoint: .topLeading, endPoint: .bottomTrailing))
    }

    func dir(_ v: Double) -> Color { v >= 0 ? green : red }
    func dirTint(_ v: Double) -> Color { v >= 0 ? greenTint : redTint }

    static func make(dark: Bool, redUp: Bool) -> Palette {
        var p = dark
            ? Palette(dark: true, bg: Color(hex: 0x0b0c0e), surface: Color(hex: 0x14161a), surface2: Color(hex: 0x1b1e23),
                      hover: Color(hex: 0x22262c), ink: Color(hex: 0xedebe6), ink2: Color(hex: 0xc3c2bd), muted: Color(hex: 0x858891),
                      line: Color(hex: 0x262a30), gold: Color(hex: 0xd9b560), goldStrong: Color(hex: 0xf0d48a),
                      goldTint: Color(r: 217, g: 181, b: 96, a: 0.13), onGold: Color(hex: 0x1a1508),
                      green: Color(hex: 0x2ebd85), red: Color(hex: 0xf0566f),
                      greenTint: Color(r: 46, g: 189, b: 133, a: 0.14), redTint: Color(r: 240, g: 86, b: 111, a: 0.14))
            : Palette(dark: false, bg: Color(hex: 0xf6f5f2), surface: Color(hex: 0xffffff), surface2: Color(hex: 0xf3f1ec),
                      hover: Color(hex: 0xefece5), ink: Color(hex: 0x181c20), ink2: Color(hex: 0x3c4046), muted: Color(hex: 0x737672),
                      line: Color(hex: 0xe7e4dd), gold: Color(hex: 0xa67c2a), goldStrong: Color(hex: 0x8c6820),
                      goldTint: Color(hex: 0xf3ecdd), onGold: Color(hex: 0x1a1508),
                      green: Color(hex: 0x1f8f6b), red: Color(hex: 0xd04a5c),
                      greenTint: Color(hex: 0xe8f4ee), redTint: Color(hex: 0xfaecee))
        if redUp {
            // tokens.css :root[data-updown="red-up"]
            p.green = Color(hex: 0xf0566f); p.red = Color(hex: 0x2ebd85)
            p.greenTint = Color(r: 240, g: 86, b: 111, a: 0.14); p.redTint = Color(r: 46, g: 189, b: 133, a: 0.14)
        }
        return p
    }
}

private struct PaletteKey: EnvironmentKey {
    static let defaultValue = Palette.make(dark: true, redUp: false)
}

extension EnvironmentValues {
    var pal: Palette {
        get { self[PaletteKey.self] }
        set { self[PaletteKey.self] = newValue }
    }
}

// MARK: - Fonts (static instances cut by scripts/build-fonts.py)

enum SkyFonts {
    static func register() {
        guard let dir = Bundle.main.url(forResource: "Fonts", withExtension: nil),
              let files = try? FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil) else { return }
        for url in files where ["ttf", "otf"].contains(url.pathExtension.lowercased()) {
            CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
        }
    }
}

extension Font {
    /// Inter, the website's interface and number face (CJK falls back to PingFang like the site).
    static func inter(_ size: CGFloat, _ weight: Font.Weight = .regular) -> Font {
        let name: String
        switch weight {
        case .bold, .heavy, .black: name = "SKYInter-Bold"
        case .semibold: name = "SKYInter-SemiBold"
        case .medium: name = "SKYInter-Medium"
        default: name = "SKYInter-Regular"
        }
        return .custom(name, fixedSize: size)
    }

    /// The "SKY" word mark (Cinzel Bold).
    static func cinzel(_ size: CGFloat) -> Font { .custom("SKYCinzel-Bold", fixedSize: size) }

    /// `.display` headings: Song for Chinese, Cormorant for Spanish, Inter semibold otherwise.
    static func display(_ size: CGFloat, lang: String) -> Font {
        switch lang {
        case "zh-CN": return .custom("SKYSongSC-Regular", fixedSize: size)
        case "zh-TW": return .custom("SKYSongTC-Regular", fixedSize: size)
        case "es": return .custom("SKYCormorant-Regular", fixedSize: size)
        default: return .inter(size, .semibold)
        }
    }
}

// MARK: - Images bundled from the website's public/ folder

enum WebImage {
    private static var cache: [String: UIImage] = [:]
    /// `name` is the public/ path with slashes replaced by dashes, e.g. "vip-cards-gold.webp".
    static func load(_ name: String) -> UIImage? {
        if let hit = cache[name] { return hit }
        guard let url = Bundle.main.url(forResource: name, withExtension: nil, subdirectory: "Web"),
              let img = UIImage(contentsOfFile: url.path) else { return nil }
        cache[name] = img
        return img
    }
}

struct WebImg: View {
    let name: String
    var mode: ContentMode = .fill
    var body: some View {
        if let img = WebImage.load(name) {
            Image(uiImage: img).resizable().aspectRatio(contentMode: mode)
        } else {
            Color.clear
        }
    }
}
