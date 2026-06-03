import Foundation
import Testing
import WebKit
@testable import Vela

@MainActor
@Suite("Theme CRUD")
struct ThemeTests {
    @Test("create custom theme adds it to themes array")
    func createCustomThemeAddsToArray() {
        let store = makeStore()
        let initialCount = store.themes.count

        store.createTheme(
            name: "Custom",
            primary: .init(red: 1, green: 0, blue: 0, alpha: 1),
            secondary: .init(red: 0, green: 1, blue: 0, alpha: 1),
            accent: .init(red: 0, green: 0, blue: 1, alpha: 1)
        )

        #expect(store.themes.count == initialCount + 1)
        #expect(store.themes.last?.name == "Custom")
        #expect(store.themes.last?.isBuiltIn == false)
    }

    @Test("edit custom theme updates properties")
    func editCustomThemeUpdatesProperties() {
        let store = makeStore()
        store.createTheme(
            name: "Custom",
            primary: .init(red: 1, green: 0, blue: 0, alpha: 1),
            secondary: .init(red: 0, green: 1, blue: 0, alpha: 1),
            accent: .init(red: 0, green: 0, blue: 1, alpha: 1)
        )
        let themeID = store.themes.last!.id

        store.editTheme(
            themeID,
            name: "Renamed",
            primary: .init(red: 0.5, green: 0.5, blue: 0.5, alpha: 1),
            secondary: .init(red: 0, green: 1, blue: 0, alpha: 1),
            accent: .init(red: 0, green: 0, blue: 1, alpha: 1)
        )

        let theme = store.themes.first(where: { $0.id == themeID })
        #expect(theme?.name == "Renamed")
        #expect(theme?.primary.red == 0.5)
    }

    @Test("cannot edit built-in theme")
    func cannotEditBuiltInTheme() {
        let store = makeStore()
        let builtIn = BrowserTheme.builtIns[0]

        store.editTheme(
            builtIn.id,
            name: "Hacked",
            primary: .init(red: 1, green: 1, blue: 1, alpha: 1),
            secondary: .init(red: 1, green: 1, blue: 1, alpha: 1),
            accent: .init(red: 1, green: 1, blue: 1, alpha: 1)
        )

        #expect(store.themes.first(where: { $0.id == builtIn.id })?.name == builtIn.name)
    }

    @Test("delete custom theme removes it and reverts workspaces")
    func deleteCustomThemeRevertsWorkspaces() {
        let store = makeStore()
        store.createTheme(
            name: "Custom",
            primary: .init(red: 1, green: 0, blue: 0, alpha: 1),
            secondary: .init(red: 0, green: 1, blue: 0, alpha: 1),
            accent: .init(red: 0, green: 0, blue: 1, alpha: 1)
        )
        let themeID = store.themes.last!.id
        store.setTheme(themeID, for: store.activeWorkspaceID)
        #expect(store.activeWorkspace?.themeID == themeID)

        store.deleteTheme(themeID)

        #expect(store.themes.contains(where: { $0.id == themeID }) == false)
        #expect(store.activeWorkspace?.themeID == BrowserTheme.builtIns[0].id)
    }

    @Test("cannot delete built-in theme")
    func cannotDeleteBuiltInTheme() {
        let store = makeStore()
        let count = store.themes.count

        store.deleteTheme(BrowserTheme.builtIns[0].id)

        #expect(store.themes.count == count)
    }

    @Test("HSL conversion produces valid stops")
    func hslConversionProducesValidStops() {
        let stop = BrowserTheme.Stop.fromHSL(hue: 0.0, saturation: 1.0, lightness: 0.5)
        #expect(stop.red > 0.99)
        #expect(stop.green < 0.01)
        #expect(stop.blue < 0.01)
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
            persistence: BrowserPersistence(applicationSupportDirectory: FileManager.default.temporaryDirectory.appending(path: "VelaThemeTests-\(UUID().uuidString)", directoryHint: .isDirectory)),
            webViewPool: StubWebViewPool()
        )
    }
}
