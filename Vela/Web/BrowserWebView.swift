import SwiftUI
import WebKit

struct BrowserWebView: NSViewRepresentable {
    let tabID: BrowserTab.ID
    @Environment(BrowserStore.self) private var store

    func makeCoordinator() -> Coordinator {
        Coordinator(tabID: tabID, store: store)
    }

    func makeNSView(context: Context) -> WKWebView {
        guard let pool = store.webViewPool as? WebViewPool else {
            return WKWebView(frame: .zero)
        }

        let webView = pool.webView(for: tabID)
        webView.navigationDelegate = context.coordinator
        return webView
    }

    func updateNSView(_ nsView: WKWebView, context: Context) {
        nsView.navigationDelegate = context.coordinator
    }

    final class Coordinator: NSObject, WKNavigationDelegate {
        let tabID: BrowserTab.ID
        weak var store: BrowserStore?

        init(tabID: BrowserTab.ID, store: BrowserStore) {
            self.tabID = tabID
            self.store = store
        }

        func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
            Task { @MainActor in
                store?.updateTab(tabID, title: webView.title, url: webView.url, isLoading: true)
            }
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            Task { @MainActor in
                store?.updateTab(tabID, title: webView.title, url: webView.url, isLoading: false)
            }
        }

        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            Task { @MainActor in
                store?.updateTab(tabID, title: webView.title, url: webView.url, isLoading: false)
            }
        }

        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
            Task { @MainActor in
                store?.updateTab(tabID, title: webView.title, url: webView.url, isLoading: false)
            }
        }
    }
}
