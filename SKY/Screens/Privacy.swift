import SwiftUI

/// pages/Privacy.tsx: white document page with a black bar.
struct PrivacyPage: View {
    @Environment(Prefs.self) private var prefs
    @Environment(Router.self) private var router

    private var doc: JSON {
        guard let url = Bundle.main.url(forResource: "privacy", withExtension: "json"),
              let data = try? Data(contentsOf: url) else { return JSON(nil) }
        let all = JSON(data: data)
        let d = all[prefs.langIndex]
        return d.exists ? d : all[0]
    }

    var body: some View {
        let d = doc
        let ink = Color(hex: 0x1e2329), body2 = Color(hex: 0x474d57)
        VStack(spacing: 0) {
            HStack {
                IconButton(.arrowLeft, size: 22, color: .white) { router.coverBack() }.frame(width: 44)
                Spacer()
                Text(d["portal"].string).font(.inter(18, .bold)).foregroundColor(.white).lineLimit(1)
                Spacer()
                Color.clear.frame(width: 44)
            }
            .padding(.horizontal, 8)
            .frame(height: 56)
            .background(Color.black.ignoresSafeArea(edges: .top))
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    PrivacyLock().frame(width: 150, height: 157.5).frame(maxWidth: .infinity).padding(.top, 8).padding(.bottom, 18)
                    Text(d["title"].string).font(.inter(30, .bold)).foregroundColor(ink).frame(maxWidth: .infinity).multilineTextAlignment(.center)
                        .padding(.bottom, 14)
                    Text(d["commitment"].string).font(.inter(18, .semibold)).foregroundColor(Color(hex: 0xb8892f)).padding(.bottom, 14)
                    ForEach(Array(d["intro"].array.enumerated()), id: \.offset) { i, p in
                        Text(p.string).font(.inter(16, i == 0 ? .bold : .regular)).foregroundColor(ink).lineSpacing(11)
                            .padding(.bottom, i == 0 ? 0 : 16)
                    }
                    Text(d["noticeTitle"].string).font(.inter(26, .bold)).foregroundColor(ink).padding(.top, 36).padding(.bottom, 8)
                    VStack(alignment: .leading, spacing: 2) {
                        ForEach(d["meta"].array.indices, id: \.self) { i in Text(d["meta"][i].string) }
                    }
                    .font(.inter(14)).foregroundColor(body2)
                    .padding(.horizontal, 14).padding(.vertical, 12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(RoundedRectangle(cornerRadius: 10).fill(Color(hex: 0xfafafa)))
                    .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(Color(hex: 0xeaecef), lineWidth: 1))
                    ForEach(d["sections"].array.indices, id: \.self) { i in
                        let s = d["sections"][i]
                        VStack(alignment: .leading, spacing: 0) {
                            Text(s["h"].string).font(.inter(19, .bold)).foregroundColor(ink).padding(.bottom, 6)
                            ForEach(s["p"].array.indices, id: \.self) { j in
                                Text(s["p"][j].string).font(.inter(16)).foregroundColor(body2).lineSpacing(11).padding(.bottom, 10)
                            }
                            ForEach(s["list"].array.indices, id: \.self) { j in
                                HStack(alignment: .firstTextBaseline, spacing: 8) {
                                    Text("•")
                                    Text(s["list"][j].string).lineSpacing(11)
                                }
                                .font(.inter(16)).foregroundColor(body2).padding(.leading, 6).padding(.bottom, 8)
                            }
                        }
                        .padding(.top, 26)
                    }
                    VStack(spacing: 0) {
                        Rectangle().fill(Color(hex: 0xeaecef)).frame(height: 1)
                        Text("© 2026 SKY Global · Skyline Exchange 天际交易所").font(.inter(13)).foregroundColor(Color(hex: 0x848e9c))
                            .padding(.top, 16)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, 40)
                }
                .padding(.horizontal, 20).padding(.top, 24).padding(.bottom, 56)
            }
            .background(Color.white)
        }
        .background(Color.white.ignoresSafeArea())
        .preferredColorScheme(.light)
    }
}

/// Gold padlock with the SKY four-point star (200×210 grid).
struct PrivacyLock: View {
    var body: some View {
        Canvas { ctx, s in
            let k = s.width / 200
            ctx.scaleBy(x: k, y: k)
            let gold = Gradient(stops: [.init(color: Color(hex: 0xf3dc9a), location: 0), .init(color: Color(hex: 0xd2a94e), location: 0.6), .init(color: Color(hex: 0xb8892f), location: 1)])
            let ink = Color(hex: 0x14161a)
            var shackle = Path()
            shackle.move(to: CGPoint(x: 52, y: 92))
            shackle.addLine(to: CGPoint(x: 52, y: 66))
            shackle.addArc(center: CGPoint(x: 100, y: 66), radius: 48, startAngle: .degrees(180), endAngle: .degrees(360), clockwise: false)
            shackle.addLine(to: CGPoint(x: 148, y: 92))
            ctx.stroke(shackle, with: .color(ink), style: StrokeStyle(lineWidth: 22, lineCap: .round))
            ctx.stroke(shackle, with: .linearGradient(gold, startPoint: CGPoint(x: 0, y: 18), endPoint: CGPoint(x: 0, y: 92)), style: StrokeStyle(lineWidth: 16, lineCap: .round))
            let base = Path(roundedRect: CGRect(x: 22, y: 88, width: 156, height: 112), cornerRadius: 18)
            ctx.fill(base, with: .linearGradient(gold, startPoint: CGPoint(x: 0, y: 88), endPoint: CGPoint(x: 0, y: 200)))
            ctx.stroke(base, with: .color(ink), lineWidth: 3)
            let face = Path(roundedRect: CGRect(x: 22, y: 88, width: 156, height: 98), cornerRadius: 18)
            ctx.fill(face, with: .linearGradient(Gradient(colors: [.white, Color(hex: 0xf1ece0)]), startPoint: CGPoint(x: 0, y: 88), endPoint: CGPoint(x: 0, y: 186)))
            ctx.stroke(face, with: .color(ink), lineWidth: 3)
            var star = Path()
            star.move(to: CGPoint(x: 100, y: 104))
            star.addCurve(to: CGPoint(x: 136, y: 140), control1: CGPoint(x: 104, y: 128), control2: CGPoint(x: 112, y: 136))
            star.addCurve(to: CGPoint(x: 100, y: 176), control1: CGPoint(x: 112, y: 144), control2: CGPoint(x: 104, y: 152))
            star.addCurve(to: CGPoint(x: 64, y: 140), control1: CGPoint(x: 96, y: 152), control2: CGPoint(x: 88, y: 144))
            star.addCurve(to: CGPoint(x: 100, y: 104), control1: CGPoint(x: 88, y: 136), control2: CGPoint(x: 96, y: 128))
            star.closeSubpath()
            ctx.fill(star, with: .color(ink))
        }
    }
}
