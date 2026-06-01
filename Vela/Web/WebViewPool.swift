import Foundation
import WebKit

@MainActor
protocol WebViewPooling: AnyObject {
    func load(_ url: URL, in tabID: BrowserTab.ID)
    func remove(tabID: BrowserTab.ID)
}

@MainActor
final class WebViewPool: WebViewPooling {
    private var webViews: [BrowserTab.ID: WKWebView] = [:]

    func webView(for tabID: BrowserTab.ID) -> WKWebView {
        if let existing = webViews[tabID] {
            return existing
        }

        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = .default()
        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.allowsBackForwardNavigationGestures = true
        webViews[tabID] = webView
        return webView
    }

    func load(_ url: URL, in tabID: BrowserTab.ID) {
        webView(for: tabID).load(URLRequest(url: url))
    }

    func remove(tabID: BrowserTab.ID) {
        webViews.removeValue(forKey: tabID)
    }
}
