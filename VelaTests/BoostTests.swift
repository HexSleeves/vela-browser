import Foundation
import Testing
import WebKit
@testable import Vela

@MainActor
@Suite("Boost & Zap")
struct BoostTests {
    @Test("add boost appends to boosts array")
    func addBoostAppendsToArray() {
        let store = makeStore()
        let boost = Boost(hostPattern: "example.com", css: "body { color: red; }")

        store.addBoost(boost)

        #expect(store.boosts.count == 1)
        #expect(store.boosts[0].hostPattern == "example.com")
    }

    @Test("remove boost removes by ID")
    func removeBoostRemovesByID() {
        let store = makeStore()
        let boost = Boost(hostPattern: "example.com", css: "body { color: red; }")
        store.addBoost(boost)

        store.removeBoost(boost.id)

        #expect(store.boosts.isEmpty)
    }

    @Test("toggle boost flips isEnabled")
    func toggleBoostFlipsEnabled() {
        let store = makeStore()
        let boost = Boost(hostPattern: "example.com", css: "body { color: red; }")
        store.addBoost(boost)
        #expect(store.boosts[0].isEnabled == true)

        store.toggleBoost(boost.id)

        #expect(store.boosts[0].isEnabled == false)
    }

    @Test("boostsForHost matches exact host")
    func boostsForHostMatchesExact() {
        let store = makeStore()
        store.addBoost(Boost(hostPattern: "example.com", css: "a {}"))
        store.addBoost(Boost(hostPattern: "other.com", css: "b {}"))

        let matched = store.boostsForHost("example.com")

        #expect(matched.count == 1)
        #expect(matched[0].css == "a {}")
    }

    @Test("boostsForHost matches wildcard pattern")
    func boostsForHostMatchesWildcard() {
        let store = makeStore()
        store.addBoost(Boost(hostPattern: "*.reddit.com", css: "a {}"))

        #expect(store.boostsForHost("www.reddit.com").count == 1)
        #expect(store.boostsForHost("old.reddit.com").count == 1)
        #expect(store.boostsForHost("reddit.com").count == 1)
        #expect(store.boostsForHost("noreddit.com").count == 0)
    }

    @Test("disabled boosts are excluded from boostsForHost")
    func disabledBoostsExcluded() {
        let store = makeStore()
        let boost = Boost(hostPattern: "example.com", css: "a {}", isEnabled: false)
        store.addBoost(boost)

        #expect(store.boostsForHost("example.com").isEmpty)
    }

    @Test("Boost host matching: exact match")
    func boostExactMatch() {
        let boost = Boost(hostPattern: "twitter.com", css: "")
        #expect(boost.matches(host: "twitter.com") == true)
        #expect(boost.matches(host: "www.twitter.com") == false)
    }

    @Test("Boost host matching: wildcard match")
    func boostWildcardMatch() {
        let boost = Boost(hostPattern: "*.twitter.com", css: "")
        #expect(boost.matches(host: "twitter.com") == true)
        #expect(boost.matches(host: "mobile.twitter.com") == true)
        #expect(boost.matches(host: "nottwitter.com") == false)
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
            persistence: BrowserPersistence(applicationSupportDirectory: FileManager.default.temporaryDirectory.appending(path: "VelaBoostTests-\(UUID().uuidString)", directoryHint: .isDirectory)),
            webViewPool: StubWebViewPool()
        )
    }
}
