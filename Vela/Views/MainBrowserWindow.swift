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
        .overlay {
            if store.isCommandBarVisible {
                CommandBarOverlay()
                    .transition(.opacity.combined(with: .scale(scale: 0.95)))
            }
        }
        .animation(VelaAnimation.emphasis, value: store.isCommandBarVisible)
        .sheet(isPresented: Binding(
            get: { store.isHistoryVisible },
            set: { store.isHistoryVisible = $0 }
        )) {
            HistoryView()
        }
        .sheet(isPresented: Binding(
            get: { store.isBoostEditorVisible },
            set: { store.isBoostEditorVisible = $0 }
        )) {
            BoostEditorView()
        }
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

        case .closeTab:
            guard let tabID = store.activeTabID else { return }
            VelaAnimation.withEmphasis {
                store.closeTab(tabID)
            }
            addressText = store.activeTab?.url?.absoluteString ?? ""

        case .focusAddressBar:
            addressText = store.activeTab?.url?.absoluteString ?? ""
            isAddressFocused = true

        case .toggleSidebar:
            VelaAnimation.withLayout {
                store.isSidebarCollapsed.toggle()
            }

        case .goBack:
            store.goBack()

        case .goForward:
            store.goForward()

        case .reload:
            store.reload()

        case .zoomIn:
            store.zoomIn()

        case .zoomOut:
            store.zoomOut()

        case .zoomReset:
            store.zoomReset()

        case .selectTabByIndex(let index):
            store.selectTabByIndex(index)
            addressText = store.activeTab?.url?.absoluteString ?? ""

        case .toggleFind:
            VelaAnimation.withMicro {
                store.toggleFindBar()
            }

        case .findNext:
            store.findNext()

        case .findPrevious:
            store.findPrevious()

        case .printPage:
            store.printPage()

        case .toggleCommandBar:
            VelaAnimation.withEmphasis {
                store.isCommandBarVisible.toggle()
            }

        case .undoCloseTab:
            VelaAnimation.withEmphasis {
                store.undoCloseTab()
            }
            addressText = store.activeTab?.url?.absoluteString ?? ""

        case .showHistory:
            store.isHistoryVisible.toggle()

        case .toggleSplit:
            VelaAnimation.withLayout {
                if store.splitTabID != nil {
                    store.closeSplit()
                } else if let tabID = store.activeTabID {
                    // Open split with a new tab
                    let tab = BrowserTab(url: nil)
                    store.tabs[tab.id] = tab
                    if let wsIndex = store.workspaces.firstIndex(where: { $0.id == store.activeWorkspaceID }) {
                        store.workspaces[wsIndex].tabIDs.append(tab.id)
                    }
                    store.splitTabID = tab.id
                }
            }
        }
    }
}
