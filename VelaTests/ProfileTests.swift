import Foundation
import Testing
@testable import Vela

@MainActor
@Suite("Profiles")
struct ProfileTests {
    @Test("default profile has nil dataStoreIdentifier")
    func defaultProfileHasNilDataStoreIdentifier() {
        let profile = Profile.makeDefault()
        #expect(profile.dataStoreIdentifier == nil)
        #expect(profile.name == "Default")
    }

    @Test("createProfile adds to profiles array")
    func createProfileAddsToArray() {
        let store = makeStore()
        let initialCount = store.profiles.count

        store.createProfile(name: "Work")

        #expect(store.profiles.count == initialCount + 1)
        #expect(store.profiles.last?.name == "Work")
        #expect(store.profiles.last?.dataStoreIdentifier != nil)
    }

    @Test("renameProfile updates name")
    func renameProfileUpdatesName() {
        let store = makeStore()
        store.createProfile(name: "Work")
        let profileID = store.profiles.last!.id

        store.renameProfile(profileID, name: "Office")

        #expect(store.profiles.first(where: { $0.id == profileID })?.name == "Office")
    }

    @Test("deleteProfile removes and reverts workspaces")
    func deleteProfileRemovesAndRevertsWorkspaces() {
        let store = makeStore()
        store.createProfile(name: "Work")
        let profileID = store.profiles.last!.id

        // Assign profile to a workspace
        let workspaceID = store.activeWorkspaceID
        store.assignProfile(profileID, to: workspaceID)
        #expect(store.workspaces.first(where: { $0.id == workspaceID })?.profileID == profileID)

        store.deleteProfile(profileID)

        #expect(!store.profiles.contains(where: { $0.id == profileID }))
        #expect(store.workspaces.first(where: { $0.id == workspaceID })?.profileID == nil)
    }

    @Test("deleteProfile guards against deleting default profile")
    func deleteProfileGuardsDefaultProfile() {
        let store = makeStore()
        let defaultProfile = store.defaultProfile
        let initialCount = store.profiles.count

        // Add a second profile so guard against count > 1 doesn't trigger
        store.createProfile(name: "Extra")

        store.deleteProfile(defaultProfile.id)

        #expect(store.profiles.contains(where: { $0.id == defaultProfile.id }))
        #expect(store.profiles.count == initialCount + 1)
    }

    @Test("deleteProfile guards against deleting last profile")
    func deleteProfileGuardsLastProfile() {
        let store = makeStore()
        #expect(store.profiles.count == 1)
        let onlyProfileID = store.profiles[0].id

        store.deleteProfile(onlyProfileID)

        #expect(store.profiles.count == 1)
    }

    @Test("profileForWorkspace returns correct profile")
    func profileForWorkspaceReturnsCorrectProfile() {
        let store = makeStore()
        store.createProfile(name: "Work")
        let workProfile = store.profiles.last!
        let workspaceID = store.activeWorkspaceID

        store.assignProfile(workProfile.id, to: workspaceID)

        let result = store.profileForWorkspace(workspaceID)
        #expect(result.id == workProfile.id)
        #expect(result.name == "Work")
    }

    @Test("profileForWorkspace returns default when workspace has no profileID")
    func profileForWorkspaceReturnsDefaultWhenNoProfileID() {
        let store = makeStore()
        let workspaceID = store.activeWorkspaceID

        let result = store.profileForWorkspace(workspaceID)
        #expect(result.dataStoreIdentifier == nil)
        #expect(result.name == "Default")
    }

    @Test("assignProfile updates workspace profileID")
    func assignProfileUpdatesWorkspaceProfileID() {
        let store = makeStore()
        store.createProfile(name: "Work")
        let profileID = store.profiles.last!.id
        let workspaceID = store.activeWorkspaceID

        store.assignProfile(profileID, to: workspaceID)

        #expect(store.workspaces.first(where: { $0.id == workspaceID })?.profileID == profileID)
    }

    @Test("assignProfile removes web views when profile changes")
    func assignProfileRemovesWebViewsOnChange() throws {
        let store = makeStore()
        let pool = store.webViewPool as! StubWebViewPool
        store.createTab(url: try #require(URL(string: "https://example.com")))
        let tabID = try #require(store.activeTabID)
        store.createProfile(name: "Work")
        let profileID = store.profiles.last!.id

        store.assignProfile(profileID, to: store.activeWorkspaceID)

        #expect(pool.removedTabIDs.contains(tabID))
    }

    @Test("v2 snapshot without profiles or profileID loads with defaults")
    func v2SnapshotLoadsWithDefaults() throws {
        let workspaceID = UUID()
        let themeID = BrowserTheme.builtIns[0].id
        let json = """
        {
            "schemaVersion": 2,
            "activeWorkspaceID": "\(workspaceID.uuidString)",
            "activeTabID": null,
            "workspaces": [
                {
                    "id": "\(workspaceID.uuidString)",
                    "name": "Personal",
                    "themeID": "\(themeID)",
                    "tabIDs": [],
                    "archivedTabIDs": []
                }
            ],
            "tabs": [],
            "themes": [],
            "tabGroups": [],
            "favoriteTabIDs": []
        }
        """

        let data = try #require(json.data(using: .utf8))
        let snapshot = try JSONDecoder().decode(BrowserStateSnapshot.self, from: data)

        #expect(snapshot.profiles.count == 1)
        #expect(snapshot.profiles[0].name == "Default")
        #expect(snapshot.profiles[0].dataStoreIdentifier == nil)
        #expect(snapshot.workspaces[0].profileID == nil)
    }

    @Test("Profile Codable round-trip preserves all fields")
    func profileCodableRoundTrip() throws {
        let original = Profile(name: "Test Profile")
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(Profile.self, from: data)

        #expect(decoded == original)
        #expect(decoded.id == original.id)
        #expect(decoded.name == original.name)
        #expect(decoded.dataStoreIdentifier == original.dataStoreIdentifier)
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
            persistence: BrowserPersistence(applicationSupportDirectory: FileManager.default.temporaryDirectory.appending(path: "VelaProfileTests-\(UUID().uuidString)", directoryHint: .isDirectory)),
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
