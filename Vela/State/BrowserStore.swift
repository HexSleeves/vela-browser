import Foundation
import Observation

@MainActor
@Observable
final class BrowserStore {
    var workspaces: [Workspace]
    var tabs: [BrowserTab.ID: BrowserTab]
    var themes: [BrowserTheme]
    var activeWorkspaceID: Workspace.ID
    var activeTabID: BrowserTab.ID?
    var isSidebarCollapsed = false

    let webViewPool: WebViewPooling
    private let persistence: BrowserPersistence
    private let navigationService: NavigationService

    static func bootstrap() -> BrowserStore {
        let persistence = BrowserPersistence()
        if let snapshot = try? persistence.load() {
            return BrowserStore(snapshot: snapshot, persistence: persistence)
        }

        let theme = BrowserTheme.builtIns[0]
        let workspace = Workspace(name: "Personal", themeID: theme.id)
        return BrowserStore(
            snapshot: BrowserStateSnapshot(
                schemaVersion: 1,
                activeWorkspaceID: workspace.id,
                activeTabID: nil,
                workspaces: [workspace],
                tabs: [],
                themes: BrowserTheme.builtIns
            ),
            persistence: persistence
        )
    }

    init(
        snapshot: BrowserStateSnapshot,
        persistence: BrowserPersistence,
        navigationService: NavigationService = NavigationService(),
        webViewPool: WebViewPooling = WebViewPool()
    ) {
        self.workspaces = snapshot.workspaces
        self.tabs = Dictionary(uniqueKeysWithValues: snapshot.tabs.map { ($0.id, $0) })
        self.themes = snapshot.themes
        self.activeWorkspaceID = snapshot.activeWorkspaceID
        self.activeTabID = snapshot.activeTabID
        self.persistence = persistence
        self.navigationService = navigationService
        self.webViewPool = webViewPool
    }

    var activeWorkspace: Workspace? {
        workspaces.first { $0.id == activeWorkspaceID }
    }

    var activeTab: BrowserTab? {
        activeTabID.flatMap { tabs[$0] }
    }

    var activeTheme: BrowserTheme {
        guard let themeID = activeWorkspace?.themeID,
              let theme = themes.first(where: { $0.id == themeID }) else {
            return BrowserTheme.builtIns[0]
        }
        return theme
    }

    func createTab(in workspaceID: Workspace.ID? = nil, url: URL? = nil, pinned: Bool = false) {
        let targetWorkspaceID = workspaceID ?? activeWorkspaceID
        var tab = BrowserTab(url: url, isPinned: pinned)
        tabs[tab.id] = tab

        guard let index = workspaces.firstIndex(where: { $0.id == targetWorkspaceID }) else {
            return
        }

        workspaces[index].tabIDs.append(tab.id)
        activeWorkspaceID = targetWorkspaceID
        activeTabID = tab.id

        if let url {
            tab.title = url.host() ?? url.absoluteString
            tab.lastAccessedAt = Date()
            tabs[tab.id] = tab
            webViewPool.load(url, in: tab.id)
        }

        persist()
    }

    func closeTab(_ tabID: BrowserTab.ID) {
        tabs.removeValue(forKey: tabID)
        webViewPool.remove(tabID: tabID)

        for index in workspaces.indices {
            workspaces[index].tabIDs.removeAll { $0 == tabID }
        }

        if activeTabID == tabID {
            activeTabID = activeWorkspace?.tabIDs.first
        }

        persist()
    }

    func selectTab(_ tabID: BrowserTab.ID) {
        guard tabs[tabID] != nil else {
            return
        }

        activeTabID = tabID
        tabs[tabID]?.lastAccessedAt = Date()
        persist()
    }

    func setPinned(_ tabID: BrowserTab.ID, isPinned: Bool) {
        guard tabs[tabID] != nil else {
            return
        }

        tabs[tabID]?.isPinned = isPinned
        persist()
    }

    func setTheme(_ themeID: BrowserTheme.ID, for workspaceID: Workspace.ID) {
        guard themes.contains(where: { $0.id == themeID }),
              let index = workspaces.firstIndex(where: { $0.id == workspaceID }) else {
            return
        }

        workspaces[index].themeID = themeID
        persist()
    }

    func switchWorkspace(_ workspaceID: Workspace.ID) {
        guard let workspace = workspaces.first(where: { $0.id == workspaceID }) else {
            return
        }

        activeWorkspaceID = workspaceID
        activeTabID = workspace.tabIDs.first
        persist()
    }

    /// Moves a tab within the active workspace's tab list.
    /// `fromIndex` and `toIndex` are relative to the filtered section (pinned or unpinned).
    func moveTab(from fromIndex: Int, to toIndex: Int, pinned: Bool) {
        guard let wsIndex = workspaces.firstIndex(where: { $0.id == activeWorkspaceID }) else { return }

        let allIDs = workspaces[wsIndex].tabIDs
        // Collect indices within tabIDs that belong to this section
        let sectionIndices = allIDs.enumerated().compactMap { offset, id -> Int? in
            guard let tab = tabs[id], tab.isPinned == pinned else { return nil }
            return offset
        }

        guard fromIndex >= 0, fromIndex < sectionIndices.count,
              toIndex >= 0, toIndex < sectionIndices.count,
              fromIndex != toIndex else { return }

        let movingAbsoluteIndex = sectionIndices[fromIndex]
        let tabID = allIDs[movingAbsoluteIndex]

        // Remove from current position
        workspaces[wsIndex].tabIDs.remove(at: movingAbsoluteIndex)

        // Recalculate section indices after removal
        let updatedIDs = workspaces[wsIndex].tabIDs
        let updatedSectionIndices = updatedIDs.enumerated().compactMap { offset, id -> Int? in
            guard let tab = tabs[id], tab.isPinned == pinned else { return nil }
            return offset
        }

        // Compute insertion position
        let insertAt: Int
        if toIndex >= updatedSectionIndices.count {
            // Inserting at the end of the section
            if let lastIdx = updatedSectionIndices.last {
                insertAt = lastIdx + 1
            } else {
                // Section is now empty — insert at end (for pinned) or after last pinned (for unpinned)
                insertAt = workspaces[wsIndex].tabIDs.count
            }
        } else {
            insertAt = updatedSectionIndices[toIndex]
        }

        workspaces[wsIndex].tabIDs.insert(tabID, at: insertAt)
        persist()
    }

    func loadAddressInput(_ input: String) {
        let destination = navigationService.destination(for: input)

        guard let tabID = activeTabID else {
            createTab(url: destination)
            return
        }

        tabs[tabID]?.url = destination
        tabs[tabID]?.title = destination.host() ?? destination.absoluteString
        tabs[tabID]?.lastAccessedAt = Date()
        webViewPool.load(destination, in: tabID)
        persist()
    }

    func updateTab(_ tabID: BrowserTab.ID, title: String?, url: URL?, isLoading: Bool, estimatedProgress: Double? = nil) {
        guard var tab = tabs[tabID] else {
            return
        }

        if let title, !title.isEmpty {
            tab.title = title
        }
        tab.url = url ?? tab.url
        tab.isLoading = isLoading
        if let estimatedProgress {
            tab.estimatedProgress = estimatedProgress
        }
        tabs[tabID] = tab
        persist()
    }

    private func persist() {
        let snapshot = BrowserStateSnapshot(
            schemaVersion: 1,
            activeWorkspaceID: activeWorkspaceID,
            activeTabID: activeTabID,
            workspaces: workspaces,
            tabs: Array(tabs.values),
            themes: themes
        )
        try? persistence.save(snapshot)
    }
}
