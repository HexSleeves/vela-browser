import SwiftUI

struct SidebarView: View {
    @Environment(BrowserStore.self) private var store
    @State private var slideDirection: Edge = .trailing
    @State private var tabFilter = ""

    var body: some View {
        ZStack {
            themeBackground

            VStack(alignment: .leading, spacing: 14) {
                spaceHeader

                if !store.isSidebarCollapsed {
                    tabSections
                        .transition(.opacity.combined(with: .scale(scale: 0.96, anchor: .top)))

                    if !store.bookmarks.isEmpty {
                        bookmarksSection
                    }

                    if let ws = store.activeWorkspace, !ws.archivedTabIDs.isEmpty {
                        archiveSection(ws.archivedTabIDs)
                    }
                }

                Spacer(minLength: 12)
                bottomBar
            }
            .padding(12)
            .animation(VelaAnimation.layout, value: store.isSidebarCollapsed)
        }
    }

    private var themeBackground: some View {
        LinearGradient(
            colors: [
                store.activeTheme.primary.color.opacity(0.58),
                store.activeTheme.secondary.color.opacity(0.28),
                store.activeTheme.accent.color.opacity(0.22)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .overlay(.regularMaterial.opacity(0.54))
        .ignoresSafeArea()
        .animation(VelaAnimation.layout, value: store.activeWorkspaceID)
    }

    private var spaceHeader: some View {
        VStack(alignment: .leading, spacing: 8) {
            if !store.isSidebarCollapsed {
                HStack {
                    Text("Vela")
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(.primary)

                    Spacer()

                    Button {
                        VelaAnimation.withEmphasis {
                            store.createWorkspace(name: "Space \(store.workspaces.count + 1)")
                        }
                    } label: {
                        Image(systemName: "plus.circle")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                    .help("New Workspace")
                }
                .transition(.opacity)
            }

            ForEach(Array(store.workspaces.enumerated()), id: \.element.id) { index, workspace in
                Button {
                    let currentIndex = store.workspaces.firstIndex(where: { $0.id == store.activeWorkspaceID }) ?? 0
                    slideDirection = index > currentIndex ? .trailing : .leading
                    VelaAnimation.withLayout {
                        store.switchWorkspace(workspace.id)
                    }
                } label: {
                    HStack(spacing: 8) {
                        Text("\(index + 1)")
                            .font(.caption.weight(.semibold))
                            .frame(width: 22, height: 22)
                            .background(.thinMaterial, in: Circle())

                        if !store.isSidebarCollapsed {
                            Text(workspace.name)
                                .lineLimit(1)
                                .transition(.opacity)
                            Spacer()
                        }
                    }
                    .padding(.vertical, 4)
                    .padding(.horizontal, 6)
                    .background(workspace.id == store.activeWorkspaceID ? Color.primary.opacity(0.08) : Color.clear, in: RoundedRectangle(cornerRadius: 8))
                }
                .buttonStyle(.plain)
                .contextMenu {
                    Button("Rename…") {
                        let alert = NSAlert()
                        alert.messageText = "Rename Workspace"
                        alert.informativeText = "Enter a new name:"
                        let field = NSTextField(frame: NSRect(x: 0, y: 0, width: 200, height: 24))
                        field.stringValue = workspace.name
                        alert.accessoryView = field
                        alert.addButton(withTitle: "Rename")
                        alert.addButton(withTitle: "Cancel")
                        if alert.runModal() == .alertFirstButtonReturn {
                            let newName = field.stringValue.trimmingCharacters(in: .whitespaces)
                            if !newName.isEmpty {
                                store.renameWorkspace(workspace.id, name: newName)
                            }
                        }
                    }

                    if store.workspaces.count > 1 {
                        Button("Delete Workspace", role: .destructive) {
                            VelaAnimation.withEmphasis {
                                store.deleteWorkspace(workspace.id)
                            }
                        }
                    }
                }
            }
            .animation(VelaAnimation.emphasis, value: store.workspaces.map(\.id))
        }
    }

    private var tabSections: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                // Tab search/filter
                HStack(spacing: 6) {
                    Image(systemName: "magnifyingglass")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                    TextField("Filter tabs…", text: $tabFilter)
                        .textFieldStyle(.plain)
                        .font(.caption)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
                .background(.quaternary, in: RoundedRectangle(cornerRadius: 6))

                let filteredTabs = filterTabs(activeTabs)

                TabSectionView(title: "Pinned", tabs: filteredTabs.filter(\.isPinned), isPinned: true)

                // Tab groups
                ForEach(store.tabGroups) { group in
                    tabGroupView(group)
                }

                // Ungrouped tabs
                let ungroupedIDs = store.tabGroups.isEmpty
                    ? filteredTabs.filter { !$0.isPinned }.map(\.id)
                    : store.ungroupedTabIDs(in: store.activeWorkspace ?? store.workspaces[0])
                let ungroupedTabs = filterTabs(ungroupedIDs.compactMap { store.tabs[$0] })
                if !ungroupedTabs.isEmpty {
                    TabSectionView(title: store.tabGroups.isEmpty ? "Tabs" : "Ungrouped", tabs: ungroupedTabs, isPinned: false)
                }

                // New Group button
                Button {
                    promptCreateGroup()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "plus")
                            .font(.caption2)
                        Text("New Group")
                            .font(.caption)
                    }
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                }
                .buttonStyle(.plain)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .id(store.activeWorkspaceID)
        .transition(.asymmetric(
            insertion: .move(edge: slideDirection).combined(with: .opacity),
            removal: .move(edge: slideDirection == .trailing ? .leading : .trailing).combined(with: .opacity)
        ))
    }

    private func promptCreateGroup() {
        let alert = NSAlert()
        alert.messageText = "New Tab Group"
        alert.informativeText = "Enter a name for this group:"
        let field = NSTextField(frame: NSRect(x: 0, y: 0, width: 200, height: 24))
        field.stringValue = ""
        field.placeholderString = "Group name"
        alert.accessoryView = field
        alert.addButton(withTitle: "Create")
        alert.addButton(withTitle: "Cancel")
        alert.window.initialFirstResponder = field
        if alert.runModal() == .alertFirstButtonReturn {
            let name = field.stringValue.trimmingCharacters(in: .whitespaces)
            if !name.isEmpty {
                VelaAnimation.withEmphasis {
                    store.createTabGroup(name: name)
                }
            }
        }
    }

    private var bookmarksSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Bookmarks")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)

            ForEach(store.bookmarks.prefix(10)) { bookmark in
                Button {
                    store.loadAddressInput(bookmark.url.absoluteString)
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "star.fill")
                            .foregroundStyle(.yellow)
                            .font(.caption2)
                            .frame(width: 18)

                        Text(bookmark.title)
                            .lineLimit(1)
                            .font(.body)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                }
                .buttonStyle(.plain)
                .contextMenu {
                    Button("Remove Bookmark", role: .destructive) {
                        VelaAnimation.withMicro {
                            store.removeBookmark(bookmark.id)
                        }
                    }
                }
            }
        }
    }

    private func tabGroupView(_ group: TabGroup) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Button {
                VelaAnimation.withMicro {
                    store.toggleGroupCollapse(group.id)
                }
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: group.isCollapsed ? "chevron.right" : "chevron.down")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .frame(width: 12)

                    Text(group.name)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .textCase(.uppercase)

                    Spacer()

                    Text("\(group.tabIDs.count)")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }
            .buttonStyle(.plain)
            .contextMenu {
                Button("Rename…") {
                    let alert = NSAlert()
                    alert.messageText = "Rename Group"
                    let field = NSTextField(frame: NSRect(x: 0, y: 0, width: 200, height: 24))
                    field.stringValue = group.name
                    alert.accessoryView = field
                    alert.addButton(withTitle: "Rename")
                    alert.addButton(withTitle: "Cancel")
                    if alert.runModal() == .alertFirstButtonReturn, !field.stringValue.isEmpty {
                        store.renameTabGroup(group.id, name: field.stringValue)
                    }
                }
                Button("Delete Group", role: .destructive) {
                    VelaAnimation.withEmphasis {
                        store.deleteTabGroup(group.id)
                    }
                }
            }

            if !group.isCollapsed {
                let groupTabs = group.tabIDs.compactMap { store.tabs[$0] }
                TabSectionView(title: "", tabs: groupTabs, isPinned: false)
            }
        }
    }

    private func archiveSection(_ archivedIDs: [BrowserTab.ID]) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Archive")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)

            ForEach(archivedIDs.compactMap({ store.tabs[$0] })) { tab in
                Button {
                    VelaAnimation.withEmphasis {
                        store.restoreArchivedTab(tab.id)
                    }
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "archivebox")
                            .foregroundStyle(.secondary)
                            .font(.caption2)
                            .frame(width: 18)

                        Text(tab.title)
                            .lineLimit(1)
                            .font(.body)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var activeTabs: [BrowserTab] {
        (store.activeWorkspace?.tabIDs ?? []).compactMap { store.tabs[$0] }
    }

    private func filterTabs(_ tabs: [BrowserTab]) -> [BrowserTab] {
        guard !tabFilter.isEmpty else { return tabs }
        let lowered = tabFilter.lowercased()
        return tabs.filter {
            $0.title.lowercased().contains(lowered) ||
            ($0.url?.absoluteString.lowercased().contains(lowered) ?? false)
        }
    }

    private var bottomBar: some View {
        HStack {
            Button {
                VelaAnimation.withEmphasis {
                    store.createTab()
                }
            } label: {
                Image(systemName: "plus")
                    .frame(width: 24, height: 24)
            }
            .help("New Tab")

            Button {
                VelaAnimation.withLayout {
                    store.isSidebarCollapsed.toggle()
                }
            } label: {
                Image(systemName: "sidebar.left")
                    .frame(width: 24, height: 24)
            }
            .help("Toggle Sidebar")

            if !store.isSidebarCollapsed {
                Spacer()

                Button {
                    store.isHistoryVisible.toggle()
                } label: {
                    Image(systemName: "clock")
                        .frame(width: 24, height: 24)
                }
                .help("History (⌘Y)")

                Button {
                    store.isBoostEditorVisible.toggle()
                } label: {
                    Image(systemName: "bolt")
                        .frame(width: 24, height: 24)
                }
                .help("Boosts")

                Button {
                    store.isDownloadsVisible.toggle()
                } label: {
                    ZStack(alignment: .topTrailing) {
                        Image(systemName: "arrow.down.circle")
                            .frame(width: 24, height: 24)
                        if store.downloads.contains(where: { $0.state == .downloading }) {
                            Circle()
                                .fill(.blue)
                                .frame(width: 6, height: 6)
                                .offset(x: 2, y: -2)
                        }
                    }
                }
                .help("Downloads")
                .popover(isPresented: Binding(
                    get: { store.isDownloadsVisible },
                    set: { store.isDownloadsVisible = $0 }
                )) {
                    DownloadsView()
                }
            }
        }
        .buttonStyle(.borderless)
    }
}
