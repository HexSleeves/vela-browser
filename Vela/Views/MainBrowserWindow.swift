import SwiftUI
import UniformTypeIdentifiers

struct MainBrowserWindow: View {
    @Environment(BrowserStore.self) private var store
    @Environment(\.openWindow) private var openWindow
    @FocusState private var isAddressFocused: Bool
    @State private var addressText = ""
    @State private var sidebarWidth: CGFloat = 280
    @State private var isDraggingSidebar = false
    @State private var dragStartWidth: CGFloat = 280

    var body: some View {
        HStack(spacing: 0) {
            SidebarView()
                .frame(width: store.isSidebarCollapsed ? 64 : sidebarWidth)
                .animation(VelaAnimation.layout, value: store.isSidebarCollapsed)

            // Drag handle for sidebar resize
            if !store.isSidebarCollapsed {
                Rectangle()
                    .fill(isDraggingSidebar ? Color.accentColor.opacity(0.5) : Color.clear)
                    .frame(width: 4)
                    .contentShape(Rectangle().inset(by: -2))
                    .onHover { hovering in
                        if hovering {
                            NSCursor.resizeLeftRight.push()
                        } else {
                            NSCursor.pop()
                        }
                    }
                    .gesture(
                        DragGesture(minimumDistance: 1)
                            .onChanged { value in
                                if !isDraggingSidebar {
                                    isDraggingSidebar = true
                                    dragStartWidth = sidebarWidth
                                }
                                let newWidth = dragStartWidth + value.translation.width
                                sidebarWidth = min(max(newWidth, 200), 400)
                            }
                            .onEnded { _ in
                                isDraggingSidebar = false
                            }
                    )
            } else {
                Divider()
            }

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
            get: { store.isLibraryVisible },
            set: { store.isLibraryVisible = $0 }
        )) {
            LibraryView()
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
        .onChange(of: store.pendingCommand) { _, command in
            guard let command else { return }
            store.pendingCommand = nil
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
            store.isLibraryVisible.toggle()

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

        case .openLittleVela:
            openWindow(id: "little-vela")

        case .openPrivateWindow:
            openWindow(id: "private-window")

        case .importBookmarks:
            importBookmarks()
        }
    }

    private func importBookmarks() {
        let panel = NSOpenPanel()
        panel.title = "Import Bookmarks"
        panel.allowedContentTypes = [.html, .text]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false

        guard panel.runModal() == .OK, let url = panel.url else { return }

        do {
            let count = try store.importBookmarks(from: url)
            let alert = NSAlert()
            alert.messageText = "Bookmarks Imported"
            alert.informativeText = count == 0 ? "No new bookmarks were found." : "Imported \(count) new bookmark\(count == 1 ? "" : "s")."
            alert.addButton(withTitle: "OK")
            alert.runModal()
        } catch {
            let alert = NSAlert(error: error)
            alert.messageText = "Import Failed"
            alert.runModal()
        }
    }
}
