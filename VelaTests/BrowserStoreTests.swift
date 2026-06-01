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
}
