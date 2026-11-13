import SwiftUI
import CoreImage.CIFilterBuiltins

/// What the poster shows (positionPosterImage.ts PosterPosition).
struct PosterPosition {
    var symbol: String
    var perp: Bool
    var side: String
    var leverage: Double
    var pnl: Double
    var roi: Double?
    var entry: Double
    var mark: Double
    var priceDec: Int

    init(perp ps: Position, t: (String) -> String) {
        symbol = ps.sym; perp = true; side = t(ps.long ? "pc_long" : "pc_short"); leverage = ps.lev
        pnl = ps.upnl; roi = ps.margin > 0 ? ps.upnl / ps.margin * 100 : nil
        entry = ps.entry; mark = ps.mark; priceDec = ps.priceDec
    }

    init(spot h: Balance) {
        symbol = h.sym; perp = false; side = ""; leverage = 0
        let cost = h.avgCost * (h.free + h.locked)
        pnl = h.pnl; roi = cost > 0 ? h.pnl / cost * 100 : nil
        entry = h.avgCost; mark = h.mark; priceDec = h.priceDec
    }
}

enum PosterRenderer {
    struct Theme { let accent: UIColor; let font: String?; let roi: String; let status: String }

    static func theme(_ lang: String) -> Theme {
        switch lang {
        case "zh-CN": return Theme(accent: UIColor(Color(hex: 0x865323)), font: "SKYSongSC-Regular", roi: "收益率", status: "持仓中")
        case "zh-TW": return Theme(accent: UIColor(Color(hex: 0x356154)), font: "SKYSongTC-Regular", roi: "報酬率", status: "持有中")
        case "nl": return Theme(accent: UIColor(Color(hex: 0x31596f)), font: nil, roi: "Rendement", status: "Open")
        case "es": return Theme(accent: UIColor(Color(hex: 0x8c4b40)), font: nil, roi: "Rentabilidad", status: "Abierta")
        default: return Theme(accent: UIColor(Color(hex: 0x42546c)), font: nil, roi: "Return", status: "Open")
        }
    }

    static func qr(_ text: String) -> UIImage? {
        let f = CIFilter.qrCodeGenerator()
        f.message = Data(text.utf8)
        f.correctionLevel = "M"
        guard let out = f.outputImage else { return nil }
        let scaled = out.transformed(by: CGAffineTransform(scaleX: 10, y: 10))
        let ctx = CIContext()
        guard let cg = ctx.createCGImage(scaled, from: scaled.extent) else { return nil }
        return UIImage(cgImage: cg)
    }

    /// 1080×1620 poster drawn like the website's canvas.
    static func render(_ p: PosterPosition, nick: String, avatar: String, photo: UIImage?, userId: Int, lang: String,
                       t: (String) -> String, num: (Double, Int) -> String) -> UIImage {
        let th = theme(lang)
        let size = CGSize(width: 1080, height: 1620)
        let fmt = UIGraphicsImageRendererFormat()
        fmt.scale = 1
        return UIGraphicsImageRenderer(size: size, format: fmt).image { _ in
            if let bg = WebImage.load("share-posters-\(lang.lowercased()).webp") {
                bg.draw(in: CGRect(origin: .zero, size: size))
            }
            let ink = UIColor(Color(hex: 0x252628)), muted = UIColor(Color(hex: 0x535453))
            func font(_ name: String?, _ s: CGFloat) -> UIFont {
                if let name, let f = UIFont(name: name, size: s) { return f }
                return UIFont(name: "Georgia", size: s) ?? .systemFont(ofSize: s)
            }
            let headingFont: String? = lang.hasPrefix("zh") ? th.font : "SKYCinzel-Bold"
            /// Text with its baseline at y, shrunk to fit `width` (canvas fillText with maxWidth).
            func text(_ s: String, _ x: CGFloat, _ y: CGFloat, _ sz: CGFloat, _ width: CGFloat, _ color: UIColor = ink,
                      _ name: String? = nil, align: NSTextAlignment = .left) {
                var f = font(name, sz)
                let w0 = (s as NSString).size(withAttributes: [.font: f]).width
                if w0 > width { f = font(name, floor(sz * width / w0)) }
                let attrs: [NSAttributedString.Key: Any] = [.font: f, .foregroundColor: color]
                let w = (s as NSString).size(withAttributes: attrs).width
                let left = align == .right ? x - w : align == .center ? x - w / 2 : x
                (s as NSString).draw(at: CGPoint(x: left, y: y - f.ascender), withAttributes: attrs)
            }
            let signed: (Double, Int) -> String = { v, d in (v < 0 ? "−" : "+") + num(abs(v), d) }
            let fmt = DateFormatter()
            fmt.timeZone = TimeZone(secondsFromGMT: 8 * 3600)
            fmt.dateFormat = "yyyy/MM/dd HH:mm:ss"
            text(fmt.string(from: Date()) + " (UTC+8)", 1004, 103, 23, 480, muted, "ArialMT", align: .right)
            text(p.symbol, 76, 889, 51, 820, ink, headingFont)
            let meta = p.perp ? [p.side, "\(Int(p.leverage))x", th.status, t("perpetual")] : [th.status, t("spotNav")]
            text(meta.filter { !$0.isEmpty }.joined(separator: "  ·  "), 76, 946, 27, 870, muted, th.font)
            text(th.roi, 76, 1019, 29, 720, muted, headingFont)
            let perfColor = p.pnl < 0 ? UIColor(Color(hex: 0xa03045)) : th.accent
            let digits = p.pnl != 0 && abs(p.pnl) < 0.01 ? 4 : 2
            text(p.roi.map { signed($0, 2) + "%" } ?? "—", 71, 1160, 145, 932, perfColor, "Georgia")
            text(signed(p.pnl, digits) + " USDT", 76, 1232, 43, 930, ink, "Georgia")
            text(t(p.perp ? "pc_entry" : "avgCost"), 76, 1351, 26, 420, muted, th.font)
            text(t("pc_mark"), 568, 1351, 26, 420, muted, th.font)
            text(p.entry > 0 ? num(p.entry, p.priceDec) : "—", 76, 1421, 43, 420, ink, th.font)
            text(p.mark > 0 ? num(p.mark, p.priceDec) : "—", 568, 1421, 43, 420, ink, th.font)

            let circle = UIBezierPath(ovalIn: CGRect(x: 77, y: 1479, width: 88, height: 88))
            UIGraphicsGetCurrentContext()?.saveGState()
            circle.addClip()
            UIColor(Color(hex: 0xe6dfd2)).setFill()
            UIRectFill(CGRect(x: 77, y: 1479, width: 88, height: 88))
            if let photo {
                let side = min(photo.size.width, photo.size.height)
                let crop = CGRect(x: (photo.size.width - side) / 2, y: (photo.size.height - side) / 2, width: side, height: side)
                if let cg = photo.cgImage?.cropping(to: crop) { UIImage(cgImage: cg).draw(in: CGRect(x: 77, y: 1479, width: 88, height: 88)) }
            } else {
                let letter = avatar.isEmpty ? String(nick.first.map { String($0) } ?? "S").uppercased() : avatar
                text(letter, 121, 1541, 48, 78, th.accent, nil, align: .center)
            }
            UIGraphicsGetCurrentContext()?.restoreGState()
            text(nick, 192, 1536, 33, 648, ink, th.font)
            UIColor.white.setFill()
            UIRectFill(CGRect(x: 881, y: 1458, width: 124, height: 124))
            if let code = qr("\(API.site.absoluteString)/#/k7bg/\(userId)") {
                let ctx = UIGraphicsGetCurrentContext()
                ctx?.interpolationQuality = .none
                code.draw(in: CGRect(x: 885, y: 1462, width: 116, height: 116))
            }
        }
    }
}

/// The poster dialog: preview, save to Photos, share (PositionPosterButton.tsx).
struct PosterSheet: View {
    @Environment(Prefs.self) private var prefs
    @Environment(Session.self) private var session
    @Environment(\.pal) private var pal
    @Environment(\.dismiss) private var dismiss
    let position: PosterPosition
    @State var image: UIImage?
    @State var failed = false
    @State var saved = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(prefs.t("poster_title")).font(.inter(17, .semibold)).foregroundColor(pal.ink)
                Spacer()
                IconButton(.x, size: 20) { dismiss() }
            }
            if let image {
                Image(uiImage: image).resizable().aspectRatio(2.0 / 3.0, contentMode: .fit)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                Text(saved ? prefs.t("saved") : prefs.t("poster_hint")).font(.inter(12.5)).foregroundColor(pal.muted).frame(maxWidth: .infinity)
                HStack(spacing: 10) {
                    Button {
                        UIImageWriteToSavedPhotosAlbum(image, nil, nil, nil)
                        saved = true
                        Haptic.success()
                    } label: {
                        HStack(spacing: 6) { Icon(.download, 16); Text(prefs.t("poster_download")) }
                    }
                    .btn(.gold, .md, wide: true)
                    ShareLink(item: Image(uiImage: image), preview: SharePreview("SKY", image: Image(uiImage: image))) {
                        HStack(spacing: 6) { Icon(.share, 16); Text(prefs.t("pc_share")) }
                    }
                    .btn(.plain, .md, wide: true)
                }
            } else {
                Text(prefs.t(failed ? "poster_error" : "poster_generating")).font(.inter(13)).foregroundColor(pal.muted)
                    .frame(maxWidth: .infinity, minHeight: 240)
            }
        }
        .padding(16)
        .presentationDetents([.large])
        .presentationCornerRadius(20)
        .presentationBackground(pal.surface)
        .task { await build() }
    }

    private func build() async {
        guard let me = session.me else { failed = true; return }
        var nick = me.email, avatar = "", photo: UIImage?
        if let j = try? await API.shared.get("/users/\(me.id)") {
            let a = j["nick"].string
            if !a.isEmpty { nick = a }
            avatar = j["avatar"].string
            let ph = j["photo"].string
            if ph.hasPrefix("/api/v1/avatars/"), let url = API.asset(ph),
               let res = try? await API.shared.session.data(from: url) {
                photo = UIImage(data: res.0)
            }
        }
        image = PosterRenderer.render(position, nick: nick, avatar: avatar, photo: photo, userId: me.id, lang: prefs.lang,
                                      t: { prefs.t($0) }, num: { prefs.num($0, $1) })
    }
}
