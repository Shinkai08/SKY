import SwiftUI
import WebKit

/// Admin console: the website's own admin pages in a web view, signed in with the app's session cookie.
struct AdminPage: View {
    @Environment(Router.self) private var router
    @Environment(\.pal) private var pal
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                IconButton(.arrowLeft, size: 22) { router.back() }
                Spacer()
            }
            .padding(.horizontal, 8)
            AdminWebView()
        }
    }
}

struct AdminWebView: UIViewRepresentable {
    final class Coordinator: NSObject, WKNavigationDelegate {
        var routed = false
        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            guard !routed else { return }
            routed = true
            // In-site navigation, so the route survives the site's history check.
            webView.evaluateJavaScript("history.pushState({skyRoute:'#/f2xp'},'','#/f2xp');dispatchEvent(new Event('sky:routechange'))")
        }
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeUIView(context: Context) -> WKWebView {
        let cfg = WKWebViewConfiguration()
        let web = WKWebView(frame: .zero, configuration: cfg)
        web.navigationDelegate = context.coordinator
        let store = cfg.websiteDataStore.httpCookieStore
        let cookies = HTTPCookieStorage.shared.cookies(for: API.site) ?? []
        let group = DispatchGroup()
        for c in cookies { group.enter(); store.setCookie(c) { group.leave() } }
        group.notify(queue: .main) { web.load(URLRequest(url: API.site)) }
        return web
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {}
}
