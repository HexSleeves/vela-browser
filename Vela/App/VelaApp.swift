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
        .commands {
            BrowserCommands()
        }

        Settings {
            SettingsView()
                .environment(store)
        }
    }
}
