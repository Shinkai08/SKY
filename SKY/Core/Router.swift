import SwiftUI
import Observation

/// Pages with the top bar and tab bar (routes.ts), and the full-screen "sheet" routes.
enum Route: Hashable {
    case home, markets, assets, settings, vip, admin
    case spot(String)
    case trade(String)
    case community(Int?)
    case profile(Int)

    /// Trading screens hide the top bar.
    var trading: Bool {
        switch self {
        case .spot, .trade: return true
        default: return false
        }
    }

    var tab: Int {
        switch self {
        case .home: return 0
        case .markets: return 1
        case .spot: return 2
        case .trade: return 3
        case .assets: return 4
        default: return -1
        }
    }
}

enum Cover: Hashable, Identifiable {
    case login, register, privacy, predict, games, crash, blackjack
    var id: Self { self }
}

@MainActor
@Observable
final class Router {
    var route: Route = .home
    var history: [Route] = []
    var cover: Cover?
    var coverHistory: [Cover] = []
    var meOpen = false
    var giftOpen = false
    /// Bumped on every navigation so pages scroll back to the top.
    var serial = 0
    /// One-shot hint for the Me drawer (e.g. open the coupon page).
    var mePage: String?

    init() {
        guard Demo.on else { return }
        switch Demo.arg("-screen") ?? "" {
        case "markets": route = .markets
        case "spot": route = .spot("BTCUSDT")
        case "trade": route = .trade("BTCUSDT")
        case "trade-chart": route = .trade("BTCUSDT")
        case "assets": route = .assets
        case "settings": route = .settings
        case "vip": route = .vip
        case "community": route = .community(nil)
        case "profile": route = .profile(Int(Demo.arg("-id") ?? "") ?? 1000003)
        default: route = .home
        }
        switch Demo.arg("-cover") ?? "" {
        case "login": cover = .login
        case "register": cover = .register
        case "privacy": cover = .privacy
        case "predict": cover = .predict
        case "games": cover = .games
        case "crash": cover = .crash
        case "blackjack": cover = .blackjack
        default: break
        }
        if let page = Demo.arg("-me") { meOpen = true; mePage = page }
    }

    func go(_ r: Route) {
        meOpen = false
        cover = nil
        if r != route {
            history.append(route)
            if history.count > 50 { history.removeFirst() }
            route = r
        }
        serial += 1
    }

    func back() {
        route = history.popLast() ?? .home
        serial += 1
    }

    func open(_ c: Cover) {
        if let current = cover {
            if current != c { coverHistory.append(current) }
        } else {
            coverHistory = []
        }
        cover = c
    }

    /// Back inside the full-screen pages (e.g. Crash → lobby); closes at the first one.
    func coverBack() {
        if let prev = coverHistory.popLast() { cover = prev } else { cover = nil }
    }

    func closeCover() {
        coverHistory = []
        cover = nil
    }
}
