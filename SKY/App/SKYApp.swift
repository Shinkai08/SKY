import SwiftUI

@main
struct SKYApp: App {
    @State private var prefs = Prefs()
    @State private var session = Session()
    @State private var router = Router()
    @State private var updates = UpdateCenter()
    @Environment(\.scenePhase) private var phase

    init() {
        SkyFonts.register()
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(prefs)
                .environment(session)
                .environment(router)
                .environment(\.pal, prefs.pal)
                .overlay {
                    if let n = updates.notice {
                        UpdatePrompt(notice: n) { withAnimation { updates.notice = nil } }
                            .environment(prefs)
                            .environment(\.pal, prefs.pal)
                    }
                }
                .animation(.easeOut(duration: 0.2), value: updates.notice == nil)
                .preferredColorScheme(prefs.dark ? .dark : .light)
                .environment(\.locale, Locale(identifier: prefs.lang))
                .task {
                    Haptic.enabled = prefs.haptics && !Demo.on
                    await session.boot()
                    await updates.check()
                }
                .onChange(of: prefs.haptics) { _, on in Haptic.enabled = on }
                .onChange(of: phase) { _, p in
                    session.active = p != .background
                    if p == .active { Task { await updates.check() } }
                }
        }
    }
}
