import SwiftUI

/// pages/Community.tsx (phone: the open thread sits above the feed).
struct CommunityPage: View {
    @Environment(Prefs.self) private var prefs
    @Environment(Session.self) private var session
    @Environment(Router.self) private var router
    @Environment(\.pal) private var pal
    let initial: Int?
    @State var topic = "all"
    @State var posts: [JSON]?
    @State var threadID: Int?
    @State var thread: JSON?
    @State var compose = false
    @State var title = ""
    @State var text = ""
    @State var draftTopic = "general"
    @State var reply = ""
    @State var busy = false
    @State var issue = ""
    @State var loadIssue = false
    @State var revision = 0
    @State var giftOpen = false

    static let topics = ["general", "market", "developer", "feedback"]

    private func topicName(_ v: String) -> String { prefs.t(v == "all" ? "sub_all" : "topic_\(v)") }

    var body: some View {
        let active: JSON? = thread?["id"].int == threadID && threadID != nil ? thread : nil
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(prefs.t("community")).font(prefs.display(19)).foregroundColor(pal.ink)
                Spacer()
                if session.me != nil {
                    Button { compose.toggle(); issue = "" } label: {
                        HStack(spacing: 6) { Icon(.messageSquarePlus, 17); Text(prefs.t("newDiscussion")) }
                    }
                    .btn(.gold)
                } else {
                    Button(prefs.t("login")) { router.open(.login) }.btn(.gold)
                }
            }
            if compose { composer }
            if !issue.isEmpty { Text(prefs.t("err_\(issue)")).font(.inter(12.5)).foregroundColor(pal.ink) }
            if let active { threadCard(active) }
            feed
        }
        .padding(.bottom, 60)
        .onAppear { if let initial { threadID = initial } }
        .task(id: "\(topic)|\(revision)") {
            while !Task.isCancelled {
                do {
                    posts = try await API.shared.get("/community\(topic == "all" ? "" : "?topic=\(topic)")").array
                    loadIssue = false
                } catch { loadIssue = true }
                try? await Task.sleep(nanoseconds: 10_000_000_000)
            }
        }
        .task(id: "\(threadID ?? 0)|\(revision)") {
            guard let id = threadID else { return }
            while !Task.isCancelled {
                do { thread = try await API.shared.get("/community/\(id)") } catch { issue = (error as? APIError)?.code ?? "service_unavailable" }
                try? await Task.sleep(nanoseconds: 5_000_000_000)
            }
        }
    }

    private var composer: some View {
        VStack(alignment: .leading, spacing: 10) {
            field(prefs.t("discussionTitle")) {
                TextField("", text: $title).font(.inter(13.5)).foregroundColor(pal.ink).padding(.horizontal, 12).frame(height: 40)
                    .background(RoundedRectangle(cornerRadius: 8).fill(pal.surface2))
                    .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(pal.line, lineWidth: 1))
            }
            field(prefs.t("category")) {
                Menu {
                    ForEach(CommunityPage.topics, id: \.self) { v in Button(topicName(v)) { draftTopic = v } }
                } label: {
                    HStack { Text(topicName(draftTopic)); Spacer(); Icon(.chevronDown, 14) }
                        .font(.inter(13)).foregroundColor(pal.ink)
                        .padding(.horizontal, 10).frame(height: 32)
                        .background(RoundedRectangle(cornerRadius: 8).fill(pal.surface2))
                        .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(pal.line, lineWidth: 1))
                }
            }
            field(prefs.t("discussionBody")) {
                TextEditor(text: $text).font(.inter(13.5)).foregroundColor(pal.ink).scrollContentBackground(.hidden)
                    .frame(minHeight: 96).padding(.horizontal, 8).padding(.vertical, 4)
                    .background(RoundedRectangle(cornerRadius: 8).fill(pal.surface2))
                    .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(pal.line, lineWidth: 1))
            }
            HStack(spacing: 10) {
                Button(prefs.t("publishDiscussion")) { Task { await publish() } }
                    .btn(.gold, .sm).disabled(busy || title.trimmingCharacters(in: .whitespaces).isEmpty || text.trimmingCharacters(in: .whitespaces).isEmpty)
                Button(prefs.t("closeComposer")) { compose = false }.btn(.plain, .sm)
            }
        }
        .card()
    }

    private func field<C: View>(_ label: String, @ViewBuilder _ c: () -> C) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label).font(.inter(12.5)).foregroundColor(pal.muted)
            c()
        }
    }

    private var feed: some View {
        VStack(alignment: .leading, spacing: 0) {
            ScrollView(.horizontal, showsIndicators: false) {
                Tabs(items: (["all"] + CommunityPage.topics).map { ($0, topicName($0)) }, value: $topic)
            }
            ForEach(Array((posts ?? []).enumerated()), id: \.offset) { _, post in
                let a = authorFrom(post["authorInfo"], fallbackId: post["author"].int)
                Button { threadID = post["id"].int; issue = ""; reply = "" } label: {
                    HStack(alignment: .top, spacing: 10) {
                        HStack(alignment: .top, spacing: 10) {
                            AvatarView(a: a, size: 34)
                            VStack(alignment: .leading, spacing: 4) {
                                Text(post["title"].string).font(.inter(13, .semibold)).foregroundColor(pal.ink).multilineTextAlignment(.leading)
                                HStack(spacing: 4) {
                                    Text(a.nick)
                                    if a.verified { VerifiedMark(size: 12) }
                                    if a.ai { AIBadge(small: true) }
                                    Text("· \(topicName(post["topic"].string))")
                                    if post["card"].exists {
                                        let r = post["card"]["ret"].double
                                        Text(" · \(r >= 0 ? "+" : "")\(String(format: "%.2f", r))%").foregroundColor(pal.dir(r))
                                    }
                                }
                                .font(.inter(11.5)).foregroundColor(pal.muted).lineLimit(1)
                            }
                        }
                        Spacer(minLength: 4)
                        HStack(spacing: 6) {
                            Icon(.heart, 14); Text("\(post["likes"].int)")
                            Icon(.messageCircle, 15); Text("\(post["replyCount"].int)")
                        }
                        .font(.inter(12.5)).foregroundColor(pal.muted)
                    }
                    .padding(.horizontal, 4).padding(.vertical, 10)
                    .background(threadID == post["id"].int ? pal.hover : .clear)
                    .overlay(alignment: .bottom) { Hairline() }
                }
                .buttonStyle(PlainTap())
            }
            if (posts ?? []).isEmpty {
                EmptyNote(text: prefs.t(loadIssue ? "err_service_unavailable" : posts != nil ? "communityEmpty" : "connecting"))
            }
        }
        .card()
    }

    private func threadCard(_ t: JSON) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Button { threadID = nil; thread = nil } label: {
                HStack(spacing: 6) { Icon(.arrowLeft, 15); Text(prefs.t("community")) }
            }
            .btn(.plain, .sm)
            VStack(alignment: .leading, spacing: 0) {
                TierBadge(text: topicName(t["topic"].string))
                Text(t["title"].string).font(.inter(16, .semibold)).foregroundColor(pal.ink).padding(.top, 10).padding(.bottom, 4)
                AuthorLine(a: authorFrom(t["authorInfo"], fallbackId: t["author"].int), id: t["author"].int, sub: "· \(localDate(t["created"].string))")
            }
            Text(t["body"].string).font(.inter(13)).foregroundColor(pal.ink).textSelection(.enabled)
            if t["card"].exists { PnlCardView(c: t["card"]) }
            Button { Task { await like(t["id"].int) } } label: {
                HStack(spacing: 6) { Icon(.heart, 16, filled: t["liked"].bool); Text("\(t["likes"].int)") }
                    .font(.inter(13)).foregroundColor(t["liked"].bool ? pal.red : pal.muted)
            }
            .buttonStyle(PlainTap())
            Text("\(prefs.t("discussionReplies")) · \(t["replyCount"].int)").font(.inter(14.5, .semibold)).foregroundColor(pal.ink).padding(.top, 4)
            ForEach(Array(t["replies"].array.enumerated()), id: \.offset) { _, r in
                VStack(alignment: .leading, spacing: 0) {
                    Hairline()
                    AuthorLine(a: authorFrom(r["authorInfo"], fallbackId: r["author"].int), id: r["author"].int, sub: "· \(localDate(r["created"].string))")
                    Text(r["body"].string).font(.inter(13)).foregroundColor(pal.ink).padding(.bottom, 10)
                }
            }
            if session.me != nil {
                field(prefs.t("writeReply")) {
                    TextEditor(text: $reply).font(.inter(13.5)).foregroundColor(pal.ink).scrollContentBackground(.hidden)
                        .frame(minHeight: 72).padding(.horizontal, 8).padding(.vertical, 4)
                        .background(RoundedRectangle(cornerRadius: 8).fill(pal.surface2))
                        .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(pal.line, lineWidth: 1))
                }
                Button(prefs.t("writeReply")) { Task { await sendReply(t["id"].int) } }
                    .btn(.gold, .sm).disabled(busy || reply.trimmingCharacters(in: .whitespaces).isEmpty)
            } else {
                Button(prefs.t("login")) { router.open(.login) }.foregroundColor(pal.gold).buttonStyle(PlainTap())
            }
        }
        .card()
    }

    private func like(_ id: Int) async {
        guard session.me != nil else { router.open(.login); return }
        _ = try? await API.shared.post("/community/\(id)/like", [:])
        revision += 1
    }

    private func publish() async {
        busy = true; issue = ""
        defer { busy = false }
        do {
            let post = try await API.shared.post("/community", ["title": title, "body": text, "topic": draftTopic])
            title = ""; text = ""
            topic = "all"
            thread = post; threadID = post["id"].int
            compose = false
            revision += 1
        } catch { issue = (error as? APIError)?.code ?? "service_unavailable" }
    }

    private func sendReply(_ id: Int) async {
        busy = true; issue = ""
        defer { busy = false }
        do {
            _ = try await API.shared.post("/community/\(id)/replies", ["body": reply])
            reply = ""
            revision += 1
        } catch { issue = (error as? APIError)?.code ?? "service_unavailable" }
    }
}

// MARK: - 社区福袋 (LuckyGift.tsx)

/// The red pouch with 福.
struct Pouch: View {
    var size: CGFloat = 52
    var body: some View {
        let s = size
        ZStack(alignment: .topLeading) {
            // mouth
            PouchMouth()
                .fill(LinearGradient(colors: [Color(hex: 0xff7a7d), Color(hex: 0xd82438)], startPoint: .topLeading, endPoint: .bottomTrailing))
                .frame(width: s * 0.46, height: s * 0.32)
                .offset(x: s * 0.27, y: s * 0.05)
            // body
            UnevenRoundedRectangle(topLeadingRadius: s * 0.8 * 0.46, bottomLeadingRadius: s * 0.8 * 0.29,
                                   bottomTrailingRadius: s * 0.8 * 0.29, topTrailingRadius: s * 0.8 * 0.46)
                .fill(RadialGradient(stops: [.init(color: Color(hex: 0xff6976), location: 0), .init(color: Color(hex: 0xdb2339), location: 0.52),
                                             .init(color: Color(hex: 0x9d152a), location: 1)],
                                     center: UnitPoint(x: 0.35, y: 0.23), startRadius: 0, endRadius: s * 0.6))
                .overlay(
                    UnevenRoundedRectangle(topLeadingRadius: s * 0.8 * 0.46, bottomLeadingRadius: s * 0.8 * 0.29,
                                           bottomTrailingRadius: s * 0.8 * 0.29, topTrailingRadius: s * 0.8 * 0.46)
                        .strokeBorder(Color(hex: 0xffb364), lineWidth: 1)
                )
                .overlay(
                    Text("福").font(.system(size: s * 0.37, weight: .heavy)).foregroundColor(Color(hex: 0xffdf87))
                        .shadow(color: Color(hex: 0x8e3514), radius: 0, x: 0, y: 2)
                )
                .frame(width: s * 0.8, height: s * 0.70)
                .offset(x: s * 0.10, y: s * 0.27)
            // cord
            Capsule().fill(Color(hex: 0xffd877))
                .frame(width: s * 0.48, height: s * 0.05)
                .shadow(color: Color(hex: 0x7d1d1b), radius: 1.5, x: 0, y: 1)
                .offset(x: s * 0.26, y: s * 0.30)
        }
        .frame(width: s, height: s, alignment: .topLeading)
    }
}

struct PouchMouth: Shape {
    func path(in r: CGRect) -> Path {
        Path { p in
            p.move(to: CGPoint(x: 0, y: r.height * 0.04)); p.addLine(to: CGPoint(x: r.width, y: r.height * 0.04))
            p.addLine(to: CGPoint(x: r.width * 0.76, y: r.height)); p.addLine(to: CGPoint(x: r.width * 0.24, y: r.height))
            p.closeSubpath()
        }
    }
}

struct LuckyLauncher: View {
    @Environment(Prefs.self) private var prefs
    let action: () -> Void
    @State var bob = false
    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Pouch(size: 52).offset(y: bob ? -3 : 3)
                Text(prefs.t("luckyGift")).font(.inter(12, .bold)).foregroundColor(Color(hex: 0xffe1a1))
            }
            .padding(.horizontal, 9).padding(.top, 8).padding(.bottom, 7)
            .background(RoundedRectangle(cornerRadius: 20).fill(Color(hex: 0x39111b)))
            .overlay(RoundedRectangle(cornerRadius: 20).strokeBorder(Color(hex: 0xb66b49), lineWidth: 1))
            .shadow(color: .black.opacity(0.33), radius: 13, x: 0, y: 8)
        }
        .buttonStyle(PlainTap())
        .onAppear { withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) { bob = true } }
    }
}

struct LuckyGiftSheet: View {
    @Environment(Prefs.self) private var prefs
    @Environment(Session.self) private var session
    @Environment(Router.self) private var router
    @Environment(\.dismiss) private var dismiss
    @State var gift: JSON?
    @State var opening = false
    @State var issue = ""

    var body: some View {
        let enabled = gift?["enabled"].bool ?? false
        let claimed = gift?["claimed"].bool ?? false
        VStack(spacing: 10) {
            HStack {
                Spacer()
                Button { dismiss() } label: {
                    Icon(.x, 18).foregroundColor(Color(hex: 0xfff4d9)).frame(width: 34, height: 34).background(Circle().fill(Color(hex: 0x17050b, alpha: 0.33)))
                }
                .buttonStyle(PlainTap())
            }
            Pouch(size: 98).rotationEffect(.degrees(opening ? 8 : 0)).animation(.easeInOut(duration: 0.1).repeatCount(4, autoreverses: true), value: opening)
            Text(prefs.t("luckyGift")).font(.inter(16, .semibold)).foregroundColor(Color(hex: 0xfff1d8))
            if enabled {
                (Text("\(prefs.num(gift?["amount"].double ?? 0, 0)) ").font(.inter(36, .bold)) + Text("USDT").font(.inter(14, .bold)))
                    .foregroundColor(Color(hex: 0xffde89))
            }
            Text(prefs.t(claimed ? "giftReceived" : "giftRules")).font(.inter(12.5)).foregroundColor(Color(hex: 0xfff1d8)).multilineTextAlignment(.center)
            if session.me == nil {
                Button(prefs.t("login")) { dismiss(); router.open(.login) }.btn(.gold)
            } else if claimed {
                Button { dismiss(); router.go(.assets) } label: { HStack(spacing: 6) { Icon(.check, 16); Text(prefs.t("assets")) } }.btn(.gold)
            } else {
                Button(prefs.t(opening ? "giftOpening" : "giftClaim")) { Task { await claim() } }.btn(.gold).disabled(!enabled || opening)
            }
            if !issue.isEmpty { Text(prefs.t(issue)).font(.inter(12.5)).foregroundColor(Color(hex: 0xfff1d8)) }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 18).padding(.top, 8).padding(.bottom, 24)
        .frame(maxWidth: .infinity)
        .background(RadialGradient(stops: [.init(color: Color(hex: 0x9a3340), location: 0), .init(color: Color(hex: 0x5e1d2b), location: 0.54),
                                           .init(color: Color(hex: 0x361521), location: 1)], center: UnitPoint(x: 0.5, y: 0.1), startRadius: 0, endRadius: 420))
        .presentationDetents([.medium])
        .presentationCornerRadius(24)
        .task { if session.me != nil { gift = try? await API.shared.get("/welcome-gift") } }
    }

    private func claim() async {
        guard gift?["enabled"].bool == true, gift?["claimed"].bool != true, !opening else { return }
        opening = true; issue = ""
        defer { opening = false }
        do {
            async let r = API.shared.post("/welcome-gift/claim", [:])
            try? await Task.sleep(nanoseconds: 440_000_000)
            let res = try await r
            gift = JSON(["enabled": true, "claimed": res["claimed"].bool, "amount": res["amount"].double])
            Haptic.success()
        } catch {
            issue = (error as? APIError)?.code == "account_frozen" ? "err_account_frozen" : "giftClaimFailed"
        }
    }
}
