import SwiftUI
import WebKit

// SKY iOS shell: a full-screen web view on the live site. Logins persist in
// the default website data store; links to other sites open in Safari.

private let home = URL(string: "https://sky.shinkaicc.com/")!

@main
struct SKYApp: App {
    var body: some Scene {
        WindowGroup {
            WebView(url: home)
                .ignoresSafeArea()
                .background(Color(red: 0.04, green: 0.05, blue: 0.06))
                .preferredColorScheme(.dark)
        }
    }
}

struct WebView: UIViewRepresentable {
    let url: URL

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.websiteDataStore = .default()
        config.allowsInlineMediaPlayback = true
        config.applicationNameForUserAgent = "SKYApp/1.0"
        let web = WKWebView(frame: .zero, configuration: config)
        web.navigationDelegate = context.coordinator
        web.uiDelegate = context.coordinator
        web.allowsBackForwardNavigationGestures = true
        web.isOpaque = false
        web.backgroundColor = UIColor(red: 0.04, green: 0.05, blue: 0.06, alpha: 1)
        web.scrollView.contentInsetAdjustmentBehavior = .never // the page handles safe areas itself

        let refresh = UIRefreshControl()
        refresh.addTarget(context.coordinator, action: #selector(Coordinator.reload(_:)), for: .valueChanged)
        web.scrollView.refreshControl = refresh
        context.coordinator.web = web

        web.load(URLRequest(url: url))
        return web
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {}

    final class Coordinator: NSObject, WKNavigationDelegate, WKUIDelegate, WKDownloadDelegate {
        weak var web: WKWebView?
        private var downloads: [ObjectIdentifier: URL] = [:]

        @objc func reload(_ sender: UIRefreshControl) {
            web?.reload()
            sender.endRefreshing()
        }

        // Stay inside the app for SKY pages; hand everything else to the system.
        func webView(_ webView: WKWebView, decidePolicyFor action: WKNavigationAction,
                     decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
            // <a download> (e.g. "Save image" on the share poster): fetch it, then offer the share sheet.
            if action.shouldPerformDownload { return decisionHandler(.download) }
            guard let target = action.request.url else { return decisionHandler(.allow) }
            let scheme = target.scheme?.lowercased() ?? ""
            if scheme == "http" || scheme == "https" {
                if target.host == home.host || action.targetFrame?.isMainFrame == false {
                    return decisionHandler(.allow)
                }
                UIApplication.shared.open(target)
                return decisionHandler(.cancel)
            }
            if scheme == "about" || scheme == "blob" || scheme == "data" {
                return decisionHandler(.allow)
            }
            UIApplication.shared.open(target) // mailto:, tel:, wallet links …
            decisionHandler(.cancel)
        }

        func webView(_ webView: WKWebView, navigationAction: WKNavigationAction, didBecome download: WKDownload) {
            download.delegate = self
        }

        func webView(_ webView: WKWebView, navigationResponse: WKNavigationResponse, didBecome download: WKDownload) {
            download.delegate = self
        }

        func download(_ download: WKDownload, decideDestinationUsing response: URLResponse, suggestedFilename: String,
                      completionHandler: @escaping (URL?) -> Void) {
            let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
            do {
                try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            } catch {
                return completionHandler(nil)
            }
            let name = suggestedFilename.isEmpty ? "SKY.png" : suggestedFilename
            let file = dir.appendingPathComponent(name)
            downloads[ObjectIdentifier(download)] = file
            completionHandler(file)
        }

        func downloadDidFinish(_ download: WKDownload) {
            guard let file = downloads.removeValue(forKey: ObjectIdentifier(download)) else { return }
            // An image is shared as a picture so the sheet offers "Save Image" to Photos.
            let item: Any = UIImage(contentsOfFile: file.path) ?? file
            let sheet = UIActivityViewController(activityItems: [item], applicationActivities: nil)
            if let pop = sheet.popoverPresentationController, let web {
                pop.sourceView = web
                pop.sourceRect = CGRect(x: web.bounds.midX, y: web.bounds.midY, width: 1, height: 1)
            }
            present(sheet) {}
        }

        func download(_ download: WKDownload, didFailWithError error: Error, resumeData: Data?) {
            downloads.removeValue(forKey: ObjectIdentifier(download))
        }

        // target=_blank: open SKY links in place, others in Safari.
        func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration,
                     for action: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
            if let target = action.request.url {
                if target.host == home.host { webView.load(action.request) } else { UIApplication.shared.open(target) }
            }
            return nil
        }

        // Show a simple retry page when the network is down.
        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
            let html = """
            <html><head><meta name="viewport" content="width=device-width,initial-scale=1">
            <style>body{background:#0a0c0f;color:#ddd;font:17px -apple-system;display:flex;flex-direction:column;
            align-items:center;justify-content:center;height:100vh;margin:0}a{color:#e8c878;margin-top:16px}</style></head>
            <body><div>无法连接 SKY · Can't reach SKY</div><a href="\(home.absoluteString)">重试 · Retry</a></body></html>
            """
            webView.loadHTMLString(html, baseURL: nil)
        }

        func webView(_ webView: WKWebView, runJavaScriptAlertPanelWithMessage message: String,
                     initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping () -> Void) {
            let alert = UIAlertController(title: nil, message: message, preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "OK", style: .default) { _ in completionHandler() })
            present(alert, fallback: completionHandler)
        }

        func webView(_ webView: WKWebView, runJavaScriptConfirmPanelWithMessage message: String,
                     initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping (Bool) -> Void) {
            let alert = UIAlertController(title: nil, message: message, preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "取消", style: .cancel) { _ in completionHandler(false) })
            alert.addAction(UIAlertAction(title: "确定", style: .default) { _ in completionHandler(true) })
            present(alert) { completionHandler(false) }
        }

        private func present(_ controller: UIViewController, fallback: @escaping () -> Void) {
            let root = UIApplication.shared.connectedScenes.compactMap { ($0 as? UIWindowScene)?.keyWindow?.rootViewController }.first
            guard let root else { return fallback() }
            var top = root
            while let next = top.presentedViewController { top = next }
            top.present(controller, animated: true)
        }
    }
}
