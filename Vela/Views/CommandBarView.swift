import SwiftUI

/// Full-screen overlay that dims the background and hosts the command bar.
struct CommandBarOverlay: View {
    @Environment(BrowserStore.self) private var store

    var body: some View {
        ZStack {
            Color.black.opacity(0.3)
                .ignoresSafeArea()
                .onTapGesture {
                    dismiss()
                }

            CommandBarView()
                .frame(maxWidth: 560)
                .padding(.bottom, 200)
        }
    }

    private func dismiss() {
        VelaAnimation.withEmphasis {
            store.isCommandBarVisible = false
        }
    }
}

struct CommandBarView: View {
    @Environment(BrowserStore.self) private var store
    @State private var query = ""
    @State private var selectedIndex = 0
    @FocusState private var isFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)

                TextField("Search tabs, actions, or the web…", text: $query)
                    .textFieldStyle(.plain)
                    .font(.title3)
                    .focused($isFocused)
                    .onSubmit {
                        submitSelection()
                    }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)

            if !results.isEmpty {
                Divider()

                ScrollView {
                    VStack(spacing: 2) {
                        ForEach(Array(results.enumerated()), id: \.element.id) { index, result in
                            CommandBarRow(result: result, isSelected: index == selectedIndex)
                                .onTapGesture {
                                    selectResult(result)
                                }
                        }
                    }
                    .padding(6)
                }
                .frame(maxHeight: 360)
            }
        }
        .background(.ultraThickMaterial, in: RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.25), radius: 20, y: 8)
        .onAppear {
            isFocused = true
            query = ""
            selectedIndex = 0
        }
        .onKeyPress(.escape) {
            dismiss()
            return .handled
        }
        .onKeyPress(.downArrow) {
            if selectedIndex < results.count - 1 { selectedIndex += 1 }
            return .handled
        }
        .onKeyPress(.upArrow) {
            if selectedIndex > 0 { selectedIndex -= 1 }
            return .handled
        }
        .onChange(of: query) {
            selectedIndex = 0
        }
    }

    // MARK: - Combined Results

    private var results: [CommandBarResult] {
        let actionResults = filteredActions.map { CommandBarResult.action($0) }
        let tabResults = filteredTabs.map { CommandBarResult.tab($0) }
        let bookmarkResults = filteredBookmarks.map { CommandBarResult.bookmark($0) }
        let historyResults = filteredHistory.map { CommandBarResult.history($0) }

        var combined = actionResults + tabResults + bookmarkResults + historyResults

        if !query.isEmpty {
            if let urlAction = urlNavigationAction {
                combined.insert(.action(urlAction), at: 0)
            }

            if combined.isEmpty || !combined.contains(where: { if case .action = $0 { return true }; return false }) {
                combined.append(.action(webSearchAction))
            }
        }

        return Array(combined.prefix(14))
    }

    // MARK: - URL Navigation

    private var urlNavigationAction: CommandAction? {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        guard trimmed.contains(".") && !trimmed.contains(" ") else { return nil }
        let url = trimmed.contains("://") ? trimmed : "https://\(trimmed)"
        return CommandAction(id: "navigate-url", title: "Navigate to \(url)", icon: "globe", shortcut: nil) { [store] in
            store.loadAddressInput(trimmed)
        }
    }

    private var webSearchAction: CommandAction {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        return CommandAction(id: "web-search", title: "Search the web for \"\(trimmed)\"", icon: "magnifyingglass", shortcut: nil) { [store] in
            store.loadAddressInput(trimmed)
        }
    }

    // MARK: - Actions (30+)

    private var filteredActions: [CommandAction] {
        guard !query.isEmpty else { return [] }
        let lowered = query.lowercased()
        return allActions.filter { $0.title.lowercased().contains(lowered) }
    }

    private var allActions: [CommandAction] {
        var actions: [CommandAction] = [
            // Navigation
            CommandAction(id: "back", title: "Go Back", icon: "chevron.left", shortcut: "⌘[") { [store] in
                store.goBack()
            },
            CommandAction(id: "forward", title: "Go Forward", icon: "chevron.right", shortcut: "⌘]") { [store] in
                store.goForward()
            },
            CommandAction(id: "reload", title: "Reload Page", icon: "arrow.clockwise", shortcut: "⌘R") { [store] in
                store.reload()
            },

            // Tab management
            CommandAction(id: "new-tab", title: "New Tab", icon: "plus", shortcut: "⌘T") { [store] in
                store.createTab()
            },
            CommandAction(id: "close-tab", title: "Close Tab", icon: "xmark", shortcut: "⌘W") { [store] in
                if let tabID = store.activeTabID {
                    store.closeTab(tabID)
                }
            },
            CommandAction(id: "undo-close", title: "Undo Close Tab", icon: "arrow.uturn.left", shortcut: "⌘Z") { [store] in
                store.undoCloseTab()
            },

            // Zoom
            CommandAction(id: "zoom-in", title: "Zoom In", icon: "plus.magnifyingglass", shortcut: "⌘+") { [store] in
                store.zoomIn()
            },
            CommandAction(id: "zoom-out", title: "Zoom Out", icon: "minus.magnifyingglass", shortcut: "⌘-") { [store] in
                store.zoomOut()
            },
            CommandAction(id: "zoom-reset", title: "Actual Size", icon: "1.magnifyingglass", shortcut: "⌘0") { [store] in
                store.zoomReset()
            },

            // View toggles
            CommandAction(id: "toggle-sidebar", title: "Toggle Sidebar", icon: "sidebar.left", shortcut: "⇧⌘S") { [store] in
                store.isSidebarCollapsed.toggle()
            },
            CommandAction(id: "toggle-find", title: "Find in Page", icon: "doc.text.magnifyingglass", shortcut: "⌘F") { [store] in
                store.toggleFindBar()
            },
            CommandAction(id: "library", title: "Open Library", icon: "books.vertical", shortcut: "⌘Y") { [store] in
                store.isLibraryVisible = true
            },
            CommandAction(id: "boosts", title: "Open Boost Editor", icon: "bolt", shortcut: nil) { [store] in
                store.isBoostEditorVisible = true
            },
            CommandAction(id: "reader", title: "Toggle Reader Mode", icon: "book", shortcut: nil) { [store] in
                store.toggleReaderMode()
            },
            CommandAction(id: "split", title: "Toggle Split View", icon: "rectangle.split.2x1", shortcut: "⇧⌘D") { [store] in
                if store.splitTabID != nil {
                    store.closeSplit()
                } else if store.activeTabID != nil {
                    let tab = BrowserTab(url: nil)
                    store.tabs[tab.id] = tab
                    if let wsIndex = store.workspaces.firstIndex(where: { $0.id == store.activeWorkspaceID }) {
                        store.workspaces[wsIndex].tabIDs.append(tab.id)
                    }
                    store.splitTabID = tab.id
                }
            },

            // Page actions
            CommandAction(id: "print", title: "Print Page", icon: "printer", shortcut: "⌘P") { [store] in
                store.printPage()
            },
            CommandAction(id: "bookmark", title: "Bookmark This Page", icon: "star", shortcut: nil) { [store] in
                store.toggleBookmark()
            },
            CommandAction(id: "copy-url", title: "Copy Page URL", icon: "doc.on.doc", shortcut: nil) { [store] in
                if let url = store.activeTab?.url {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(url.absoluteString, forType: .string)
                }
            },

            // Workspace management
            CommandAction(id: "new-workspace", title: "New Workspace", icon: "plus.rectangle.on.rectangle", shortcut: nil) { [store] in
                store.createWorkspace(name: "Space \(store.workspaces.count + 1)")
            },
            CommandAction(id: "new-group", title: "Create Tab Group", icon: "folder.badge.plus", shortcut: nil) { [store] in
                store.createTabGroup(name: "New Group")
            },

            // Privacy
            CommandAction(id: "clear-data", title: "Clear Browsing Data", icon: "trash", shortcut: nil) { [store] in
                store.clearHistory()
                Task { await FaviconCache.shared.clear() }
            },
            CommandAction(id: "private-window", title: "New Private Window", icon: "eye.slash", shortcut: "⇧⌘N") { [store] in
                // Dispatched via BrowserCommands
            },
            CommandAction(id: "little-vela", title: "Open Little Vela", icon: "rectangle.on.rectangle.angled", shortcut: "⌥⌘N") { [store] in
                // Dispatched via BrowserCommands
            },

            // Profile management
            CommandAction(id: "manage-profiles", title: "Manage Profiles", icon: "person.2", shortcut: nil) { },

            // Settings
            CommandAction(id: "settings", title: "Open Settings", icon: "gearshape", shortcut: "⌘,") { },

            // Focus
            CommandAction(id: "focus-address", title: "Focus Address Bar", icon: "character.cursor.ibeam", shortcut: "⌘L") { },

            // Import
            CommandAction(id: "import-bookmarks", title: "Import Bookmarks", icon: "square.and.arrow.down", shortcut: nil) { },

            // Mute
            CommandAction(id: "mute-tab", title: "Toggle Mute Tab", icon: "speaker.slash", shortcut: nil) { [store] in
                if let tabID = store.activeTabID {
                    store.toggleMute(tabID)
                }
            },

            // Pin
            CommandAction(id: "pin-tab", title: "Toggle Pin Tab", icon: "pin", shortcut: nil) { [store] in
                if let tabID = store.activeTabID, let tab = store.tabs[tabID] {
                    store.setPinned(tabID, isPinned: !tab.isPinned)
                }
            },

            // Favorites
            CommandAction(id: "toggle-favorite", title: "Toggle Favorite", icon: "heart", shortcut: nil) { [store] in
                if let tabID = store.activeTabID {
                    if store.isFavorite(tabID) {
                        store.removeFavorite(tabID)
                    } else {
                        store.addFavorite(tabID)
                    }
                }
            },
        ]

        // Dynamic workspace switching actions
        for workspace in store.workspaces {
            let wsID = workspace.id
            let wsName = workspace.name
            actions.append(CommandAction(id: "switch-ws-\(wsID)", title: "Switch to \(wsName)", icon: "rectangle.stack", shortcut: nil) { [store] in
                store.switchWorkspace(wsID)
            })
        }

        return actions
    }

    private var filteredTabs: [BrowserTab] {
        let allTabs = Array(store.tabs.values).filter { !store.isTransientTab($0.id) }
        guard !query.isEmpty else {
            return allTabs.sorted { $0.lastAccessedAt > $1.lastAccessedAt }.prefix(5).map { $0 }
        }

        let lowered = query.lowercased()
        return allTabs
            .filter { $0.title.lowercased().contains(lowered) || ($0.url?.absoluteString.lowercased().contains(lowered) ?? false) }
            .sorted { $0.lastAccessedAt > $1.lastAccessedAt }
            .prefix(5)
            .map { $0 }
    }

    private var filteredBookmarks: [Bookmark] {
        guard !query.isEmpty else { return [] }
        let lowered = query.lowercased()
        let openURLs = Set(store.tabs.values
            .filter { !store.isTransientTab($0.id) }
            .compactMap(\.url?.absoluteString))
        return store.bookmarks
            .filter { bm in
                !openURLs.contains(bm.url.absoluteString) &&
                (bm.title.lowercased().contains(lowered) || bm.url.absoluteString.lowercased().contains(lowered))
            }
            .prefix(3)
            .map { $0 }
    }

    private var filteredHistory: [HistoryEntry] {
        guard !query.isEmpty else { return [] }
        let lowered = query.lowercased()
        let openURLs = Set(store.tabs.values
            .filter { !store.isTransientTab($0.id) }
            .compactMap(\.url?.absoluteString))
        return store.history
            .filter { entry in
                !openURLs.contains(entry.url.absoluteString) &&
                (entry.title.lowercased().contains(lowered) || entry.url.absoluteString.lowercased().contains(lowered))
            }
            .prefix(5)
            .map { $0 }
    }

    // MARK: - Actions

    private func submitSelection() {
        if !results.isEmpty, selectedIndex < results.count {
            selectResult(results[selectedIndex])
        } else if !query.isEmpty {
            store.loadAddressInput(query)
            dismiss()
        }
    }

    private func selectResult(_ result: CommandBarResult) {
        switch result {
        case .tab(let tab):
            VelaAnimation.withEmphasis {
                store.selectTab(tab.id)
                store.isCommandBarVisible = false
            }
        case .bookmark(let bm):
            store.loadAddressInput(bm.url.absoluteString)
            VelaAnimation.withEmphasis {
                store.isCommandBarVisible = false
            }
        case .history(let entry):
            store.loadAddressInput(entry.url.absoluteString)
            VelaAnimation.withEmphasis {
                store.isCommandBarVisible = false
            }
        case .action(let action):
            VelaAnimation.withEmphasis {
                store.isCommandBarVisible = false
            }
            action.action()
        }
    }

    private func dismiss() {
        VelaAnimation.withEmphasis {
            store.isCommandBarVisible = false
        }
    }
}

// MARK: - Result Model

enum CommandBarResult: Identifiable {
    case tab(BrowserTab)
    case bookmark(Bookmark)
    case history(HistoryEntry)
    case action(CommandAction)

    var id: String {
        switch self {
        case .tab(let tab): return "tab-\(tab.id)"
        case .bookmark(let bm): return "bookmark-\(bm.id)"
        case .history(let entry): return "history-\(entry.id)"
        case .action(let action): return "action-\(action.id)"
        }
    }
}

struct CommandAction: Identifiable {
    let id: String
    let title: String
    let icon: String
    let shortcut: String?
    let action: @MainActor () -> Void

    init(id: String, title: String, icon: String, shortcut: String? = nil, action: @escaping @MainActor () -> Void) {
        self.id = id
        self.title = title
        self.icon = icon
        self.shortcut = shortcut
        self.action = action
    }
}

// MARK: - Result Row

private struct CommandBarRow: View {
    let result: CommandBarResult
    let isSelected: Bool

    var body: some View {
        HStack(spacing: 10) {
            resultIcon
                .frame(width: 18, height: 18)

            VStack(alignment: .leading, spacing: 2) {
                Text(resultTitle)
                    .lineLimit(1)
                    .font(.body)

                if !resultSubtitle.isEmpty {
                    Text(resultSubtitle)
                        .lineLimit(1)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            if let shortcut = resultShortcut {
                Text(shortcut)
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .padding(.trailing, 4)
            }

            resultBadge
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(
            isSelected ? Color.accentColor.opacity(0.15) : Color.clear,
            in: RoundedRectangle(cornerRadius: 8)
        )
        .contentShape(Rectangle())
    }

    @ViewBuilder
    private var resultIcon: some View {
        switch result {
        case .tab(let tab):
            FaviconView(url: tab.url, size: 18)
        case .bookmark:
            Image(systemName: "star.fill").foregroundStyle(.yellow)
        case .history:
            Image(systemName: "clock").foregroundStyle(.secondary)
        case .action(let action):
            Image(systemName: action.icon).foregroundStyle(Color.accentColor)
        }
    }

    private var resultTitle: String {
        switch result {
        case .tab(let tab): return tab.title
        case .bookmark(let bm): return bm.title
        case .history(let entry): return entry.title
        case .action(let action): return action.title
        }
    }

    private var resultSubtitle: String {
        switch result {
        case .tab(let tab): return tab.url?.absoluteString ?? ""
        case .bookmark(let bm): return bm.url.absoluteString
        case .history(let entry): return entry.url.absoluteString
        case .action: return ""
        }
    }

    private var resultShortcut: String? {
        if case .action(let action) = result {
            return action.shortcut
        }
        return nil
    }

    @ViewBuilder
    private var resultBadge: some View {
        switch result {
        case .tab:
            Text("Tab")
                .font(.caption2)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(.quaternary, in: RoundedRectangle(cornerRadius: 4))
        case .bookmark:
            Text("Bookmark")
                .font(.caption2)
                .foregroundStyle(.yellow)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(.quaternary, in: RoundedRectangle(cornerRadius: 4))
        case .history:
            Text("History")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(.quaternary, in: RoundedRectangle(cornerRadius: 4))
        case .action:
            Text("Action")
                .font(.caption2)
                .foregroundStyle(Color.accentColor)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(.quaternary, in: RoundedRectangle(cornerRadius: 4))
        }
    }
}
