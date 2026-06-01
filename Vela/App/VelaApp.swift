import SwiftUI

@main
struct VelaApp: App {
    @State private var store = BrowserStore.bootstrap()

    var body: some Scene {
        WindowGroup {
            MainBrowserWindow()
                .environment(store)
                .frame(minWidth: 960, minHeight: 640)
        }
        .defaultSize(width: 1200, height: 800)
        .commands {
            BrowserCommands()
        }

        // Little Vela: compact popup window for quick browsing
        WindowGroup("Little Vela", id: "little-vela") {
            LittleVelaView()
                .environment(store)
                .frame(minWidth: 400, minHeight: 300)
        }
        .defaultSize(width: 500, height: 600)
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentSize)

        // Private browsing window
        WindowGroup("Private Browsing", id: "private-window") {
            PrivateWindowView()
                .environment(store)
                .frame(minWidth: 600, minHeight: 400)
        }
        .defaultSize(width: 900, height: 700)

        Settings {
            SettingsView()
                .environment(store)
        }
    }
}
