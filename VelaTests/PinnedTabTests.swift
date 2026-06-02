import Foundation
import Testing
@testable import Vela

@MainActor
@Suite("Pinned Tab Designated URL")
struct PinnedTabTests {
    @Test("setDesignatedURL sets the URL on the tab")
    func setDesignatedURLSetsURL() throws {
        let store = makeStore()
        let url = try #require(URL(string: "https://example.com"))
        store.createTab(url: url, pinned: true)
        let tabID = try #require(store.activeTabID)

        let designatedURL = try #require(URL(string: "https://designated.example.com"))
        store.setDesignatedURL(designatedURL, for: tabID)

        #expect(store.tabs[tabID]?.designatedURL == designatedURL)
    }

    @Test("clearDesignatedURL removes it and clears isStub")
    func clearDesignatedURLRemovesAndClearsStub() throws {
        let store = makeStore()
        let url = try #require(URL(string: "https://example.com"))
        store.createTab(url: url, pinned: true)
        let tabID = try #require(store.activeTabID)

        let designatedURL = try #require(URL(string: "https://designated.example.com"))
        store.setDesignatedURL(designatedURL, for: tabID)
        store.tabs[tabID]?.isStub = true

        store.clearDesignatedURL(for: tabID)

        #expect(store.tabs[tabID]?.designatedURL == nil)
        #expect(store.tabs[tabID]?.isStub == false)
    }

    @Test("resetToDesignatedURL navigates tab back to designated URL")
    func resetToDesignatedURLNavigates() throws {
        let store = makeStore()
        let pool = store.webViewPool as? StubWebViewPool
        let url = try #require(URL(string: "https://example.com"))
        store.createTab(url: url, pinned: true)
        let tabID = try #require(store.activeTabID)

        let designatedURL = try #require(URL(string: "https://designated.example.com"))
        store.setDesignatedURL(designatedURL, for: tabID)

        // Navigate away
        store.tabs[tabID]?.url = try #require(URL(string: "https://other.com"))
        store.tabs[tabID]?.isStub = true

        store.resetToDesignatedURL(tabID)

        #expect(store.tabs[tabID]?.url == designatedURL)
        #expect(store.tabs[tabID]?.isStub == false)
        #expect(store.tabs[tabID]?.title == "designated.example.com")
        #expect(pool?.loadedURLs[tabID] == designatedURL)
    }

    @Test("isPinnedWithDesignatedURL returns true for pinned tab with designatedURL")
    func isPinnedWithDesignatedURLTrueForPinned() throws {
        let store = makeStore()
        let url = try #require(URL(string: "https://example.com"))
        store.createTab(url: url, pinned: true)
        let tabID = try #require(store.activeTabID)

        let designatedURL = try #require(URL(string: "https://designated.example.com"))
        store.setDesignatedURL(designatedURL, for: tabID)

        #expect(store.isPinnedWithDesignatedURL(tabID) == true)
    }

    @Test("isPinnedWithDesignatedURL returns false for unpinned tab with designatedURL")
    func isPinnedWithDesignatedURLFalseForUnpinned() throws {
        let store = makeStore()
        let url = try #require(URL(string: "https://example.com"))
        store.createTab(url: url)
        let tabID = try #require(store.activeTabID)

        let designatedURL = try #require(URL(string: "https://designated.example.com"))
        store.setDesignatedURL(designatedURL, for: tabID)

        #expect(store.isPinnedWithDesignatedURL(tabID) == false)
    }

    @Test("closeTab on pinned tab with designatedURL creates stub")
    func closeTabOnPinnedWithDesignatedURLCreatesStub() throws {
        let store = makeStore()
        let pool = store.webViewPool as? StubWebViewPool
        let url = try #require(URL(string: "https://example.com"))
        store.createTab(url: url, pinned: true)
        let tabID = try #require(store.activeTabID)

        let designatedURL = try #require(URL(string: "https://designated.example.com"))
        store.setDesignatedURL(designatedURL, for: tabID)

        store.closeTab(tabID)

        #expect(store.tabs[tabID]?.isStub == true)
        #expect(store.activeWorkspace?.tabIDs.contains(tabID) == true)
        #expect(pool?.removedTabIDs.contains(tabID) == true)
    }

    @Test("closeTab on regular pinned tab without designatedURL removes normally")
    func closeTabOnRegularPinnedTabRemovesNormally() throws {
        let store = makeStore()
        let url = try #require(URL(string: "https://example.com"))
        store.createTab(url: url, pinned: true)
        let tabID = try #require(store.activeTabID)

        store.closeTab(tabID)

        #expect(store.tabs[tabID] == nil)
        #expect(store.activeWorkspace?.tabIDs.contains(tabID) == false)
    }

    @Test("selectTab on stub reactivates it")
    func selectTabOnStubReactivates() throws {
        let store = makeStore()
        let pool = store.webViewPool as? StubWebViewPool
        let url = try #require(URL(string: "https://example.com"))
        store.createTab(url: url, pinned: true)
        let tabID = try #require(store.activeTabID)

        let designatedURL = try #require(URL(string: "https://designated.example.com"))
        store.setDesignatedURL(designatedURL, for: tabID)

        // Create another tab and make stub
        store.createTab(url: try #require(URL(string: "https://other.com")))
        store.tabs[tabID]?.isStub = true

        store.selectTab(tabID)

        #expect(store.tabs[tabID]?.isStub == false)
        #expect(store.activeTabID == tabID)
        #expect(pool?.loadedURLs[tabID] == designatedURL)
    }

    @Test("BrowserTab Codable round-trip with designatedURL and isStub")
    func codableRoundTrip() throws {
        let designatedURL = try #require(URL(string: "https://designated.example.com"))
        let tab = BrowserTab(
            title: "Test",
            url: try #require(URL(string: "https://example.com")),
            isPinned: true,
            designatedURL: designatedURL,
            isStub: true
        )

        let encoder = JSONEncoder()
        let data = try encoder.encode(tab)
        let decoder = JSONDecoder()
        let decoded = try decoder.decode(BrowserTab.self, from: data)

        #expect(decoded.id == tab.id)
        #expect(decoded.title == tab.title)
        #expect(decoded.url == tab.url)
        #expect(decoded.isPinned == tab.isPinned)
        #expect(decoded.designatedURL == designatedURL)
        #expect(decoded.isStub == true)
    }

    @Test("Old BrowserTab JSON without designatedURL/isStub decodes with defaults")
    func oldJSONDecodesWithDefaults() throws {
        // Simulate old JSON without designatedURL and isStub fields
        let oldJSON = """
        {
            "id": "12345678-1234-1234-1234-123456789ABC",
            "title": "Old Tab",
            "url": "https://example.com",
            "isPinned": false,
            "isLoading": false,
            "estimatedProgress": 0.0,
            "canGoBack": false,
            "canGoForward": false,
            "zoomLevel": 1.0,
            "isPlayingAudio": false,
            "isMuted": false,
            "isReaderMode": false,
            "lastAccessedAt": 0.0
        }
        """

        let data = try #require(oldJSON.data(using: .utf8))
        let decoder = JSONDecoder()
        let tab = try decoder.decode(BrowserTab.self, from: data)

        #expect(tab.designatedURL == nil)
        #expect(tab.isStub == false)
        #expect(tab.title == "Old Tab")
    }

    private func makeStore() -> BrowserStore {
        let theme = BrowserTheme.builtIns[0]
        let workspace = Workspace(name: "Personal", themeID: theme.id)
        let snapshot = BrowserStateSnapshot(
            schemaVersion: 1,
            activeWorkspaceID: workspace.id,
            activeTabID: nil,
            workspaces: [workspace],
            tabs: [],
            themes: BrowserTheme.builtIns
        )
        return BrowserStore(
            snapshot: snapshot,
            persistence: BrowserPersistence(applicationSupportDirectory: FileManager.default.temporaryDirectory.appending(path: "VelaPinnedTabTests-\(UUID().uuidString)", directoryHint: .isDirectory)),
            webViewPool: StubWebViewPool()
        )
    }
}

@MainActor
private final class StubWebViewPool: WebViewPooling {
    private(set) var loadedURLs: [BrowserTab.ID: URL] = [:]
    private(set) var removedTabIDs: [BrowserTab.ID] = []

    func load(_ url: URL, in tabID: BrowserTab.ID) {
        loadedURLs[tabID] = url
    }

    func remove(tabID: BrowserTab.ID) {
        removedTabIDs.append(tabID)
    }

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
