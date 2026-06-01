import Foundation
import Testing
@testable import Vela

@Suite("BrowserPersistence")
struct BrowserPersistenceTests {
    @Test("saves and loads a browser state snapshot")
    func savesAndLoadsSnapshot() throws {
        let directory = temporaryDirectory()
        let persistence = BrowserPersistence(applicationSupportDirectory: directory)
        let theme = BrowserTheme.builtIns[0]
        let tab = BrowserTab(title: "Example", url: URL(string: "https://example.com")!)
        let workspace = Workspace(name: "Research", themeID: theme.id, tabIDs: [tab.id])
        let snapshot = BrowserStateSnapshot(
            schemaVersion: 1,
            activeWorkspaceID: workspace.id,
            activeTabID: tab.id,
            workspaces: [workspace],
            tabs: [tab],
            themes: BrowserTheme.builtIns
        )

        try persistence.save(snapshot)
        let loaded = try persistence.load()

        #expect(loaded == snapshot)
    }

    @Test("missing state file returns nil")
    func missingStateFileReturnsNil() throws {
        let persistence = BrowserPersistence(applicationSupportDirectory: temporaryDirectory())

        let loaded = try persistence.load()

        #expect(loaded == nil)
    }

    private func temporaryDirectory() -> URL {
        FileManager.default.temporaryDirectory
            .appending(path: "VelaTests-\(UUID().uuidString)", directoryHint: .isDirectory)
    }
}
