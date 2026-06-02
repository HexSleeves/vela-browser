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
    func setMuted(_ muted: Bool, tabID: BrowserTab.ID)
    func toggleReaderMode(tabID: BrowserTab.ID, enable: Bool)
}

@MainActor
final class WebViewPool: WebViewPooling {
    private var webViews: [BrowserTab.ID: WKWebView] = [:]
    weak var store: BrowserStore?

    init() {
        // Clear stale website data once to ensure UA changes take effect.
        let key = "uaClearedV3"
        if !UserDefaults.standard.bool(forKey: key) {
            WKWebsiteDataStore.default().removeData(
                ofTypes: WKWebsiteDataStore.allWebsiteDataTypes(),
                modifiedSince: .distantPast
            ) {}
            UserDefaults.standard.set(true, forKey: key)
        }
    }

    private let userAgent = BrowserUserAgent.safariCompatibleMac

    func webView(for tabID: BrowserTab.ID) -> WKWebView {
        if let existing = webViews[tabID] {
            if existing.customUserAgent != userAgent {
                existing.customUserAgent = userAgent
            }
            return existing
        }

        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = dataStore(for: tabID)
        store?.contentBlocker.applyRules(to: configuration)
        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.allowsBackForwardNavigationGestures = true
        webView.customUserAgent = userAgent
        webViews[tabID] = webView
        return webView
    }

    private func dataStore(for tabID: BrowserTab.ID) -> WKWebsiteDataStore {
        guard let store else { return .default() }

        if store.isPrivateTab(tabID) {
            return .nonPersistent()
        }

        // Find workspace containing this tab
        guard let workspace = store.workspaces.first(where: { $0.tabIDs.contains(tabID) || $0.archivedTabIDs.contains(tabID) }) else {
            return .default()
        }

        let profile = store.profileForWorkspace(workspace.id)

        if let identifier = profile.dataStoreIdentifier {
            return WKWebsiteDataStore(forIdentifier: identifier)
        }

        return .default()
    }

    func load(_ url: URL, in tabID: BrowserTab.ID) {
        let wv = webView(for: tabID)

        // Inject boosts for this host. Private browsing disables boosts by default
        // so user scripts cannot observe private-page DOM without an explicit future permission model.
        if store?.isPrivateTab(tabID) != true, let host = url.host(), let store {
            let matching = store.boostsForHost(host)
            // Clear previous user scripts and re-add
            wv.configuration.userContentController.removeAllUserScripts()
            for boost in matching {
                if !boost.css.isEmpty {
                    let cssScript = "var s=document.createElement('style');s.textContent=\(boost.css.debugDescription);document.head.appendChild(s);"
                    let script = WKUserScript(source: cssScript, injectionTime: .atDocumentEnd, forMainFrameOnly: true)
                    wv.configuration.userContentController.addUserScript(script)
                }
                if !boost.js.isEmpty {
                    let script = WKUserScript(source: boost.js, injectionTime: .atDocumentEnd, forMainFrameOnly: true)
                    wv.configuration.userContentController.addUserScript(script)
                }
            }
        }

        wv.load(URLRequest(url: url))
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

    func setMuted(_ muted: Bool, tabID: BrowserTab.ID) {
        guard let webView = webViews[tabID] else { return }
        webView.setAllMediaPlaybackSuspended(muted)
    }

    func printPage(tabID: BrowserTab.ID) {
        guard let webView = webViews[tabID] else { return }
        let printInfo = NSPrintInfo.shared
        let printOp = webView.printOperation(with: printInfo)
        printOp.showsPrintPanel = true
        printOp.showsProgressPanel = true
        printOp.runModal(for: webView.window ?? NSWindow(), delegate: nil, didRun: nil, contextInfo: nil)
    }

    func toggleReaderMode(tabID: BrowserTab.ID, enable: Bool) {
        guard let webView = webViews[tabID] else { return }
        if enable {
            // Extract article content and display in reader template
            let extractionJS = """
            (function() {
                var article = document.querySelector('article') || document.querySelector('[role="main"]') || document.querySelector('main');
                if (!article) {
                    var paras = document.querySelectorAll('p');
                    var best = null, bestLen = 0;
                    var parent = null;
                    paras.forEach(function(p) {
                        var pp = p.parentElement;
                        if (pp && pp.textContent.length > bestLen) {
                            bestLen = pp.textContent.length;
                            parent = pp;
                        }
                    });
                    article = parent || document.body;
                }
                var title = document.title || '';
                return JSON.stringify({title: title, content: article.innerHTML});
            })()
            """
            webView.evaluateJavaScript(extractionJS) { [weak webView] result, _ in
                guard let jsonString = result as? String,
                      let data = jsonString.data(using: .utf8),
                      let parsed = try? JSONSerialization.jsonObject(with: data) as? [String: String],
                      let title = parsed["title"],
                      let content = parsed["content"] else { return }

                let readerHTML = """
                <!DOCTYPE html>
                <html><head>
                <meta charset="utf-8">
                <meta name="viewport" content="width=device-width">
                <style>
                    body { font-family: -apple-system, Georgia, serif; max-width: 680px; margin: 40px auto; padding: 0 20px; line-height: 1.7; color: #e0e0e0; background: #1a1a1a; }
                    h1 { font-size: 2em; line-height: 1.2; margin-bottom: 0.5em; }
                    img { max-width: 100%; height: auto; border-radius: 8px; }
                    a { color: #6db3f2; }
                    pre, code { background: #2a2a2a; padding: 2px 6px; border-radius: 4px; font-size: 0.9em; }
                    pre { padding: 12px; overflow-x: auto; }
                    blockquote { border-left: 3px solid #444; margin-left: 0; padding-left: 16px; color: #aaa; }
                </style>
                </head><body>
                <h1>\(title.replacingOccurrences(of: "<", with: "&lt;"))</h1>
                \(content)
                </body></html>
                """
                webView?.loadHTMLString(readerHTML, baseURL: webView?.url)
            }
        } else {
            // Reload original page
            webView.reload()
        }
    }
}
