import Foundation
import Testing
@testable import Vela

@MainActor
@Suite("BrowserStore")
struct BrowserStoreTests {
    @Test("create tab adds it to active workspace and selects it")
    func createTabAddsItToActiveWorkspaceAndSelectsIt() throws {
        let store = makeStore()

        store.createTab(url: try #require(URL(string: "https://example.com")))

        let tabID = try #require(store.activeTabID)
        #expect(store.activeWorkspace?.tabIDs == [tabID])
        #expect(store.tabs[tabID]?.url?.absoluteString == "https://example.com")
    }

    @Test("close tab removes metadata and clears active selection")
    func closeTabRemovesMetadataAndClearsSelection() throws {
        let store = makeStore()
        store.createTab(url: try #require(URL(string: "https://example.com")))
        let tabID = try #require(store.activeTabID)

        store.closeTab(tabID)

        #expect(store.tabs[tabID] == nil)
        #expect(store.activeWorkspace?.tabIDs.isEmpty == true)
        #expect(store.activeTabID == nil)
    }

    @Test("switch workspace selects first tab in that workspace")
    func switchWorkspaceSelectsFirstTabInWorkspace() throws {
        let store = makeStore()
        let secondWorkspace = Workspace(name: "Work", themeID: "forest")
        store.workspaces.append(secondWorkspace)
        store.createTab(in: secondWorkspace.id, url: try #require(URL(string: "https://example.com/work")))
        let tabID = try #require(store.activeTabID)
        store.switchWorkspace(store.workspaces[0].id)

        store.switchWorkspace(secondWorkspace.id)

        #expect(store.activeWorkspaceID == secondWorkspace.id)
        #expect(store.activeTabID == tabID)
    }

    @Test("loading address input creates a tab when no tab is active")
    func loadingAddressInputCreatesTabWhenNoTabIsActive() {
        let store = makeStore()

        store.loadAddressInput("example.com")

        let tabID = store.activeTabID
        #expect(tabID != nil)
        #expect(tabID.flatMap { store.tabs[$0]?.url?.absoluteString } == "https://example.com")
    }

    @Test("moveTab reorders unpinned tabs within the active workspace")
    func moveTabReordersUnpinnedTabs() throws {
        let store = makeStore()
        store.createTab(url: try #require(URL(string: "https://a.com")))
        store.createTab(url: try #require(URL(string: "https://b.com")))
        store.createTab(url: try #require(URL(string: "https://c.com")))

        let originalIDs = try #require(store.activeWorkspace?.tabIDs)
        #expect(originalIDs.count == 3)

        // Move first tab to last position (index 0 -> 2)
        store.moveTab(from: 0, to: 2, pinned: false)

        let reorderedIDs = try #require(store.activeWorkspace?.tabIDs)
        #expect(reorderedIDs.count == 3)
        // Original [A, B, C] -> [B, C, A]
        #expect(reorderedIDs[0] == originalIDs[1])
        #expect(reorderedIDs[1] == originalIDs[2])
        #expect(reorderedIDs[2] == originalIDs[0])
    }

    @Test("moveTab does not cross pinned/unpinned boundary")
    func moveTabRespectsSection() throws {
        let store = makeStore()
        store.createTab(url: try #require(URL(string: "https://pinned.com")), pinned: true)
        store.createTab(url: try #require(URL(string: "https://a.com")))
        store.createTab(url: try #require(URL(string: "https://b.com")))

        let originalIDs = try #require(store.activeWorkspace?.tabIDs)
        #expect(originalIDs.count == 3)

        // Move unpinned tab at section index 0 to section index 1
        store.moveTab(from: 0, to: 1, pinned: false)

        let reorderedIDs = try #require(store.activeWorkspace?.tabIDs)
        // Pinned tab stays at index 0, unpinned tabs swap
        #expect(reorderedIDs[0] == originalIDs[0]) // pinned tab untouched
        #expect(reorderedIDs[1] == originalIDs[2])
        #expect(reorderedIDs[2] == originalIDs[1])
    }

    @Test("moveTab with same from and to index is a no-op")
    func moveTabSameIndexNoOp() throws {
        let store = makeStore()
        store.createTab(url: try #require(URL(string: "https://a.com")))
        store.createTab(url: try #require(URL(string: "https://b.com")))

        let originalIDs = try #require(store.activeWorkspace?.tabIDs)

        store.moveTab(from: 0, to: 0, pinned: false)

        let afterIDs = try #require(store.activeWorkspace?.tabIDs)
        #expect(afterIDs == originalIDs)
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
            persistence: BrowserPersistence(applicationSupportDirectory: FileManager.default.temporaryDirectory.appending(path: "VelaStoreTests-\(UUID().uuidString)", directoryHint: .isDirectory)),
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
}
