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
        context.coordinator.installPeekHandler(on: webView)
        context.coordinator.installZapHandler(on: webView)
        context.coordinator.observe(webView)

        if webView.url == nil, let tab = store.tabs[tabID], let url = tab.url, !tab.isStub {
            webView.load(URLRequest(url: url))
        }

        return webView
    }

    func updateNSView(_ nsView: WKWebView, context: Context) {
        nsView.navigationDelegate = context.coordinator
        nsView.uiDelegate = context.coordinator
        context.coordinator.observe(nsView)
    }

    @MainActor
    final class Coordinator: NSObject, WKNavigationDelegate, WKUIDelegate, WKScriptMessageHandler {
        let tabID: BrowserTab.ID
        weak var store: BrowserStore?

        private var progressObservation: NSKeyValueObservation?
        private var canGoBackObservation: NSKeyValueObservation?
        private var canGoForwardObservation: NSKeyValueObservation?
        private var urlObservation: NSKeyValueObservation?
        private var titleObservation: NSKeyValueObservation?
        private var peekDelayTask: Task<Void, Never>?
        private var peekHandlerInstalled = false

        init(tabID: BrowserTab.ID, store: BrowserStore) {
            self.tabID = tabID
            self.store = store
        }

        // MARK: - Peek JS Injection

        func installPeekHandler(on webView: WKWebView) {
            guard !peekHandlerInstalled else { return }
            peekHandlerInstalled = true
            WebScriptMessageHandlerInstaller.replaceHandler(
                self,
                name: WebScriptMessageHandlerInstaller.peekName,
                in: webView.configuration.userContentController
            )
        }

        private var zapHandlerInstalled = false

        func installZapHandler(on webView: WKWebView) {
            guard !zapHandlerInstalled else { return }
            zapHandlerInstalled = true
            WebScriptMessageHandlerInstaller.replaceHandler(
                self,
                name: WebScriptMessageHandlerInstaller.zapName,
                in: webView.configuration.userContentController
            )
        }

        nonisolated func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
            Task { @MainActor in
                if message.name == WebScriptMessageHandlerInstaller.zapName, let selector = message.body as? String {
                    self.store?.createZapBoost(selector: selector)
                    return
                }

                guard message.name == WebScriptMessageHandlerInstaller.peekName else { return }
                guard let body = message.body as? [String: String],
                      let type = body["type"] else { return }

                if type == "hover", let urlString = body["url"],
                   let url = URL(string: urlString) {
                    if let pageURL = self.store?.tabs[self.tabID]?.url,
                       AuthPageCompatibility.disablesPeekPreviews(for: pageURL) {
                        self.hidePeek()
                        return
                    }

                    self.peekDelayTask?.cancel()
                    self.peekDelayTask = Task { @MainActor in
                        try? await Task.sleep(for: .milliseconds(300))
                        guard !Task.isCancelled else { return }
                        self.store?.peekURL = url
                        VelaAnimation.withEmphasis {
                            self.store?.isPeekVisible = true
                        }
                    }
                } else if type == "leave" {
                    self.peekDelayTask?.cancel()
                    if self.store?.isPeekVisible == true {
                        VelaAnimation.withEmphasis {
                            self.store?.isPeekVisible = false
                            self.store?.peekURL = nil
                        }
                    }
                }
            }
        }

        // MARK: - KVO Observations

        func observe(_ webView: WKWebView) {
            guard progressObservation == nil else { return }

            progressObservation = webView.observe(\.estimatedProgress, options: [.new]) { [weak self] webView, change in
                guard let self, let progress = change.newValue else { return }
                Task { @MainActor in
                    self.store?.updateTab(self.tabID, title: nil, url: nil, isLoading: webView.isLoading, estimatedProgress: progress)
                }
            }

            canGoBackObservation = webView.observe(\.canGoBack, options: [.new]) { [weak self] webView, change in
                guard let self, let value = change.newValue else { return }
                Task { @MainActor in
                    self.store?.updateNavState(self.tabID, canGoBack: value, canGoForward: nil)
                }
            }

            canGoForwardObservation = webView.observe(\.canGoForward, options: [.new]) { [weak self] webView, change in
                guard let self, let value = change.newValue else { return }
                Task { @MainActor in
                    self.store?.updateNavState(self.tabID, canGoBack: nil, canGoForward: value)
                }
            }

            urlObservation = webView.observe(\.url, options: [.new]) { [weak self] webView, change in
                guard let self, let url = change.newValue ?? nil else { return }
                Task { @MainActor in
                    self.store?.updateTab(self.tabID, title: nil, url: url, isLoading: webView.isLoading)
                }
            }

            titleObservation = webView.observe(\.title, options: [.new]) { [weak self] webView, change in
                guard let self, let title = change.newValue ?? nil else { return }
                Task { @MainActor in
                    self.store?.updateTab(self.tabID, title: title, url: nil, isLoading: webView.isLoading)
                }
            }
        }

        // MARK: - WKNavigationDelegate

        func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction) async -> WKNavigationActionPolicy {
            if let url = navigationAction.request.url,
               AuthPageCompatibility.disablesPeekPreviews(for: url) {
                hidePeek()
            }

            // Intercept link clicks in pinned tabs with designated URLs
            if navigationAction.navigationType == .linkActivated,
               let url = navigationAction.request.url,
               let store = self.store,
               store.isPinnedWithDesignatedURL(tabID) {
                Task { @MainActor in
                    VelaAnimation.withEmphasis {
                        store.createTab(url: url)
                    }
                }
                return .cancel
            }

            // Existing swipe indicator logic
            if navigationAction.navigationType == .backForward,
               let url = navigationAction.request.url {
                if webView.backForwardList.backItem?.url == url {
                    store?.showSwipeIndicator(.back, for: tabID)
                } else if webView.backForwardList.forwardItem?.url == url {
                    store?.showSwipeIndicator(.forward, for: tabID)
                }
            }
            return .allow
        }

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
                if let url = webView.url, GoogleSignInCompatibility.isEmbeddedSignInRejection(url) {
                    store?.setTabError(
                        tabID,
                        description: "Google blocks sign-in inside embedded browser views. Open this sign-in flow in your default browser to continue.",
                        code: BrowserErrorCode.googleEmbeddedSignInBlocked
                    )
                    return
                }

                if let url = webView.url, AuthPageCompatibility.disablesPeekPreviews(for: url) {
                    self.hidePeek()
                    return
                }

                self.injectPeekScript(webView)
            }
        }

        private func hidePeek() {
            peekDelayTask?.cancel()
            VelaAnimation.withEmphasis {
                store?.isPeekVisible = false
                store?.peekURL = nil
            }
        }

        private func injectPeekScript(_ webView: WKWebView) {
            let js = """
            (function() {
                if (window.__velaPeekInstalled) return;
                window.__velaPeekInstalled = true;
                document.addEventListener('mouseover', function(e) {
                    var a = e.target.closest('a[href]');
                    if (a && a.href && a.href.startsWith('http')) {
                        window.webkit.messageHandlers.velaPeek.postMessage({type: 'hover', url: a.href});
                    }
                });
                document.addEventListener('mouseout', function(e) {
                    var a = e.target.closest('a[href]');
                    if (a) {
                        window.webkit.messageHandlers.velaPeek.postMessage({type: 'leave'});
                    }
                });
            })();
            """
            webView.evaluateJavaScript(js) { _, _ in }
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

        func webView(_ webView: WKWebView, respondTo challenge: URLAuthenticationChallenge) async -> (URLSession.AuthChallengeDisposition, URLCredential?) {
            guard challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust,
                  let serverTrust = challenge.protectionSpace.serverTrust else {
                return (.performDefaultHandling, nil)
            }

            let host = challenge.protectionSpace.host
            if store?.sslExceptions.contains(host) == true {
                return (.useCredential, URLCredential(trust: serverTrust))
            }
            return (.performDefaultHandling, nil)
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

        func webView(_ webView: WKWebView, runJavaScriptAlertPanelWithMessage message: String, initiatedByFrame frame: WKFrameInfo) async {
            let alert = NSAlert()
            alert.messageText = frame.request.url?.host() ?? "Web Page"
            alert.informativeText = message
            alert.addButton(withTitle: "OK")
            alert.alertStyle = .informational

            if let window = webView.window {
                _ = await alert.beginSheetModal(for: window)
            } else {
                alert.runModal()
            }
        }

        func webView(_ webView: WKWebView, runJavaScriptConfirmPanelWithMessage message: String, initiatedByFrame frame: WKFrameInfo) async -> Bool {
            let alert = NSAlert()
            alert.messageText = frame.request.url?.host() ?? "Web Page"
            alert.informativeText = message
            alert.addButton(withTitle: "OK")
            alert.addButton(withTitle: "Cancel")
            alert.alertStyle = .informational

            let response: NSApplication.ModalResponse
            if let window = webView.window {
                response = await alert.beginSheetModal(for: window)
            } else {
                response = alert.runModal()
            }
            return response == .alertFirstButtonReturn
        }

        func webView(_ webView: WKWebView, runJavaScriptTextInputPanelWithPrompt prompt: String, defaultText: String?, initiatedByFrame frame: WKFrameInfo) async -> String? {
            let alert = NSAlert()
            alert.messageText = frame.request.url?.host() ?? "Web Page"
            alert.informativeText = prompt
            alert.addButton(withTitle: "OK")
            alert.addButton(withTitle: "Cancel")

            let textField = NSTextField(frame: NSRect(x: 0, y: 0, width: 260, height: 24))
            textField.stringValue = defaultText ?? ""
            alert.accessoryView = textField

            let response: NSApplication.ModalResponse
            if let window = webView.window {
                response = await alert.beginSheetModal(for: window)
            } else {
                response = alert.runModal()
            }
            return response == .alertFirstButtonReturn ? textField.stringValue : nil
        }

        // MARK: - WKUIDelegate: Media Permissions

        func webView(_ webView: WKWebView, decideMediaCapturePermissionsFor origin: WKSecurityOrigin, initiatedBy frame: WKFrameInfo, type: WKMediaCaptureType) async -> WKPermissionDecision {
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

            let response: NSApplication.ModalResponse
            if let window = webView.window {
                response = await alert.beginSheetModal(for: window)
            } else {
                response = alert.runModal()
            }
            return response == .alertFirstButtonReturn ? .grant : .deny
        }

        // MARK: - WKUIDelegate: New Window (window.open, target=_blank)

        func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration, for navigationAction: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
            let blockPopups = UserDefaults.standard.bool(forKey: "blockPopups")

            // If pop-ups are blocked, only allow user-activated link popups.
            if blockPopups && navigationAction.navigationType != .linkActivated {
                return nil
            }

            // In transient windows, keep popups inside the same privacy/lifetime boundary.
            if let url = navigationAction.request.url,
               let store = self.store,
               store.isTransientTab(tabID) {
                webView.load(URLRequest(url: url))
                return nil
            }

            // Open regular pages as new regular tab.
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
