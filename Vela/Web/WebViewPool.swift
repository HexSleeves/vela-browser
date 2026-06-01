import Foundation
import WebKit

@MainActor
protocol WebViewPooling: AnyObject {
    func load(_ url: URL, in tabID: BrowserTab.ID)
    func remove(tabID: BrowserTab.ID)
    func goBack(tabID: BrowserTab.ID)
    func goForward(tabID: BrowserTab.ID)
    func reload(tabID: BrowserTab.ID)
    func stopLoading(tabID: BrowserTab.ID)
    func setZoom(_ level: Double, tabID: BrowserTab.ID)
    func findInPage(_ text: String, tabID: BrowserTab.ID)
    func findNext(tabID: BrowserTab.ID)
    func findPrevious(tabID: BrowserTab.ID)
    func clearFind(tabID: BrowserTab.ID)
    func printPage(tabID: BrowserTab.ID)
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

    func goBack(tabID: BrowserTab.ID) {
        webViews[tabID]?.goBack()
    }

    func goForward(tabID: BrowserTab.ID) {
        webViews[tabID]?.goForward()
    }

    func reload(tabID: BrowserTab.ID) {
        webViews[tabID]?.reload()
    }

    func stopLoading(tabID: BrowserTab.ID) {
        webViews[tabID]?.stopLoading()
    }

    func setZoom(_ level: Double, tabID: BrowserTab.ID) {
        webViews[tabID]?.pageZoom = level
    }

    func findInPage(_ text: String, tabID: BrowserTab.ID) {
        guard let webView = webViews[tabID], !text.isEmpty else {
            clearFind(tabID: tabID)
            return
        }
        // Use JavaScript window.find for broad compatibility
        let escaped = text.replacingOccurrences(of: "'", with: "\\'")
        webView.evaluateJavaScript("window.find('\(escaped)', false, false, true)") { _, _ in }
    }

    func findNext(tabID: BrowserTab.ID) {
        guard let webView = webViews[tabID] else { return }
        webView.evaluateJavaScript("window.find(window.__velaFindText || '', false, false, true)") { _, _ in }
    }

    func findPrevious(tabID: BrowserTab.ID) {
        guard let webView = webViews[tabID] else { return }
        webView.evaluateJavaScript("window.find(window.__velaFindText || '', false, true, true)") { _, _ in }
    }

    func clearFind(tabID: BrowserTab.ID) {
        guard let webView = webViews[tabID] else { return }
        webView.evaluateJavaScript("window.getSelection()?.removeAllRanges()") { _, _ in }
    }

    func printPage(tabID: BrowserTab.ID) {
        guard let webView = webViews[tabID] else { return }
        let printInfo = NSPrintInfo.shared
        let printOp = webView.printOperation(with: printInfo)
        printOp.showsPrintPanel = true
        printOp.showsProgressPanel = true
        printOp.runModal(for: webView.window ?? NSWindow(), delegate: nil, didRun: nil, contextInfo: nil)
    }
}
