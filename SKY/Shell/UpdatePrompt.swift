import SwiftUI

/// Update notice published from the admin console (GET /app/version).
@MainActor
@Observable
final class UpdateCenter {
    var notice: JSON?

    static var myBuild: Int { Int(Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "0") ?? 0 }

    /// Called whenever the app is opened or comes back to the foreground.
    func check() async {
        guard let v = try? await API.shared.get("/app/version") else { return }
        if v["enabled"].bool && v["build"].int > UpdateCenter.myBuild && !v["url"].string.isEmpty {
            notice = v
        } else {
            notice = nil
        }
    }
}

/// The popup: title, version, notes, [立即更新] and ✕.
struct UpdatePrompt: View {
    @Environment(Prefs.self) private var prefs
    @Environment(\.pal) private var pal
    @Environment(\.openURL) private var openURL
    let notice: JSON
    let close: () -> Void

    var body: some View {
        ZStack {
            Color(hex: 0x090811, alpha: 0.72).ignoresSafeArea().onTapGesture {}
            VStack(spacing: 14) {
                HStack {
                    Spacer()
                    IconButton(.x, size: 20) { close() }
                }
                .padding(.bottom, -14)
                WebImg(name: "brand-sky-logo.webp", mode: .fit).frame(width: 120)
                Text(prefs.t("app_updateTitle")).font(.inter(20, .bold)).foregroundColor(pal.ink)
                if !notice["version"].string.isEmpty {
                    TierBadge(text: "v\(notice["version"].string)")
                }
                if !notice["notes"].string.isEmpty {
                    Text(notice["notes"].string).font(.inter(13.5)).foregroundColor(pal.ink2).lineSpacing(4)
                        .lineLimit(12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Button {
                    if let u = URL(string: notice["url"].string) { openURL(u) }
                    close()
                } label: {
                    Text(prefs.t("app_updateNow")).font(.inter(16, .bold)).foregroundColor(pal.onGold)
                        .frame(maxWidth: .infinity).frame(height: 48)
                        .background(RoundedRectangle(cornerRadius: 12).fill(pal.goldGrad))
                }
                .buttonStyle(PlainTap())
            }
            .padding(.horizontal, 20).padding(.top, 12).padding(.bottom, 20)
            .background(RoundedRectangle(cornerRadius: 20).fill(pal.surface))
            .overlay(RoundedRectangle(cornerRadius: 20).strokeBorder(pal.platLine, lineWidth: 1))
            .shadow(color: .black.opacity(0.4), radius: 20, x: 0, y: 10)
            .padding(.horizontal, 28)
        }
        .transition(.opacity)
    }
}
