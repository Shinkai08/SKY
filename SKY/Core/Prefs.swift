import SwiftUI
import Observation

/// User preferences (theme, colours, language, haptics) and the translation table.
/// Mirrors the website's theme.ts and i18n.tsx; stored under the same keys.
@Observable
final class Prefs {
    static let langs = ["en", "nl", "es", "zh-CN", "zh-TW"]
    static let langNames: [String: String] = ["en": "English", "nl": "Nederlands", "es": "Español", "zh-CN": "简体中文", "zh-TW": "繁體中文"]

    var dark: Bool { didSet { save() } }
    var redUp: Bool { didSet { save() } }
    var lang: String { didSet { save() } }
    var haptics: Bool { didSet { save() } }
    var notifications: Bool { didSet { save() } }
    var hideBalance: Bool { didSet { save() } }
    var faceID: Bool { didSet { save() } }

    @ObservationIgnored private var table: [String: [String]] = [:]

    init() {
        let d = UserDefaults.standard
        dark = (d.string(forKey: "sky.theme") ?? "dark") != "light"
        redUp = d.string(forKey: "sky.updown") == "red-up"
        haptics = d.object(forKey: "sky.haptics") as? Bool ?? true
        notifications = d.object(forKey: "sky.notify") as? Bool ?? true
        hideBalance = d.bool(forKey: "sky.hideBalance")
        faceID = d.bool(forKey: "sky.faceid")
        if let saved = d.string(forKey: "sky.lang"), Prefs.langs.contains(saved) {
            lang = saved
        } else {
            let pref = Locale.preferredLanguages.first ?? "en"
            if pref.hasPrefix("zh") {
                lang = (pref.contains("Hant") || pref.contains("TW") || pref.contains("HK")) ? "zh-TW" : "zh-CN"
            } else {
                let short = String(pref.prefix(2))
                lang = Prefs.langs.contains(short) ? short : "en"
            }
        }
        if let url = Bundle.main.url(forResource: "strings", withExtension: "json"),
           let data = try? Data(contentsOf: url),
           let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let strings = obj["strings"] as? [String: [String]] {
            table = strings
        }
        if Demo.on {
            let args = ProcessInfo.processInfo.arguments
            if let i = args.firstIndex(of: "-theme"), i + 1 < args.count { dark = args[i + 1] != "light" }
            if let i = args.firstIndex(of: "-lang"), i + 1 < args.count { lang = args[i + 1] }
        }
    }

    private func save() {
        let d = UserDefaults.standard
        d.set(dark ? "dark" : "light", forKey: "sky.theme")
        d.set(redUp ? "red-up" : "green-up", forKey: "sky.updown")
        d.set(lang, forKey: "sky.lang")
        d.set(haptics, forKey: "sky.haptics")
        d.set(notifications, forKey: "sky.notify")
        d.set(hideBalance, forKey: "sky.hideBalance")
        d.set(faceID, forKey: "sky.faceid")
    }

    var pal: Palette { Palette.make(dark: dark, redUp: redUp) }
    var langIndex: Int { Prefs.langs.firstIndex(of: lang) ?? 0 }
    var isZh: Bool { lang.hasPrefix("zh") }

    /// Translated string; `{name}` placeholders are filled from `vars`.
    func t(_ key: String, _ vars: [String: String] = [:]) -> String {
        var s = key
        if let row = table[key] {
            let i = langIndex
            if i < row.count, !row[i].isEmpty { s = row[i] } else if let first = row.first { s = first }
        }
        if vars.isEmpty { return s }
        for (k, v) in vars { s = s.replacingOccurrences(of: "{\(k)}", with: v) }
        return s
    }

    func has(_ key: String) -> Bool { table[key] != nil }

    /// Grouped number with fixed decimals, like Intl.NumberFormat(lang, { useGrouping: 'always' }).
    func num(_ v: Double, _ digits: Int = 2) -> String { Fmt.num(v, digits, lang: lang) }

    /// "+1,234.50" / "−1,234.50" with the true minus sign, like the site's `signed`.
    func signed(_ v: Double, _ digits: Int = 2, _ suffix: String = "") -> String {
        (v >= 0 ? "+" : "−") + Fmt.num(abs(v), digits, lang: lang) + suffix
    }

    func display(_ size: CGFloat) -> Font { .display(size, lang: lang) }
}

enum Fmt {
    static func num(_ v: Double, _ digits: Int, lang: String) -> String {
        guard v.isFinite else { return "—" }
        let d = max(0, min(12, digits))
        let s = String(format: "%.\(d)f", abs(v))
        let parts = s.split(separator: ".", maxSplits: 1).map(String.init)
        let intPart = parts[0]
        let comma = lang == "nl" || lang == "es"
        let group = comma ? "." : ","
        let dec = comma ? "," : "."
        var grouped = ""
        for (i, ch) in intPart.reversed().enumerated() {
            if i > 0 && i % 3 == 0 { grouped.append(contentsOf: group.reversed()) }
            grouped.append(ch)
        }
        var out = String(grouped.reversed())
        if parts.count > 1 { out += dec + parts[1] }
        let isZero = out.allSatisfy { !$0.isNumber || $0 == "0" }
        return (v < 0 && !isZero ? "-" : "") + out
    }

    /// data.ts compact(): 1.23B / 4.56M / plain.
    static func compact(_ n: Double, _ num: (Double, Int) -> String) -> String {
        if n >= 1e9 { return num(n / 1e9, 2) + "B" }
        if n >= 1e6 { return num(n / 1e6, 2) + "M" }
        return num(n, 2)
    }

    static func priceDigits(_ p: Double) -> Int { p >= 1 ? 2 : 4 }

    /// "+1.23%" chip text (toFixed, ASCII digits, true minus).
    static func pct(_ v: Double, _ digits: Int = 2) -> String {
        (v >= 0 ? "+" : "−") + String(format: "%.\(digits)f", abs(v)) + "%"
    }
}
