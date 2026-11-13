import SwiftUI

// Temporary pages; each is replaced by its real port.

struct StubPage: View {
    @Environment(\.pal) private var pal
    let name: String
    var body: some View {
        VStack(spacing: 8) {
            Text(name).font(.inter(16, .semibold)).foregroundColor(pal.ink)
            Text("…").foregroundColor(pal.muted)
        }
        .frame(maxWidth: .infinity, minHeight: 300)
    }
}

struct StubCover: View {
    @Environment(Router.self) private var router
    @Environment(\.pal) private var pal
    let name: String
    var body: some View {
        ZStack(alignment: .topTrailing) {
            pal.bg.ignoresSafeArea()
            StubPage(name: name)
            IconButton(.x, size: 20) { router.closeCover() }.padding(12)
        }
    }
}

struct MarketsPage: View { var body: some View { StubPage(name: "Markets") } }
struct SpotPage: View { let sym: String; var body: some View { StubPage(name: "Spot \(sym)") } }
struct TradePage: View { let sym: String; var body: some View { StubPage(name: "Futures \(sym)") } }
struct AssetsPage: View { var body: some View { StubPage(name: "Assets") } }
struct SettingsPage: View { var body: some View { StubPage(name: "Settings") } }
struct VipPage: View { var body: some View { StubPage(name: "VIP") } }
struct CommunityPage: View { let initial: Int?; var body: some View { StubPage(name: "Community") } }
struct ProfilePage: View { let id: Int; var body: some View { StubPage(name: "Profile \(id)") } }
struct AdminPage: View { var body: some View { StubPage(name: "Admin") } }
struct MeDrawer: View {
    @Environment(Router.self) private var router
    @Environment(\.pal) private var pal
    var body: some View {
        ZStack(alignment: .topLeading) {
            pal.bg.ignoresSafeArea()
            StubPage(name: "Me")
            IconButton(.arrowLeft, size: 20) { router.meOpen = false }.padding(12)
        }
    }
}
struct AuthPage: View { let register: Bool; var body: some View { StubCover(name: register ? "Register" : "Login") } }
struct PrivacyPage: View { var body: some View { StubCover(name: "Privacy") } }
struct PredictPage: View { var body: some View { StubCover(name: "Predict") } }
struct GamesPage: View { var body: some View { StubCover(name: "Games") } }
struct CrashPage: View { var body: some View { StubCover(name: "Crash") } }
struct BlackjackPage: View { var body: some View { StubCover(name: "Blackjack") } }
