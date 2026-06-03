import Foundation
import Testing
@testable import Vela

@MainActor
@Suite("Extensions")
struct ExtensionTests {

    @Test("InstalledExtension encode/decode round-trip")
    func installedExtensionRoundTrip() throws {
        let original = InstalledExtension(
            name: "Test Extension",
            version: "1.2.3",
            extensionBundlePath: "Extensions/test-extension",
            isEnabled: true,
            allowInPrivateBrowsing: false,
            grantedPermissions: ["storage"],
            deniedPermissions: ["tabs"]
        )

        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(InstalledExtension.self, from: data)

        #expect(decoded.name == original.name)
        #expect(decoded.version == original.version)
        #expect(decoded.extensionBundlePath == original.extensionBundlePath)
        #expect(decoded.isEnabled == original.isEnabled)
        #expect(decoded.allowInPrivateBrowsing == original.allowInPrivateBrowsing)
        #expect(decoded.grantedPermissions == original.grantedPermissions)
        #expect(decoded.deniedPermissions == original.deniedPermissions)
    }

    @Test("InstalledExtension decoder uses safe defaults for missing fields")
    func installedExtensionDecoderDefaults() throws {
        let json = #"{"id":"A1B2C3D4-E5F6-7890-ABCD-EF1234567890"}"#
        let data = Data(json.utf8)
        let decoded = try JSONDecoder().decode(InstalledExtension.self, from: data)

        #expect(decoded.name == "Unknown")
        #expect(decoded.version == "0.0.0")
        #expect(decoded.extensionBundlePath == "")
        #expect(decoded.isEnabled == true)
        #expect(decoded.allowInPrivateBrowsing == false)
        #expect(decoded.grantedPermissions.isEmpty)
        #expect(decoded.deniedPermissions.isEmpty)
    }

    @Test("removeExtension removes from array")
    func removeExtensionRemoves() {
        let store = makeStore()
        let ext = InstalledExtension(
            name: "Test",
            version: "1.0",
            extensionBundlePath: "Extensions/test"
        )
        store.installedExtensions.append(ext)

        store.removeExtension(id: ext.id)

        #expect(store.installedExtensions.isEmpty)
    }

    @Test("toggleExtension flips isEnabled")
    func toggleExtensionFlips() {
        let store = makeStore()
        let ext = InstalledExtension(
            name: "Test",
            version: "1.0",
            extensionBundlePath: "Extensions/test"
        )
        store.installedExtensions.append(ext)
        #expect(store.installedExtensions[0].isEnabled == true)

        store.toggleExtension(ext.id)

        #expect(store.installedExtensions[0].isEnabled == false)
    }

    @Test("setExtensionPrivateBrowsing updates flag")
    func setPrivateBrowsing() {
        let store = makeStore()
        let ext = InstalledExtension(
            name: "Test",
            version: "1.0",
            extensionBundlePath: "Extensions/test"
        )
        store.installedExtensions.append(ext)
        #expect(store.installedExtensions[0].allowInPrivateBrowsing == false)

        store.setExtensionPrivateBrowsing(ext.id, allowed: true)

        #expect(store.installedExtensions[0].allowInPrivateBrowsing == true)
    }

    @Test("InstalledExtension array encode/decode round-trip")
    func installedExtensionArrayRoundTrip() throws {
        let extensions = [
            InstalledExtension(name: "Ext A", version: "1.0", extensionBundlePath: "Extensions/a"),
            InstalledExtension(name: "Ext B", version: "2.0", extensionBundlePath: "Extensions/b", isEnabled: false),
        ]

        let data = try JSONEncoder().encode(extensions)
        let decoded = try JSONDecoder().decode([InstalledExtension].self, from: data)

        #expect(decoded.count == 2)
        #expect(decoded[0].name == "Ext A")
        #expect(decoded[1].isEnabled == false)
    }

    // MARK: - Helpers

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
            persistence: BrowserPersistence(applicationSupportDirectory: FileManager.default.temporaryDirectory.appending(path: "VelaExtTests-\(UUID().uuidString)", directoryHint: .isDirectory)),
            webViewPool: StubWebViewPool()
        )
    }
}
