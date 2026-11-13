import SwiftUI
import PhotosUI

/// Platinum list container (.sx-list).
struct SxList<Content: View>: View {
    @Environment(\.pal) private var pal
    @ViewBuilder var content: () -> Content
    var body: some View {
        VStack(spacing: 0) { content() }
            .background(
                RoundedRectangle(cornerRadius: 14).fill(
                    pal.dark
                        ? LinearGradient(stops: [.init(color: Color(hex: 0x1d2025), location: 0), .init(color: Color(hex: 0x15171b), location: 0.42), .init(color: Color(hex: 0x14161a), location: 1)], startPoint: .top, endPoint: .bottom)
                        : LinearGradient(stops: [.init(color: .white, location: 0), .init(color: Color(hex: 0xfbfaf7), location: 0.55), .init(color: Color(hex: 0xf4f1ea), location: 1)], startPoint: .top, endPoint: .bottom)
                )
            )
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(pal.platLine, lineWidth: 1))
            .shadow(color: pal.dark ? .black.opacity(0.28) : Color(r: 70, g: 60, b: 30, a: 0.08), radius: 9, x: 0, y: 6)
    }
}

/// One settings row (.sx-row): label · value · chevron.
struct SxRow<Trailing: View>: View {
    @Environment(\.pal) private var pal
    let label: String
    var first = false
    var isStatic = false
    var on = false
    var action: (() -> Void)?
    @ViewBuilder var trailing: () -> Trailing

    var body: some View {
        let row = HStack(spacing: 10) {
            Text(label).font(.inter(14.5, .medium)).foregroundColor(on ? pal.gold : pal.ink)
            Spacer(minLength: 6)
            trailing()
            if !isStatic { Icon(.chevronRight, 17).foregroundColor(pal.muted) }
        }
        .padding(.leading, 14).padding(.trailing, 10)
        .frame(minHeight: 50)
        .overlay(alignment: .top) { if !first { Hairline() } }
        .contentShape(Rectangle())
        if let action {
            Button { Haptic.tap(); action() } label: { row }.buttonStyle(PlainTap())
        } else {
            row
        }
    }
}

extension SxRow where Trailing == SxValue {
    init(_ label: String, value: String = "", first: Bool = false, isStatic: Bool = false, action: (() -> Void)? = nil) {
        self.label = label; self.first = first; self.isStatic = isStatic; self.action = action
        self.trailing = { SxValue(text: value) }
    }
}

struct SxValue: View {
    @Environment(\.pal) private var pal
    let text: String
    var body: some View { Text(text).font(.inter(13)).foregroundColor(pal.muted).lineLimit(1) }
}

/// .switch
struct SkySwitch: View {
    @Environment(\.pal) private var pal
    @Binding var on: Bool
    var body: some View {
        Button { on.toggle(); Haptic.tap() } label: {
            ZStack(alignment: on ? .trailing : .leading) {
                Capsule().fill(on ? pal.gold : pal.hover).frame(width: 40, height: 22)
                Circle().fill(.white).frame(width: 16, height: 16).padding(3)
            }
            .animation(.easeOut(duration: 0.15), value: on)
        }
        .buttonStyle(PlainTap())
    }
}

/// pages/Settings.tsx.
struct SettingsPage: View {
    @Environment(Prefs.self) private var prefs
    @Environment(Session.self) private var session
    @Environment(Router.self) private var router
    @Environment(\.pal) private var pal
    @State private var sub: String?
    @State private var toast = ""
    @State private var cacheMB = "…"
    @State private var checking = false

    static let version = "2.0.0"

    var body: some View {
        @Bindable var p = prefs
        let title: String = {
            switch sub {
            case "lang": return prefs.t("language")
            case "profile": return prefs.t("set_profile")
            case "frames": return prefs.t("avatarFrames")
            case "privacy": return prefs.t("set_privacy")
            case "help": return prefs.t("set_help")
            case "about": return prefs.t("set_about")
            default: return prefs.t("set_title")
            }
        }()
        VStack(alignment: .leading, spacing: 0) {
            IconButton(.arrowLeft, size: 24, color: pal.ink2) {
                if sub != nil { sub = nil } else { router.back() }
            }
            .padding(.leading, -8)
            .frame(height: 40)
            .padding(.top, -6).padding(.bottom, 4)
            Text(title).font(.inter(24, .bold)).foregroundColor(pal.ink).padding(.bottom, 2)

            switch sub {
            case nil:
                section(prefs.t("set_general")) {
                    SxRow(label: prefs.t("set_notify"), first: true, isStatic: true) { SkySwitch(on: $p.notifications) }
                    SxRow(prefs.t("currency"), value: "USDT", isStatic: true)
                    SxRow(prefs.t("language"), value: Prefs.langNames[prefs.lang] ?? "") { sub = "lang" }
                    SxRow(label: prefs.t("haptics"), isStatic: true) { SkySwitch(on: $p.haptics) }
                }
                section(prefs.t("set_theme")) {
                    SxRow(prefs.t("set_mode"), value: prefs.t(prefs.dark ? "set_dark" : "set_light"), first: true) { prefs.dark.toggle() }
                    SxRow(label: prefs.t("set_colorConf"), action: { prefs.redUp.toggle() }) {
                        HStack(spacing: 6) {
                            Text("↑").foregroundColor(prefs.redUp ? Color(hex: 0xf0566f) : Color(hex: 0x2ebd85))
                            Text("↓").foregroundColor(prefs.redUp ? Color(hex: 0x2ebd85) : Color(hex: 0xf0566f))
                        }
                        .font(.inter(13, .semibold))
                    }
                    SxRow("\(prefs.t("set_tz"))", value: "\(prefs.t("set_24h")) · UTC+8", isStatic: true)
                }
                section(prefs.t("set_account")) {
                    SxRow(prefs.t("overview"), first: true) { router.go(.assets) }
                    SxRow(prefs.t("futures")) { router.go(.trade("BTCUSDT")) }
                    SxRow(prefs.t("vipTitle")) { router.go(.vip) }
                    SxRow(prefs.t("set_profile")) { sub = "profile" }
                    SxRow(prefs.t("avatarFrames")) { sub = "frames" }
                    SxRow(prefs.t("set_privacy")) { sub = "privacy" }
                }
                section(prefs.t("set_other")) {
                    SxRow(prefs.t("set_clearCache"), value: "\(cacheMB) MB", first: true) { clearCache() }
                    SxRow(prefs.t("set_help")) { sub = "help" }
                    SxRow(prefs.t("set_privacyCenter")) { router.open(.privacy) }
                    SxRow(prefs.t("set_about")) { sub = "about" }
                    SxRow(label: prefs.t("set_update"), action: { Task { await checkUpdate() } }) {
                        HStack(spacing: 6) {
                            Circle().fill(pal.gold).frame(width: 9, height: 9)
                            Text(checking ? prefs.t("set_checking") : SettingsPage.version).font(.inter(13)).foregroundColor(pal.muted)
                        }
                    }
                }
            case "lang":
                SxList {
                    ForEach(Array(Prefs.langs.enumerated()), id: \.offset) { i, l in
                        SxRow(label: Prefs.langNames[l] ?? l, first: i == 0, isStatic: true, on: prefs.lang == l, action: { prefs.lang = l; sub = nil }) {
                            if prefs.lang == l { Icon(.check, 20).foregroundColor(pal.gold) }
                        }
                    }
                }
                .padding(.top, 6)
            case "profile": ProfileSettings().padding(.top, 6)
            case "frames": AvatarFramesView().padding(.top, 6)
            case "privacy": PrivacySettings().padding(.top, 6)
            case "help":
                VStack(alignment: .leading, spacing: 14) {
                    SxList {
                        SxRow(prefs.t("me_support"), value: prefs.t("me_supportTitle"), first: true) { router.go(.community(nil)) }
                        SxRow(prefs.t("privacyNotice")) { router.open(.privacy) }
                    }
                    Text(prefs.t("me_supportBody")).font(.inter(12.5)).foregroundColor(pal.muted).padding(.horizontal, 2)
                }
                .padding(.top, 6)
            default:
                VStack(spacing: 14) {
                    VStack(spacing: 6) {
                        WebImg(name: "brand-sky-logo.webp", mode: .fit).frame(width: 150).padding(.bottom, 6)
                        Text(prefs.t("brandFull")).font(.inter(20, .semibold)).foregroundColor(pal.ink)
                        Text(prefs.t("about_body")).font(.inter(12.5)).foregroundColor(pal.muted).multilineTextAlignment(.center)
                    }
                    .padding(.horizontal, 16).padding(.top, 28).padding(.bottom, 12)
                    SxList {
                        SxRow(prefs.t("about_version"), value: SettingsPage.version, first: true, isStatic: true)
                        SxRow(prefs.t("about_build"), value: Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "1", isStatic: true)
                        SxRow(prefs.t("about_company"), value: "SKY Global", isStatic: true)
                        SxRow(prefs.t("about_founder"), value: "Shinkai.CC", isStatic: true)
                        SxRow(prefs.t("privacyNotice")) { router.open(.privacy) }
                    }
                    Text("© 2026 SKY Global · Skyline Exchange 天际交易所").font(.inter(12.5)).foregroundColor(pal.muted)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
        .toast($toast)
        .onAppear { cacheMB = measureCache() }
    }

    private func section<C: View>(_ title: String, @ViewBuilder _ rows: @escaping () -> C) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(.inter(12.5)).foregroundColor(pal.muted).padding(.top, 16)
            SxList(content: rows)
        }
    }

    private func measureCache() -> String {
        let bytes = URLCache.shared.currentDiskUsage + URLCache.shared.currentMemoryUsage
        return String(format: "%.2f", Double(bytes) / 1_048_576)
    }

    private func clearCache() {
        URLCache.shared.removeAllCachedResponses()
        cacheMB = measureCache()
        toast = prefs.t("set_cleared")
    }

    /// Compares with the latest published build (the app cannot replace itself; the download page opens).
    private func checkUpdate() async {
        guard !checking else { return }
        checking = true
        defer { checking = false }
        guard let r = try? await API.shared.fetch("https://api.github.com/repos/Shinkai08/SKY/releases/latest") else {
            toast = prefs.t("set_offline"); return
        }
        let mine = Int(Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "0") ?? 0
        let latest = Int(r["name"].string.components(separatedBy: CharacterSet.decimalDigits.inverted).filter { !$0.isEmpty }.last ?? "0") ?? 0
        if latest > mine && mine > 1 {
            toast = prefs.t("set_found")
            if let u = URL(string: "https://github.com/Shinkai08/SKY/releases/latest") { await UIApplication.shared.open(u) }
        } else {
            toast = prefs.t("set_latest")
        }
    }
}

// MARK: - profile / frames / privacy

/// /users/{me} for the editors.
@MainActor
@Observable
final class MineModel {
    var j: JSON?
    func reload(_ id: Int?) async {
        guard let id else { return }
        j = try? await API.shared.get("/users/\(id)")
    }
}

struct ProfileSettings: View {
    @Environment(Prefs.self) private var prefs
    @Environment(Session.self) private var session
    @Environment(Router.self) private var router
    @Environment(\.pal) private var pal
    @State private var mine = MineModel()
    @State private var nick = ""
    @State private var bio = ""
    @State private var avatar = ""
    @State private var tags: [String] = []
    @State private var tag = ""
    @State private var busy = false
    @State private var msg = ""
    @State private var pick: PhotosPickerItem?

    static let emoji = ["🐂", "🦊", "🦌", "🐶", "🐱", "🐼", "🐯", "🦁", "🐻", "🐳", "🦅", "🐲", "🚀", "💎", "🌙", "⭐"]

    var body: some View {
        Group {
            if let m = mine.j {
                let photo = m["photo"].string
                VStack(alignment: .leading, spacing: 10) {
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(prefs.t("set_profile")).font(.inter(16, .semibold)).foregroundColor(pal.ink)
                            Text(prefs.t("set_profileDesc")).font(.inter(12.5)).foregroundColor(pal.muted)
                        }
                        Spacer()
                        Button("\(prefs.t("pf_mine")) →") { router.go(.profile(m["id"].int)) }
                            .font(.inter(12.5)).foregroundColor(pal.gold).buttonStyle(PlainTap())
                    }
                    HStack(alignment: .top, spacing: 16) {
                        AvatarView(a: Author(id: m["id"].int, nick: nick.isEmpty ? m["nick"].string : nick, avatar: avatar,
                                             frame: m["frame"].string, photo: photo), size: 84)
                        VStack(alignment: .leading, spacing: 8) {
                            PhotosPicker(selection: $pick, matching: .images) {
                                HStack(spacing: 6) { Icon(.camera, 15); Text(prefs.t("pf_upload")) }
                            }
                            .btn(.gold, .sm).disabled(busy)
                            if !photo.isEmpty {
                                Button { Task { await removePhoto() } } label: {
                                    HStack(spacing: 6) { Icon(.trash2, 14); Text(prefs.t("pf_removePhoto")) }
                                }
                                .btn(.ghost, .sm).disabled(busy)
                            }
                            Text(prefs.t("pf_photoHint")).font(.inter(11.5)).foregroundColor(pal.muted)
                        }
                    }
                    if photo.isEmpty {
                        field(prefs.t("pf_avatar")) {
                            FlowWrap(spacing: 6) {
                                avatarChoice("", label: String((nick.isEmpty ? "?" : nick).prefix(1)).uppercased())
                                ForEach(ProfileSettings.emoji, id: \.self) { e in avatarChoice(e, label: e) }
                            }
                        }
                    }
                    field(prefs.t("pf_nick")) { textBox($nick) }
                    field("\(prefs.t("pf_bio")) \(bio.count)/80") { textBox($bio) }
                    field("\(prefs.t("pf_tags")) \(tags.count)/5") {
                        FlowWrap(spacing: 8) {
                            ForEach(tags, id: \.self) { x in
                                HStack(spacing: 6) {
                                    Text(x)
                                    Button { tags.removeAll { $0 == x } } label: { Icon(.x, 12) }.buttonStyle(PlainTap())
                                }
                                .font(.inter(11.5, .medium)).foregroundColor(pal.gold)
                                .padding(.horizontal, 9).padding(.vertical, 3)
                                .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(pal.gold, lineWidth: 1))
                            }
                            if tags.count < 5 {
                                HStack(spacing: 6) {
                                    TextField("", text: $tag, prompt: Text(prefs.t("pf_tagsHint")).foregroundColor(pal.muted))
                                        .font(.inter(13.5)).frame(width: 150, height: 32)
                                        .padding(.horizontal, 10)
                                        .background(RoundedRectangle(cornerRadius: 8).fill(pal.surface2))
                                        .onSubmit(addTag)
                                    Button(action: addTag) { Icon(.plus, 14) }.btn(.plain, .sm)
                                        .disabled(tag.trimmingCharacters(in: .whitespaces).isEmpty)
                                }
                            }
                        }
                    }
                    if !msg.isEmpty { Text(msg).font(.inter(12.5)).foregroundColor(pal.ink) }
                    Button(prefs.t("pf_save")) { Task { await save() } }.btn(.gold).disabled(busy)
                }
                .card()
            }
        }
        .task {
            await mine.reload(session.me?.id)
            if let m = mine.j {
                nick = m["nick"].string; bio = m["bio"].string; avatar = m["avatar"].string
                tags = m["tags"].array.map { $0.string }
            }
        }
        .onChange(of: pick) { _, item in
            guard let item else { return }
            Task { await upload(item) }
        }
    }

    private func field<C: View>(_ label: String, @ViewBuilder _ c: () -> C) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label).font(.inter(12.5)).foregroundColor(pal.muted)
            c()
        }
    }

    private func textBox(_ b: Binding<String>) -> some View {
        TextField("", text: b).font(.inter(13.5)).foregroundColor(pal.ink)
            .padding(.horizontal, 12).frame(height: 40)
            .background(RoundedRectangle(cornerRadius: 8).fill(pal.surface2))
            .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(pal.line, lineWidth: 1))
    }

    private func avatarChoice(_ value: String, label: String) -> some View {
        Button { avatar = value } label: {
            Text(label).font(.system(size: 17)).foregroundColor(pal.ink)
                .frame(width: 34, height: 34)
                .background(Circle().fill(pal.surface2))
                .overlay(Circle().strokeBorder(avatar == value ? pal.gold : pal.line, lineWidth: 1))
                .background(Circle().stroke(avatar == value ? pal.goldTint : .clear, lineWidth: 4))
        }
        .buttonStyle(PlainTap())
    }

    private func addTag() {
        let v = tag.trimmingCharacters(in: .whitespaces)
        guard !v.isEmpty, v.count <= 10, tags.count < 5, !tags.contains(where: { $0.lowercased() == v.lowercased() }) else { return }
        tags.append(v); tag = ""
    }

    private func fail(_ e: Error) {
        let code = (e as? APIError)?.code ?? "service_unavailable"
        msg = prefs.t("err_\(code)")
    }

    private func save() async {
        busy = true; msg = ""
        defer { busy = false }
        do {
            _ = try await API.shared.post("/me/profile", ["nick": nick, "bio": bio, "avatar": avatar, "tags": tags], method: "PUT")
            await mine.reload(session.me?.id); await session.loadAvatar()
            msg = prefs.t("saved")
        } catch { fail(error) }
    }

    /// Centre-crops to a 512px square JPEG, like the website.
    private func upload(_ item: PhotosPickerItem) async {
        busy = true; msg = ""
        defer { busy = false; pick = nil }
        guard let data = try? await item.loadTransferable(type: Data.self), let img = UIImage(data: data) else {
            msg = prefs.t("err_invalid_photo"); return
        }
        let side = min(img.size.width, img.size.height)
        let out = min(512, side)
        let fmt = UIGraphicsImageRendererFormat(); fmt.scale = 1
        let square = UIGraphicsImageRenderer(size: CGSize(width: out, height: out), format: fmt).image { _ in
            let k = out / side
            img.draw(in: CGRect(x: -(img.size.width - side) / 2 * k, y: -(img.size.height - side) / 2 * k,
                                width: img.size.width * k, height: img.size.height * k))
        }
        guard let jpeg = square.jpegData(compressionQuality: 0.9) else { return }
        do {
            _ = try await API.shared.upload("/me/photo", data: jpeg, contentType: "image/jpeg")
            await mine.reload(session.me?.id); await session.loadAvatar()
            msg = prefs.t("saved")
        } catch { fail(error) }
    }

    private func removePhoto() async {
        busy = true
        defer { busy = false }
        do {
            _ = try await API.shared.post("/me/photo", [:], method: "DELETE")
            await mine.reload(session.me?.id); await session.loadAvatar()
        } catch { fail(error) }
    }
}

struct AvatarFramesView: View {
    @Environment(Prefs.self) private var prefs
    @Environment(Session.self) private var session
    @Environment(Router.self) private var router
    @Environment(\.pal) private var pal
    @State private var draft: String?
    @State private var saving = false
    @State private var notice = ""

    var body: some View {
        let a = session.avatar
        let saved = a?.frame ?? ""
        let frame = draft ?? saved
        let me = Author(id: a?.id ?? 0, nick: a?.nick ?? session.me?.email ?? "SKY", avatar: a?.avatar ?? "", frame: frame, photo: a?.photo ?? "")
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 5) {
                    Text(prefs.t("avatarFrames")).font(.inter(16, .semibold)).foregroundColor(pal.ink)
                    Text(prefs.t("frameDescription")).font(.inter(12.5)).foregroundColor(pal.muted)
                }
                Spacer()
                AvatarView(a: me, size: 78)
            }
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 92), spacing: 6)], spacing: 6) {
                ForEach(["", "orbit", "frost", "jade", "noir", "crown"], id: \.self) { v in
                    Button { draft = v; notice = "" } label: {
                        VStack(spacing: 6) {
                            AvatarView(a: Author(id: me.id, nick: me.nick, avatar: me.avatar, frame: v, photo: me.photo), size: 64)
                            Text(prefs.t("frame_\(v.isEmpty ? "none" : v)")).font(.inter(12)).lineLimit(1)
                        }
                        .foregroundColor(frame == v ? pal.gold : pal.ink)
                        .padding(.vertical, 8).padding(.horizontal, 4)
                        .frame(maxWidth: .infinity)
                        .background(RoundedRectangle(cornerRadius: 12).fill(pal.surface2))
                        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(frame == v ? pal.gold : pal.line, lineWidth: 1))
                    }
                    .buttonStyle(PlainTap())
                }
            }
            .padding(.vertical, 4)
            HStack(spacing: 12) {
                if session.me != nil {
                    Button(prefs.t("saveFrame")) { Task { await save(frame) } }.btn(.gold, .sm).disabled(saving || frame == saved)
                } else {
                    Button(prefs.t("login")) { router.open(.login) }.btn(.gold, .sm)
                }
                if !notice.isEmpty { Text(notice).font(.inter(12.5)).foregroundColor(pal.ink) }
            }
        }
        .card()
    }

    private func save(_ frame: String) async {
        saving = true; notice = ""
        defer { saving = false }
        do {
            _ = try await API.shared.post("/me/avatar-frame", ["frame": frame], method: "PUT")
            await session.loadAvatar()
            draft = nil
            notice = prefs.t("saved")
        } catch { notice = prefs.t("frameSaveFailed") }
    }
}

struct PrivacySettings: View {
    @Environment(Prefs.self) private var prefs
    @Environment(Session.self) private var session
    @Environment(\.pal) private var pal
    @State private var mine = MineModel()
    @State private var busy = false

    var body: some View {
        Group {
            if let m = mine.j {
                let on = m["publicPerf"].bool
                VStack(alignment: .leading, spacing: 0) {
                    Text(prefs.t("set_privacy")).font(.inter(14.5, .semibold)).foregroundColor(pal.ink)
                        .padding(.horizontal, 12).padding(.top, 10).padding(.bottom, 10)
                    Hairline()
                    HStack(spacing: 12) {
                        Icon(on ? .eye : .eyeOff, 20, stroke: 1.6).foregroundColor(pal.muted).frame(width: 20)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(prefs.t("pf_public")).font(.inter(13)).foregroundColor(pal.ink)
                            Text(prefs.t(on ? "set_perfOn" : "set_perfOff")).font(.inter(12.5)).foregroundColor(pal.muted)
                        }
                        Spacer()
                        SkySwitch(on: Binding(get: { on }, set: { _ in Task { await toggle(on) } })).disabled(busy)
                    }
                    .padding(12)
                }
                .card(0)
            }
        }
        .task { await mine.reload(session.me?.id) }
    }

    private func toggle(_ on: Bool) async {
        busy = true
        defer { busy = false }
        _ = try? await API.shared.post("/me/privacy", ["publicPerf": !on], method: "PUT")
        await mine.reload(session.me?.id)
    }
}

/// Fixed-ratio columns (CSS grid "1.15fr 1fr"): each child gets its share of the width.
struct Columns: Layout {
    var ratios: [CGFloat]
    var spacing: CGFloat = 8
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let w = proposal.width ?? 360
        let widths = share(w, subviews.count)
        var h: CGFloat = 0
        for (i, v) in subviews.enumerated() { h = max(h, v.sizeThatFits(ProposedViewSize(width: widths[i], height: nil)).height) }
        return CGSize(width: w, height: h)
    }
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let widths = share(bounds.width, subviews.count)
        var x = bounds.minX
        for (i, v) in subviews.enumerated() {
            v.place(at: CGPoint(x: x, y: bounds.minY), proposal: ProposedViewSize(width: widths[i], height: nil))
            x += widths[i] + spacing
        }
    }
    private func share(_ w: CGFloat, _ n: Int) -> [CGFloat] {
        let r = (0..<n).map { $0 < ratios.count ? ratios[$0] : 1 }
        let total = r.reduce(0, +)
        let avail = max(0, w - spacing * CGFloat(max(0, n - 1)))
        return r.map { avail * $0 / total }
    }
}

/// Wrapping row layout (flex-wrap).
struct FlowWrap: Layout {
    var spacing: CGFloat = 8
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxW = proposal.width ?? .infinity
        var x: CGFloat = 0, y: CGFloat = 0, rowH: CGFloat = 0, widest: CGFloat = 0
        for v in subviews {
            let s = v.sizeThatFits(.unspecified)
            if x > 0 && x + s.width > maxW { x = 0; y += rowH + spacing; rowH = 0 }
            x += s.width + spacing
            rowH = max(rowH, s.height)
            widest = max(widest, x - spacing)
        }
        return CGSize(width: min(maxW, widest), height: y + rowH)
    }
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX, y = bounds.minY, rowH: CGFloat = 0
        for v in subviews {
            let s = v.sizeThatFits(.unspecified)
            if x > bounds.minX && x + s.width > bounds.maxX { x = bounds.minX; y += rowH + spacing; rowH = 0 }
            v.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(s))
            x += s.width + spacing
            rowH = max(rowH, s.height)
        }
    }
}
