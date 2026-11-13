import SwiftUI
import Observation

/// Login state (auth.tsx), the polled /account (useAccount) and the user's own avatar (useOwnAvatar).
@MainActor
@Observable
final class Session {
    var me: Me?
    var ready = false
    var account: Account?
    var avatar: Author?
    var active = true

    @ObservationIgnored private var poller: Task<Void, Never>?

    func boot() async {
        do {
            me = Me(try await API.shared.get("/me"))
        } catch {
            me = nil
        }
        ready = true
        await afterLogin()
    }

    func login(email: String, password: String) async throws {
        me = Me(try await API.shared.post("/auth/login", ["email": email, "password": password]))
        await afterLogin()
    }

    func register(email: String, password: String) async throws {
        me = Me(try await API.shared.post("/auth/register", ["email": email, "password": password]))
        await afterLogin()
    }

    func logout() async {
        _ = try? await API.shared.post("/auth/logout", [:])
        me = nil
        account = nil
        avatar = nil
        poller?.cancel()
    }

    private func afterLogin() async {
        poller?.cancel()
        guard me != nil else { return }
        await refresh()
        await loadAvatar()
        poller = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 1_000_000_000)
                guard let self else { return }
                if self.active && !Demo.on { await self.refresh() }
            }
        }
    }

    func refresh() async {
        guard me != nil else { account = nil; return }
        do {
            account = Account(try await API.shared.get("/account"))
        } catch let e as APIError where e.status == 401 {
            me = nil
            account = nil
        } catch {}
    }

    func loadAvatar() async {
        guard let me else { return }
        if let a = try? await API.shared.get("/me/avatar") {
            let author = Author(a)
            if author.id == me.id { avatar = author }
        }
    }

    /// The identity shown in the top bar and personal center.
    var face: Author {
        if let avatar { return avatar }
        return Author(id: me?.id ?? 0, nick: me?.email ?? "?")
    }

    // MARK: orders

    func place(_ body: [String: Any]) async -> (ok: Bool, reason: String) {
        do {
            let r = try await API.shared.post("/order", body)
            await refresh()
            return (r["ok"].bool, r["reason"].string)
        } catch let e as APIError {
            return (false, e.code)
        } catch {
            return (false, "service_unavailable")
        }
    }

    func cancel(_ id: Int) async {
        _ = try? await API.shared.post("/cancel", ["id": id])
        await refresh()
    }

    func tool(_ path: String, _ body: [String: Any]) async -> (ok: Bool, reason: String) {
        do {
            let r = try await API.shared.post(path, body)
            await refresh()
            return (r["ok"].bool, r["reason"].string)
        } catch let e as APIError {
            return (false, e.status == 404 ? "service_unavailable" : e.code)
        } catch {
            return (false, "service_unavailable")
        }
    }
}

// MARK: - VIP schedule (vip.ts)

struct VipTier {
    var level: Int
    var minAssets: Double
    var minVolSpot: Double, minVolPerp: Double
    var spotMaker: Double, spotTaker: Double, perpMaker: Double, perpTaker: Double
}

enum VIP {
    private static let M = 1e6, B = 1e9
    private static func row(_ l: Int, _ a: Double, _ sv: Double, _ pv: Double, _ sm: Double, _ st: Double, _ pm: Double, _ pt: Double) -> VipTier {
        VipTier(level: l, minAssets: a, minVolSpot: sv, minVolPerp: pv, spotMaker: sm / 100, spotTaker: st / 100, perpMaker: pm / 100, perpTaker: pt / 100)
    }
    static let tiers: [VipTier] = [
        row(0, 0, 0, 0, 0.08, 0.10, 0.02, 0.05),
        row(1, 100_000, 1 * M, 5 * M, 0.0675, 0.08, 0.016, 0.045),
        row(2, 200_000, 5 * M, 10 * M, 0.06, 0.07, 0.015, 0.036),
        row(3, 2 * M, 10 * M, 50 * M, 0.055, 0.065, 0.01, 0.028),
        row(4, 5 * M, 20 * M, 200 * M, 0.03, 0.045, 0.008, 0.027),
        row(5, 20 * M, 100 * M, 600 * M, 0.025, 0.035, 0.005, 0.026),
        row(6, 50 * M, 200 * M, 1 * B, 0, 0.03, 0, 0.025),
        row(7, 100 * M, 500 * M, 1.5 * B, -0.001, 0.023, -0.001, 0.023),
        row(8, 250 * M, 1 * B, 2 * B, -0.0025, 0.02, -0.0025, 0.02),
        row(9, 500 * M, 5 * B, 20 * B, -0.005, 0.015, -0.005, 0.015),
    ]

    static func tierFor(spot: Bool, assets: Double, volume: Double) -> VipTier {
        var t = tiers[0]
        for x in tiers where assets >= x.minAssets || volume >= (spot ? x.minVolSpot : x.minVolPerp) { t = x }
        return t
    }

    static func pct(_ rate: Double) -> String {
        (rate < 0 ? "−" : "") + String(format: "%.4f", abs(rate * 100)) + "%"
    }

    struct Mine {
        var spot: VipTier
        var perp: VipTier
        var level: Int
        var assetsUsd: Double
        var volSpot: Double
        var volPerp: Double
    }

    /// vipOf(): the account's spot and perpetual tiers with the server's rates.
    static func of(_ a: Account?) -> Mine {
        guard let v = a?.vip else {
            let assets = a?.total ?? 0
            let s = tierFor(spot: true, assets: assets, volume: 0)
            let p = tierFor(spot: false, assets: assets, volume: 0)
            return Mine(spot: s, perp: p, level: max(s.level, p.level), assetsUsd: assets, volSpot: 0, volPerp: 0)
        }
        func at(_ l: Int) -> VipTier { tiers[max(0, min(tiers.count - 1, l))] }
        var s = at(v.spot); s.spotMaker = v.spotMaker; s.spotTaker = v.spotTaker
        var p = at(v.perp); p.perpMaker = v.perpMaker; p.perpTaker = v.perpTaker
        return Mine(spot: s, perp: p, level: max(v.spot, v.perp), assetsUsd: v.assets, volSpot: v.vol30Spot, volPerp: v.vol30Perp)
    }

    static func next(_ t: VipTier) -> VipTier? { t.level + 1 < tiers.count ? tiers[t.level + 1] : nil }
}

/// exchange.mmrFor and the isolated liquidation estimate (market/sky.ts).
func mmrFor(_ lev: Double) -> Double { min(0.005, 1 / (2 * max(1, lev))) }
func isolatedLiq(entry: Double, lev: Double, long: Bool) -> Double {
    let mmr = mmrFor(lev)
    return long ? (entry * (1 - 1 / lev)) / (1 - mmr) : (entry * (1 + 1 / lev)) / (1 + mmr)
}
