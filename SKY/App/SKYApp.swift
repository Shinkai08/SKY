import SwiftUI

@main
struct SKYApp: App {
    @State private var prefs = Prefs()
    @State private var session = Session()
    @State private var router = Router()
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
                .preferredColorScheme(prefs.dark ? .dark : .light)
                .environment(\.locale, Locale(identifier: prefs.lang))
                .task {
                    Haptic.enabled = prefs.haptics && !Demo.on
                    await session.boot()
                }
                .onChange(of: prefs.haptics) { _, on in Haptic.enabled = on }
                .onChange(of: phase) { _, p in session.active = p != .background }
        }
    }
}
