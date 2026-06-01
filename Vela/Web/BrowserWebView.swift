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
        context.coordinator.observeProgress(of: webView)
        return webView
    }

    func updateNSView(_ nsView: WKWebView, context: Context) {
        nsView.navigationDelegate = context.coordinator
        context.coordinator.observeProgress(of: nsView)
    }

    final class Coordinator: NSObject, WKNavigationDelegate {
        let tabID: BrowserTab.ID
        weak var store: BrowserStore?
        private var progressObservation: NSKeyValueObservation?

        init(tabID: BrowserTab.ID, store: BrowserStore) {
            self.tabID = tabID
            self.store = store
        }

        func observeProgress(of webView: WKWebView) {
            // Avoid re-subscribing if already observing this web view
            guard progressObservation == nil else { return }
            progressObservation = webView.observe(\.estimatedProgress, options: [.new]) { [weak self] webView, _ in
                guard let self else { return }
                let progress = webView.estimatedProgress
                Task { @MainActor in
                    self.store?.updateTab(self.tabID, title: nil, url: nil, isLoading: webView.isLoading, estimatedProgress: progress)
                }
            }
        }

        func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
            Task { @MainActor in
                store?.updateTab(tabID, title: webView.title, url: webView.url, isLoading: true, estimatedProgress: 0.05)
            }
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            Task { @MainActor in
                store?.updateTab(tabID, title: webView.title, url: webView.url, isLoading: false, estimatedProgress: 1.0)
            }
        }

        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            Task { @MainActor in
                store?.updateTab(tabID, title: webView.title, url: webView.url, isLoading: false, estimatedProgress: 0)
            }
        }

        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
            Task { @MainActor in
                store?.updateTab(tabID, title: webView.title, url: webView.url, isLoading: false, estimatedProgress: 0)
            }
        }
    }
}
