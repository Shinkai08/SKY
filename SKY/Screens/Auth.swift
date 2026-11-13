import SwiftUI

/// pages/AuthPage.tsx: full-screen black sheet.
struct AuthPage: View {
    @Environment(Prefs.self) private var prefs
    @Environment(Session.self) private var session
    @Environment(Router.self) private var router
    @Environment(\.pal) private var pal
    let register: Bool
    @State var email = ""
    @State var password = ""
    @State var show = false
    @State var agree = false
    @State var busy = false
    @State var err = ""
    @State var note = ""
    @FocusState var focus: Int?

    var body: some View {
        let reg = register
        let canSubmit = !busy && !email.isEmpty && !password.isEmpty && (!reg || agree)
        ZStack {
            Color.black.ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    HStack(spacing: 6) {
                        Spacer()
                        IconButton(.headset, size: 22, color: Color(hex: 0xf5f3ee)) { router.closeCover(); router.go(.community(nil)) }
                        IconButton(.x, size: 24, color: Color(hex: 0xf5f3ee)) { router.closeCover() }
                    }
                    .padding(.top, 14).padding(.horizontal, -6)
                    WebImg(name: "brand-sky-logo.webp", mode: .fit)
                        .frame(width: min(UIScreen.main.bounds.width * 0.64, 260))
                        .frame(maxWidth: .infinity)
                        .padding(.top, -4).padding(.bottom, 4)
                    Text(reg ? prefs.t("authWelcome") : prefs.t("authWelcomeBack"))
                        .font(.inter(27, .bold)).foregroundColor(.white)
                    field(prefs.t("email")) {
                        TextField("", text: $email, prompt: Text(prefs.t("emailPh")).foregroundColor(Color(hex: 0x6f727b)))
                            .keyboardType(.emailAddress).textContentType(.emailAddress)
                            .textInputAutocapitalization(.never).autocorrectionDisabled()
                            .focused($focus, equals: 0)
                            .onChange(of: email) { _, v in let t = v.trimmingCharacters(in: .whitespaces); if t != v { email = t } }
                    }
                    field(prefs.t("password")) {
                        HStack {
                            Group {
                                if show {
                                    TextField("", text: $password, prompt: Text(reg ? prefs.t("passwordHint") : prefs.t("passwordPh")).foregroundColor(Color(hex: 0x6f727b)))
                                } else {
                                    SecureField("", text: $password, prompt: Text(reg ? prefs.t("passwordHint") : prefs.t("passwordPh")).foregroundColor(Color(hex: 0x6f727b)))
                                }
                            }
                            .textContentType(reg ? .newPassword : .password)
                            .textInputAutocapitalization(.never).autocorrectionDisabled()
                            .focused($focus, equals: 1)
                            Button { show.toggle() } label: { Icon(show ? .eyeOff : .eye, 18).foregroundColor(Color(hex: 0xa7a9b0)) }
                                .buttonStyle(PlainTap())
                        }
                    }
                    if reg {
                        Button { agree.toggle() } label: {
                            HStack(alignment: .top, spacing: 10) {
                                ZStack {
                                    RoundedRectangle(cornerRadius: 5).fill(agree ? pal.gold : .clear)
                                    RoundedRectangle(cornerRadius: 5).strokeBorder(agree ? pal.gold : Color(hex: 0x8b8e96), lineWidth: 1.5)
                                    if agree { Icon(.check, 14, stroke: 3).foregroundColor(Color(hex: 0x1a1508)) }
                                }
                                .frame(width: 20, height: 20).padding(.top, 2)
                                (Text(prefs.t("agreePrefix")) + Text(prefs.t("privacyNotice")).underline(pattern: .dot) + Text(prefs.t("agreeSuffix")))
                                    .font(.inter(15)).foregroundColor(Color(hex: 0xe6e4de)).multilineTextAlignment(.leading)
                                    .onTapGesture { router.open(.privacy) }
                            }
                        }
                        .buttonStyle(PlainTap())
                    }
                    if !err.isEmpty { Text(err).font(.inter(14)).foregroundColor(pal.red) }
                    Button { Task { await submit() } } label: {
                        Text(reg ? prefs.t("register") : prefs.t("login")).font(.inter(18, .bold)).foregroundColor(Color(hex: 0x1a1508))
                            .frame(maxWidth: .infinity).frame(height: 54)
                            .background(RoundedRectangle(cornerRadius: 12).fill(pal.goldGrad))
                            .opacity(canSubmit ? 1 : 0.45)
                    }
                    .buttonStyle(PlainTap())
                    .disabled(!canSubmit)
                    HStack(spacing: 16) {
                        Rectangle().fill(Color(hex: 0x33363d)).frame(height: 1)
                        Text(prefs.t("or")).font(.inter(16)).foregroundColor(Color(hex: 0xc9c7c0))
                        Rectangle().fill(Color(hex: 0x33363d)).frame(height: 1)
                    }
                    Button { note = prefs.t("googleSoon") } label: {
                        ZStack {
                            Text(prefs.t("googleContinue")).font(.inter(17, .semibold)).foregroundColor(.white)
                            HStack {
                                GoogleMark(size: 22)
                                Spacer()
                            }
                            .padding(.leading, 22)
                        }
                        .frame(maxWidth: .infinity).frame(height: 54)
                        .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(Color(hex: 0x3a3d44), lineWidth: 1))
                    }
                    .buttonStyle(PlainTap())
                    if !note.isEmpty {
                        Text(note).font(.inter(13)).foregroundColor(Color(hex: 0xa7a9b0)).frame(maxWidth: .infinity).padding(.top, -6)
                    }
                    HStack(spacing: 4) {
                        Text(prefs.t("or")).foregroundColor(Color(hex: 0x8b8e96))
                        Button(reg ? prefs.t("login") : prefs.t("register")) { router.open(reg ? .login : .register) }
                            .font(.inter(17, .semibold)).foregroundColor(Color(hex: 0xf0d48a)).buttonStyle(PlainTap())
                    }
                    .font(.inter(17))
                    .padding(.top, 8)
                }
                .padding(.horizontal, 20).padding(.bottom, 32)
            }
            .scrollDismissesKeyboard(.interactively)
        }
        .preferredColorScheme(.dark)
    }

    private func field<C: View>(_ label: String, @ViewBuilder _ input: () -> C) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label).font(.inter(15)).foregroundColor(Color(hex: 0xa7a9b0))
            input()
                .font(.inter(16)).foregroundColor(.white)
                .padding(.horizontal, 16).frame(height: 54)
                .background(RoundedRectangle(cornerRadius: 12).fill(Color(hex: 0x1e2026)))
        }
    }

    private func submit() async {
        guard !busy, !email.isEmpty, !password.isEmpty, !register || agree else { return }
        busy = true; err = ""
        defer { busy = false }
        do {
            if register { try await session.register(email: email, password: password) } else { try await session.login(email: email, password: password) }
            Haptic.success()
            router.closeCover()
            router.go(register ? .assets : .home)
        } catch {
            let code = (error as? APIError)?.code ?? "service_unavailable"
            let key = "err_\(code)"
            err = prefs.has(key) ? prefs.t(key) : code
            Haptic.error()
        }
    }
}

struct GoogleMark: View {
    var size: CGFloat = 22
    var body: some View {
        Canvas { ctx, s in
            let k = s.width / 48
            for (path, color) in BrandMark.googleG {
                ctx.fill(path.applying(CGAffineTransform(scaleX: k, y: k)), with: .color(color))
            }
        }
        .frame(width: size, height: size)
    }
}
