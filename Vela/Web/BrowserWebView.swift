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
        webView.uiDelegate = context.coordinator
        context.coordinator.observe(webView)
        return webView
    }

    func updateNSView(_ nsView: WKWebView, context: Context) {
        nsView.navigationDelegate = context.coordinator
        nsView.uiDelegate = context.coordinator
        context.coordinator.observe(nsView)
    }

    final class Coordinator: NSObject, WKNavigationDelegate, WKUIDelegate {
        let tabID: BrowserTab.ID
        weak var store: BrowserStore?

        private var progressObservation: NSKeyValueObservation?
        private var canGoBackObservation: NSKeyValueObservation?
        private var canGoForwardObservation: NSKeyValueObservation?
        private var urlObservation: NSKeyValueObservation?
        private var titleObservation: NSKeyValueObservation?

        init(tabID: BrowserTab.ID, store: BrowserStore) {
            self.tabID = tabID
            self.store = store
        }

        // MARK: - KVO Observations

        func observe(_ webView: WKWebView) {
            guard progressObservation == nil else { return }

            progressObservation = webView.observe(\.estimatedProgress, options: [.new]) { [weak self] webView, _ in
                guard let self else { return }
                let progress = webView.estimatedProgress
                Task { @MainActor in
                    self.store?.updateTab(self.tabID, title: nil, url: nil, isLoading: webView.isLoading, estimatedProgress: progress)
                }
            }

            canGoBackObservation = webView.observe(\.canGoBack, options: [.new]) { [weak self] webView, _ in
                guard let self else { return }
                let value = webView.canGoBack
                Task { @MainActor in
                    self.store?.updateNavState(self.tabID, canGoBack: value, canGoForward: nil)
                }
            }

            canGoForwardObservation = webView.observe(\.canGoForward, options: [.new]) { [weak self] webView, _ in
                guard let self else { return }
                let value = webView.canGoForward
                Task { @MainActor in
                    self.store?.updateNavState(self.tabID, canGoBack: nil, canGoForward: value)
                }
            }

            urlObservation = webView.observe(\.url, options: [.new]) { [weak self] webView, _ in
                guard let self else { return }
                let url = webView.url
                let title = webView.title
                Task { @MainActor in
                    self.store?.updateTab(self.tabID, title: title, url: url, isLoading: webView.isLoading)
                }
            }

            titleObservation = webView.observe(\.title, options: [.new]) { [weak self] webView, _ in
                guard let self else { return }
                let title = webView.title
                let url = webView.url
                Task { @MainActor in
                    self.store?.updateTab(self.tabID, title: title, url: url, isLoading: webView.isLoading)
                }
            }
        }

        // MARK: - WKNavigationDelegate

        func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
            Task { @MainActor in
                store?.clearTabError(tabID)
                store?.updateTab(tabID, title: webView.title, url: webView.url, isLoading: true, estimatedProgress: 0.05)
                store?.updateNavState(tabID, canGoBack: webView.canGoBack, canGoForward: webView.canGoForward)
            }
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            Task { @MainActor in
                store?.updateTab(tabID, title: webView.title, url: webView.url, isLoading: false, estimatedProgress: 1.0)
                store?.updateNavState(tabID, canGoBack: webView.canGoBack, canGoForward: webView.canGoForward)
            }
        }

        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            Task { @MainActor in
                store?.updateTab(tabID, title: webView.title, url: webView.url, isLoading: false, estimatedProgress: 0)
                store?.updateNavState(tabID, canGoBack: webView.canGoBack, canGoForward: webView.canGoForward)
                let nsError = error as NSError
                if nsError.code != NSURLErrorCancelled {
                    store?.setTabError(tabID, description: nsError.localizedDescription, code: nsError.code)
                }
            }
        }

        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
            Task { @MainActor in
                store?.updateTab(tabID, title: webView.title, url: webView.url, isLoading: false, estimatedProgress: 0)
                store?.updateNavState(tabID, canGoBack: webView.canGoBack, canGoForward: webView.canGoForward)
                let nsError = error as NSError
                if nsError.code != NSURLErrorCancelled {
                    store?.setTabError(tabID, description: nsError.localizedDescription, code: nsError.code)
                }
            }
        }

        // MARK: - WKNavigationDelegate: SSL Challenges

        func webView(_ webView: WKWebView, didReceive challenge: URLAuthenticationChallenge, completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
            guard challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust,
                  let serverTrust = challenge.protectionSpace.serverTrust else {
                completionHandler(.performDefaultHandling, nil)
                return
            }

            let host = challenge.protectionSpace.host
            Task { @MainActor in
                if self.store?.sslExceptions.contains(host) == true {
                    completionHandler(.useCredential, URLCredential(trust: serverTrust))
                } else {
                    completionHandler(.performDefaultHandling, nil)
                }
            }
        }

        // MARK: - WKNavigationDelegate: Downloads

        func webView(_ webView: WKWebView, decidePolicyFor navigationResponse: WKNavigationResponse) async -> WKNavigationResponsePolicy {
            // If the response isn't something WebKit can show, download it
            if !navigationResponse.canShowMIMEType {
                return .download
            }
            return .allow
        }

        func webView(_ webView: WKWebView, navigationResponse: WKNavigationResponse, didBecome download: WKDownload) {
            Task { @MainActor in
                store?.downloadManager.startDownload(download)
            }
        }

        func webView(_ webView: WKWebView, navigationAction: WKNavigationAction, didBecome download: WKDownload) {
            Task { @MainActor in
                store?.downloadManager.startDownload(download)
            }
        }

        // MARK: - WKUIDelegate: JS Dialogs

        func webView(_ webView: WKWebView, runJavaScriptAlertPanelWithMessage message: String, initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping () -> Void) {
            let alert = NSAlert()
            alert.messageText = frame.request.url?.host() ?? "Web Page"
            alert.informativeText = message
            alert.addButton(withTitle: "OK")
            alert.alertStyle = .informational

            if let window = webView.window {
                alert.beginSheetModal(for: window) { _ in
                    completionHandler()
                }
            } else {
                alert.runModal()
                completionHandler()
            }
        }

        func webView(_ webView: WKWebView, runJavaScriptConfirmPanelWithMessage message: String, initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping (Bool) -> Void) {
            let alert = NSAlert()
            alert.messageText = frame.request.url?.host() ?? "Web Page"
            alert.informativeText = message
            alert.addButton(withTitle: "OK")
            alert.addButton(withTitle: "Cancel")
            alert.alertStyle = .informational

            if let window = webView.window {
                alert.beginSheetModal(for: window) { response in
                    completionHandler(response == .alertFirstButtonReturn)
                }
            } else {
                let response = alert.runModal()
                completionHandler(response == .alertFirstButtonReturn)
            }
        }

        func webView(_ webView: WKWebView, runJavaScriptTextInputPanelWithPrompt prompt: String, defaultText: String?, initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping (String?) -> Void) {
            let alert = NSAlert()
            alert.messageText = frame.request.url?.host() ?? "Web Page"
            alert.informativeText = prompt
            alert.addButton(withTitle: "OK")
            alert.addButton(withTitle: "Cancel")

            let textField = NSTextField(frame: NSRect(x: 0, y: 0, width: 260, height: 24))
            textField.stringValue = defaultText ?? ""
            alert.accessoryView = textField

            if let window = webView.window {
                alert.beginSheetModal(for: window) { response in
                    completionHandler(response == .alertFirstButtonReturn ? textField.stringValue : nil)
                }
            } else {
                let response = alert.runModal()
                completionHandler(response == .alertFirstButtonReturn ? textField.stringValue : nil)
            }
        }

        // MARK: - WKUIDelegate: Media Permissions

        func webView(_ webView: WKWebView, requestMediaCapturePermissionFor origin: WKSecurityOrigin, initiatedByFrame frame: WKFrameInfo, type: WKMediaCaptureType, decisionHandler: @escaping (WKPermissionDecision) -> Void) {
            let permissionName: String = switch type {
            case .camera: "camera"
            case .microphone: "microphone"
            case .cameraAndMicrophone: "camera and microphone"
            @unknown default: "media"
            }

            let alert = NSAlert()
            alert.messageText = "\(origin.host) wants to use your \(permissionName)"
            alert.informativeText = "This site is requesting access to your \(permissionName)."
            alert.addButton(withTitle: "Allow")
            alert.addButton(withTitle: "Deny")
            alert.alertStyle = .informational

            if let window = webView.window {
                alert.beginSheetModal(for: window) { response in
                    decisionHandler(response == .alertFirstButtonReturn ? .grant : .deny)
                }
            } else {
                let response = alert.runModal()
                decisionHandler(response == .alertFirstButtonReturn ? .grant : .deny)
            }
        }

        // MARK: - WKUIDelegate: New Window (window.open, target=_blank)

        func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration, for navigationAction: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
            let blockPopups = UserDefaults.standard.bool(forKey: "blockPopups")

            // If pop-ups are blocked and this wasn't user-initiated, ignore
            if blockPopups && !navigationAction.sourceFrame.isMainFrame && navigationAction.navigationType != .linkActivated {
                return nil
            }

            // Open as new tab
            if let url = navigationAction.request.url {
                Task { @MainActor in
                    VelaAnimation.withEmphasis {
                        self.store?.createTab(url: url)
                    }
                }
            }
            return nil
        }
    }
}
