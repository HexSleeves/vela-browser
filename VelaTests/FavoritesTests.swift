import Foundation
import Testing
@testable import Vela

@MainActor
@Suite("Favorites")
struct FavoritesTests {
    @Test("addFavorite adds tab ID to favoriteTabIDs")
    func addFavoriteAddsTabID() throws {
        let store = makeStore()
        store.createTab(url: try #require(URL(string: "https://example.com")))
        let tabID = try #require(store.activeTabID)

        store.addFavorite(tabID)

        #expect(store.favoriteTabIDs == [tabID])
    }

    @Test("addFavorite is a no-op for non-existent tab ID")
    func addFavoriteNoOpForNonExistent() {
        let store = makeStore()
        let fakeID = UUID()

        store.addFavorite(fakeID)

        #expect(store.favoriteTabIDs.isEmpty)
    }

    @Test("addFavorite is a no-op for already-favorited tab")
    func addFavoriteNoOpForDuplicate() throws {
        let store = makeStore()
        store.createTab(url: try #require(URL(string: "https://example.com")))
        let tabID = try #require(store.activeTabID)

        store.addFavorite(tabID)
        store.addFavorite(tabID)

        #expect(store.favoriteTabIDs == [tabID])
    }

    @Test("addFavorite caps at 8 favorites")
    func addFavoriteCapsAtEight() throws {
        let store = makeStore()
        var tabIDs: [BrowserTab.ID] = []

        for i in 0..<9 {
            store.createTab(url: try #require(URL(string: "https://site\(i).com")))
            let tabID = try #require(store.activeTabID)
            tabIDs.append(tabID)
            store.addFavorite(tabID)
        }

        #expect(store.favoriteTabIDs.count == 8)
        #expect(!store.favoriteTabIDs.contains(tabIDs[8]))
    }

    @Test("removeFavorite removes the tab ID")
    func removeFavoriteRemovesTabID() throws {
        let store = makeStore()
        store.createTab(url: try #require(URL(string: "https://example.com")))
        let tabID = try #require(store.activeTabID)
        store.addFavorite(tabID)

        store.removeFavorite(tabID)

        #expect(store.favoriteTabIDs.isEmpty)
    }

    @Test("removeFavorite is a no-op for non-favorite tab")
    func removeFavoriteNoOpForNonFavorite() throws {
        let store = makeStore()
        store.createTab(url: try #require(URL(string: "https://example.com")))
        let tabID = try #require(store.activeTabID)

        store.removeFavorite(tabID)

        #expect(store.favoriteTabIDs.isEmpty)
    }

    @Test("reorderFavorites swaps positions correctly")
    func reorderFavoritesSwaps() throws {
        let store = makeStore()
        var tabIDs: [BrowserTab.ID] = []
        for i in 0..<3 {
            store.createTab(url: try #require(URL(string: "https://site\(i).com")))
            let tabID = try #require(store.activeTabID)
            tabIDs.append(tabID)
            store.addFavorite(tabID)
        }

        store.reorderFavorites(from: 0, to: 2)

        #expect(store.favoriteTabIDs == [tabIDs[1], tabIDs[2], tabIDs[0]])
    }

    @Test("isFavorite returns true for favorite, false for non-favorite")
    func isFavoriteReturnsCorrectBool() throws {
        let store = makeStore()
        store.createTab(url: try #require(URL(string: "https://fav.com")))
        let favID = try #require(store.activeTabID)
        store.createTab(url: try #require(URL(string: "https://nonfav.com")))
        let nonFavID = try #require(store.activeTabID)

        store.addFavorite(favID)

        #expect(store.isFavorite(favID))
        #expect(!store.isFavorite(nonFavID))
    }

    @Test("closeTab auto-removes from favoriteTabIDs")
    func closeTabAutoRemovesFavorite() throws {
        let store = makeStore()
        store.createTab(url: try #require(URL(string: "https://example.com")))
        let tabID = try #require(store.activeTabID)
        store.addFavorite(tabID)

        store.closeTab(tabID)

        #expect(store.favoriteTabIDs.isEmpty)
    }

    @Test("favoriteTabsWithWorkspace resolves correct workspace for each tab")
    func favoriteTabsWithWorkspaceResolvesCorrectly() throws {
        let store = makeStore()
        let ws1ID = store.activeWorkspaceID
        store.createTab(url: try #require(URL(string: "https://ws1.com")))
        let tab1ID = try #require(store.activeTabID)

        store.createWorkspace(name: "Work")
        let ws2ID = store.activeWorkspaceID
        store.createTab(url: try #require(URL(string: "https://ws2.com")))
        let tab2ID = try #require(store.activeTabID)

        store.addFavorite(tab1ID)
        store.addFavorite(tab2ID)

        let resolved = store.favoriteTabsWithWorkspace
        #expect(resolved.count == 2)
        #expect(resolved[0].tab.id == tab1ID)
        #expect(resolved[0].workspaceID == ws1ID)
        #expect(resolved[1].tab.id == tab2ID)
        #expect(resolved[1].workspaceID == ws2ID)
    }

    @Test("v1 snapshot without favoriteTabIDs loads with empty array")
    func v1SnapshotMigration() throws {
        let theme = BrowserTheme.builtIns[0]
        let workspace = Workspace(name: "Test", themeID: theme.id)

        let v1JSON: [String: Any] = [
            "schemaVersion": 1,
            "activeWorkspaceID": workspace.id.uuidString,
            "workspaces": [
                ["id": workspace.id.uuidString, "name": "Test", "themeID": theme.id, "tabIDs": [], "archivedTabIDs": []]
            ],
            "tabs": [],
            "themes": [],
            "tabGroups": []
        ]

        let data = try JSONSerialization.data(withJSONObject: v1JSON)
        let snapshot = try JSONDecoder().decode(BrowserStateSnapshot.self, from: data)

        #expect(snapshot.favoriteTabIDs.isEmpty)
    }

    private func makeStore() -> BrowserStore {
        let theme = BrowserTheme.builtIns[0]
        let workspace = Workspace(name: "Personal", themeID: theme.id)
        let snapshot = BrowserStateSnapshot(
            schemaVersion: 2,
            activeWorkspaceID: workspace.id,
            activeTabID: nil,
            workspaces: [workspace],
            tabs: [],
            themes: BrowserTheme.builtIns
        )
        return BrowserStore(
            snapshot: snapshot,
            persistence: BrowserPersistence(applicationSupportDirectory: FileManager.default.temporaryDirectory.appending(path: "VelaFavTests-\(UUID().uuidString)", directoryHint: .isDirectory)),
            webViewPool: StubWebViewPool()
        )
    }
}

@MainActor
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
