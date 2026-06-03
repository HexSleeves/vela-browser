import Foundation
import Testing
import WebKit
@testable import Vela

@MainActor
@Suite("Content Blocking")
struct ContentBlockingTests {
    @Test("toggle content blocking exception adds host")
    func toggleExceptionAddsHost() {
        let store = makeStore()

        store.toggleContentBlockingException(host: "example.com")

        #expect(store.contentBlockingExceptions.contains("example.com"))
        #expect(store.isContentBlockingDisabled(for: "example.com") == true)
    }

    @Test("toggle content blocking exception removes existing host")
    func toggleExceptionRemovesHost() {
        let store = makeStore()
        store.toggleContentBlockingException(host: "example.com")

        store.toggleContentBlockingException(host: "example.com")

        #expect(store.contentBlockingExceptions.contains("example.com") == false)
        #expect(store.isContentBlockingDisabled(for: "example.com") == false)
    }

    @Test("isContentBlockingDisabled returns false for non-excepted host")
    func isDisabledReturnsFalseForNonExcepted() {
        let store = makeStore()

        #expect(store.isContentBlockingDisabled(for: "example.com") == false)
    }

    @Test("ContentBlockerService parseEasyList handles domain block rules")
    func parseEasyListDomainBlock() {
        let service = ContentBlockerService()
        let rules = service.parseEasyList("||ads.example.com^\n")

        #expect(rules.count == 1)
        let trigger = rules[0]["trigger"] as? [String: Any]
        let action = rules[0]["action"] as? [String: String]
        #expect(action?["type"] == "block")
        #expect(trigger?["url-filter"] as? String != nil)
    }

    @Test("ContentBlockerService parseEasyList handles CSS hiding rules")
    func parseEasyListCSSHiding() {
        let service = ContentBlockerService()
        let rules = service.parseEasyList("##.ad-banner\n")

        #expect(rules.count == 1)
        let action = rules[0]["action"] as? [String: String]
        #expect(action?["type"] == "css-display-none")
        #expect(action?["selector"] == ".ad-banner")
    }

    @Test("ContentBlockerService parseEasyList handles exception rules")
    func parseEasyListExceptionRules() {
        let service = ContentBlockerService()
        let rules = service.parseEasyList("@@||example.com^\n")

        #expect(rules.count == 1)
        let action = rules[0]["action"] as? [String: String]
        #expect(action?["type"] == "ignore-previous-rules")
    }

    @Test("ContentBlockerService parseEasyList skips comments and headers")
    func parseEasyListSkipsComments() {
        let service = ContentBlockerService()
        let rules = service.parseEasyList("[Adblock Plus]\n! This is a comment\n||ads.example.com^\n")

        #expect(rules.count == 1)
    }

    @Test("ContentBlockerService parseEasyList respects max rule cap")
    func parseEasyListRespectsCap() {
        let service = ContentBlockerService()
        var lines = ""
        for i in 0..<60000 {
            lines += "||ad\(i).example.com^\n"
        }
        let rules = service.parseEasyList(lines)

        #expect(rules.count == 50000)
    }

    private final class StubWebViewPool: WebViewPooling {
        func load(_ url: URL, in tabID: BrowserTab.ID) {}
        func remove(tabID: BrowserTab.ID) {}
        func goBack(tabID: BrowserTab.ID) {}
        func goForward(tabID: BrowserTab.ID) {}
        func reload(tabID: BrowserTab.ID) {}
        func stopLoading(tabID: BrowserTab.ID) {}
        func setZoom(_ level: Double, tabID: BrowserTab.ID) {}
        func findInPage(_ text: String, tabID: BrowserTab.ID) {}
        func findNext(tabID: BrowserTab.ID) {}
        func findPrevious(tabID: BrowserTab.ID) {}
        func clearFind(tabID: BrowserTab.ID) {}
        func printPage(tabID: BrowserTab.ID) {}
        func setMuted(_ muted: Bool, tabID: BrowserTab.ID) {}
        func toggleReaderMode(tabID: BrowserTab.ID, enable: Bool) {}
    }

    private func makeStore() -> BrowserStore {
        let theme = BrowserTheme.builtIns[0]
        let workspace = Workspace(name: "Personal", themeID: theme.id)
        let snapshot = BrowserStateSnapshot(
            schemaVersion: 3,
            activeWorkspaceID: workspace.id,
            activeTabID: nil,
            workspaces: [workspace],
            tabs: [],
            themes: BrowserTheme.builtIns
        )
        return BrowserStore(
            snapshot: snapshot,
            persistence: BrowserPersistence(applicationSupportDirectory: FileManager.default.temporaryDirectory.appending(path: "VelaContentBlockingTests-\(UUID().uuidString)", directoryHint: .isDirectory)),
            webViewPool: StubWebViewPool()
        )
    }
}
