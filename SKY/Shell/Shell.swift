import SwiftUI

/// App.tsx Shell: top bar (not on trading pages), the routed page, the bottom tab bar,
/// full-screen sheet routes and the personal-center drawer.
struct RootView: View {
    @Environment(Prefs.self) private var prefs
    @Environment(Session.self) private var session
    @Environment(Router.self) private var router
    @Environment(\.pal) private var pal

    var body: some View {
        @Bindable var r = router
        ZStack {
            pal.bg.ignoresSafeArea()
            page
                .overlay(alignment: .bottomTrailing) {
                    if case .community = router.route {
                        LuckyLauncher { r.giftOpen = true }.padding(.trailing, 12).padding(.bottom, 4)
                    }
                }
                .safeAreaInset(edge: .top, spacing: 0) {
                    if !router.route.trading { TopBar() }
                }
                .safeAreaInset(edge: .bottom, spacing: 0) { TabBar() }
            if router.meOpen {
                MeDrawer()
                    .transition(.move(edge: .leading))
                    .zIndex(2)
            }
        }
        .animation(.easeOut(duration: 0.25), value: router.meOpen)
        .sheet(isPresented: $r.giftOpen) {
            LuckyGiftSheet()
                .environment(prefs).environment(session).environment(router).environment(\.pal, prefs.pal)
        }
        .fullScreenCover(item: $r.cover) { cover in
            CoverPage(cover: cover)
                .environment(prefs)
                .environment(session)
                .environment(router)
                .environment(\.pal, prefs.pal)
                .preferredColorScheme(prefs.dark ? .dark : .light)
        }
    }

    @ViewBuilder private var page: some View {
        switch router.route {
        case .home: Page { HomePage() }
        case .markets: Page { MarketsPage() }
        case .spot(let sym): SpotPage(sym: sym).id(sym)
        case .trade(let sym): TradePage(sym: sym).id(sym)
        case .assets: Page { AssetsPage() }
        case .settings: Page { SettingsPage() }
        case .vip: Page { VipPage() }
        case .community(let id): Page(bottom: 70) { CommunityPage(initial: id) }
        case .profile(let id): ProfilePage(id: id).id(id)
        case .admin: AdminPage()
        }
    }
}

/// `main.page` on phones: 10px padding, scrolls, back to top on navigation.
struct Page<Content: View>: View {
    @Environment(Router.self) private var router
    var pad: CGFloat = 10
    var bottom: CGFloat = 16
    @ViewBuilder var content: () -> Content

    init(pad: CGFloat = 10, bottom: CGFloat = 16, @ViewBuilder content: @escaping () -> Content) {
        self.pad = pad; self.bottom = bottom; self.content = content
    }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    Color.clear.frame(height: 0).id("top")
                    content()
                }
                .padding(.horizontal, pad)
                .padding(.top, pad)
                .padding(.bottom, bottom)
            }
            .scrollDismissesKeyboard(.interactively)
            .onChange(of: router.serial) { _, _ in proxy.scrollTo("top", anchor: .top) }
        }
    }
}

/// Phone top bar (Nav.tsx TopNav at ≤640px): avatar or logo on the left; search, language and theme on the right.
struct TopBar: View {
    @Environment(Prefs.self) private var prefs
    @Environment(Session.self) private var session
    @Environment(Router.self) private var router
    @Environment(\.pal) private var pal

    var body: some View {
        HStack(spacing: 4) {
            if session.me != nil {
                Button { Haptic.tap(); router.meOpen = true } label: {
                    AvatarView(a: session.face, size: 38)
                }
                .buttonStyle(PlainTap())
            } else {
                Button { router.go(.home) } label: { Logo(size: 28) }
                    .buttonStyle(PlainTap())
            }
            Spacer(minLength: 8)
            IconButton(.search) { router.go(.markets) }
            IconButton(.globe) { router.go(.settings) }
            IconButton(prefs.dark ? .sun : .moon) { prefs.dark.toggle() }
        }
        .padding(.horizontal, 10)
        .frame(height: 48)
        .frame(maxWidth: .infinity)
        .background(pal.surface.ignoresSafeArea(edges: .top))
        .overlay(alignment: .bottom) { Hairline() }
    }
}

/// .icon-btn on phones: 32px tall, 6px padding, 17px icon.
struct IconButton: View {
    @Environment(\.pal) private var pal
    let icon: Lucide
    var size: CGFloat = 17
    var color: Color?
    let action: () -> Void
    init(_ icon: Lucide, size: CGFloat = 17, color: Color? = nil, action: @escaping () -> Void) {
        self.icon = icon; self.size = size; self.color = color; self.action = action
    }
    var body: some View {
        Button { Haptic.tap(); action() } label: {
            Icon(icon, size).foregroundColor(color ?? pal.ink2)
                .padding(.horizontal, 6)
                .frame(height: 32)
        }
        .buttonStyle(PlainTap())
    }
}

struct Logo: View {
    var size: CGFloat = 34
    var body: some View {
        WebImg(name: "logo.png", mode: .fill)
            .frame(width: size, height: size)
            .background(Color.black)
            .clipShape(RoundedRectangle(cornerRadius: 9))
    }
}

/// Bottom tab bar: 首页 / 行情 / 交易 / 合约 / 资产.
struct TabBar: View {
    @Environment(Prefs.self) private var prefs
    @Environment(Router.self) private var router
    @Environment(\.pal) private var pal

    var body: some View {
        let items: [(Lucide, String, Route)] = [
            (.house, prefs.t("home"), .home),
            (.chartNoAxesColumn, prefs.t("markets"), .markets),
            (.arrowLeftRight, prefs.t("tradeNav"), .spot("BTCUSDT")),
            (.chartCandlestick, prefs.t("futuresNav"), .trade("BTCUSDT")),
            (.wallet, prefs.t("assets"), .assets),
        ]
        HStack(spacing: 0) {
            ForEach(0..<items.count, id: \.self) { i in
                let on = router.route.tab == i
                Button {
                    Haptic.tap()
                    router.go(items[i].2)
                } label: {
                    VStack(spacing: 4) {
                        Icon(items[i].0, 25, stroke: 1.75)
                        Text(items[i].1).font(.inter(12, .medium)).lineLimit(1)
                    }
                    .foregroundColor(on ? pal.gold : pal.muted)
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(PlainTap())
            }
        }
        .padding(.top, 9)
        .padding(.bottom, 9)
        .background(
            pal.surface
                .shadow(color: .black.opacity(0.12), radius: 12, x: 0, y: -6)
                .ignoresSafeArea(edges: .bottom)
        )
        .overlay(alignment: .top) {
            Rectangle().fill(pal.platLine).frame(height: 1)
        }
    }
}

/// Full-screen routes (no bars).
struct CoverPage: View {
    let cover: Cover
    var body: some View {
        switch cover {
        case .login: AuthPage(register: false)
        case .register: AuthPage(register: true)
        case .privacy: PrivacyPage()
        case .predict: PredictPage()
        case .games: GamesPage()
        case .crash: CrashPage()
        case .blackjack: BlackjackPage()
        }
    }
}
