import SwiftUI

struct MainBrowserWindow: View {
    @Environment(BrowserStore.self) private var store
    @FocusState private var isAddressFocused: Bool
    @State private var addressText = ""

    var body: some View {
        HStack(spacing: 0) {
            SidebarView()
                .frame(width: store.isSidebarCollapsed ? 64 : 280)
                .animation(VelaAnimation.layout, value: store.isSidebarCollapsed)

            Divider()

            BrowserSurfaceView(addressText: $addressText, isAddressFocused: $isAddressFocused)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background(.regularMaterial)
        .focusedValue(\.browserCommandSink) { command in
            handle(command)
        }
    }

    private func handle(_ command: BrowserCommand) {
        switch command {
        case .newTab:
            VelaAnimation.withEmphasis {
                store.createTab()
            }
            addressText = ""
            isAddressFocused = true
        case .focusAddressBar:
            addressText = store.activeTab?.url?.absoluteString ?? ""
            isAddressFocused = true
        case .toggleSidebar:
            VelaAnimation.withLayout {
                store.isSidebarCollapsed.toggle()
            }
        }
    }
}
