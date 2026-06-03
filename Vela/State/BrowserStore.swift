import Foundation
import Observation
import WebKit

@MainActor
@Observable
final class BrowserStore {
    var workspaces: [Workspace]
    var tabs: [BrowserTab.ID: BrowserTab]
    var themes: [BrowserTheme]
    var activeWorkspaceID: Workspace.ID
    var activeTabID: BrowserTab.ID?
    var isSidebarCollapsed = false
    var isFindBarVisible = false
    var findText = ""
    var isCommandBarVisible = false
    var isLibraryVisible = false
    var isBoostEditorVisible = false
    var downloads: [DownloadItem] = []
    var bookmarks: [Bookmark] = []
    var recentlyClosed: [ClosedTab] = []
    var history: [HistoryEntry] = []
    var sslExceptions: Set<String> = [] // Hosts the user chose "proceed anyway" for
    var splitTabID: BrowserTab.ID? // Second tab in split view
    var boosts: [Boost] = []
    var tabGroups: [TabGroup] = []
    var favoriteTabIDs: [BrowserTab.ID] = []
    var profiles: [Profile] = [Profile.makeDefault()]
    var swipeIndicator: [BrowserTab.ID: SwipeDirection] = [:]
    var peekURL: URL?
    var isPeekVisible = false
    var pendingCommand: BrowserCommand?
    var isZapModeActive = false
    @ObservationIgnored var contentBlocker = ContentBlockerService()
    var contentBlockingExceptions: Set<String> = []
    var installedExtensions: [InstalledExtension] = []
    @ObservationIgnored var extensionController = WKWebExtensionController()

    enum TransientTabKind {
        case littleVela
        case privateBrowsing
    }

    enum SwipeDirection {
        case back
        case forward
    }

    struct ClosedTab {
        let title: String
        let url: URL?
        let workspaceID: Workspace.ID
        let isPinned: Bool
    }

    private static let maxRecentlyClosed = 10

    private static let maxHistoryEntries = 500

    private static let maxDownloadEntries = 200

    private var transientTabs: [BrowserTab.ID: TransientTabKind] = [:]

    let webViewPool: WebViewPooling
    let downloadManager: DownloadManager
    private let persistence: BrowserPersistence
    private let navigationService: NavigationService

    static func bootstrap() -> BrowserStore {
        let persistence = BrowserPersistence()
        if let snapshot = try? persistence.load() {
            let store = BrowserStore(snapshot: snapshot, persistence: persistence)
            store.loadHistory()
            store.loadBookmarks()
            store.loadBoosts()
            store.loadExtensions()
            store.loadDownloads()
            store.loadRoutingRules()
            store.initContentBlocking()
            store.archiveStaleTabsIfNeeded()
            store.restorePersistedTabURLs()
            return store
        }

        let theme = BrowserTheme.builtIns[0]
        let workspace = Workspace(name: "Personal", themeID: theme.id)
        return BrowserStore(
            snapshot: BrowserStateSnapshot(
                schemaVersion: 3,
                activeWorkspaceID: workspace.id,
                activeTabID: nil,
                workspaces: [workspace],
                tabs: [],
                themes: BrowserTheme.builtIns,
                profiles: [Profile.makeDefault()]
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
        self.tabGroups = snapshot.tabGroups
        self.favoriteTabIDs = snapshot.favoriteTabIDs
        self.profiles = snapshot.profiles
        self.persistence = persistence
        self.navigationService = navigationService
        self.webViewPool = webViewPool
        self.downloadManager = DownloadManager()
        self.downloadManager.store = self
        if let pool = webViewPool as? WebViewPool {
            pool.store = self
        }
        removeOrphanedPersistedTabs()
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

    func createTransientTab(kind: TransientTabKind) -> BrowserTab.ID {
        let tab = BrowserTab(url: nil)
        tabs[tab.id] = tab
        transientTabs[tab.id] = kind
        return tab.id
    }

    func discardTransientTab(_ tabID: BrowserTab.ID?) {
        guard let tabID else { return }
        transientTabs.removeValue(forKey: tabID)
        tabs.removeValue(forKey: tabID)
        webViewPool.remove(tabID: tabID)
        swipeIndicator.removeValue(forKey: tabID)
        if splitTabID == tabID {
            splitTabID = nil
        }
        if activeTabID == tabID {
            activeTabID = activeWorkspace?.tabIDs.first
        }
        persist()
    }

    func isTransientTab(_ tabID: BrowserTab.ID) -> Bool {
        transientTabs[tabID] != nil
    }

    func isPrivateTab(_ tabID: BrowserTab.ID) -> Bool {
        transientTabs[tabID] == .privateBrowsing
    }

    func promoteTransientTab(_ tabID: BrowserTab.ID, to workspaceID: Workspace.ID) {
        guard transientTabs[tabID] != nil,
              tabs[tabID] != nil,
              let wsIndex = workspaces.firstIndex(where: { $0.id == workspaceID }) else { return }
        transientTabs.removeValue(forKey: tabID)
        workspaces[wsIndex].tabIDs.append(tabID)
        activeWorkspaceID = workspaceID
        activeTabID = tabID
        persist()
    }

    func showSwipeIndicator(_ direction: SwipeDirection, for tabID: BrowserTab.ID) {
        swipeIndicator[tabID] = direction
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(650))
            if swipeIndicator[tabID] == direction {
                swipeIndicator.removeValue(forKey: tabID)
            }
        }
    }

    private func removeOrphanedPersistedTabs() {
        let workspaceTabIDs = Set(workspaces.flatMap { $0.tabIDs + $0.archivedTabIDs })
        tabs = tabs.filter { workspaceTabIDs.contains($0.key) }
        tabGroups = tabGroups.map { group in
            var sanitized = group
            sanitized.tabIDs = group.tabIDs.filter { workspaceTabIDs.contains($0) }
            return sanitized
        }
        favoriteTabIDs = favoriteTabIDs.filter { tabs[$0] != nil }
        if let activeTabID, !workspaceTabIDs.contains(activeTabID) {
            self.activeTabID = activeWorkspace?.tabIDs.first
        }
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
        if isPeekVisible {
            isPeekVisible = false
            peekURL = nil
        }

        if isTransientTab(tabID) {
            discardTransientTab(tabID)
            return
        }

        // Pinned tabs with designatedURL become stubs instead of closing
        if let tab = tabs[tabID], tab.isPinned, tab.designatedURL != nil {
            tabs[tabID]?.isStub = true
            webViewPool.remove(tabID: tabID)
            if activeTabID == tabID {
                // Select next non-stub tab
                let wsTabIDs = activeWorkspace?.tabIDs ?? []
                activeTabID = wsTabIDs.first(where: { $0 != tabID && tabs[$0]?.isStub != true })
            }
            persist()
            return
        }

        // Save to recently closed before removing
        if let tab = tabs[tabID] {
            let wsID = workspaces.first(where: { $0.tabIDs.contains(tabID) })?.id ?? activeWorkspaceID
            let closed = ClosedTab(title: tab.title, url: tab.url, workspaceID: wsID, isPinned: tab.isPinned)
            recentlyClosed.insert(closed, at: 0)
            if recentlyClosed.count > Self.maxRecentlyClosed {
                recentlyClosed = Array(recentlyClosed.prefix(Self.maxRecentlyClosed))
            }
        }

        favoriteTabIDs.removeAll { $0 == tabID }
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

    func undoCloseTab() {
        guard let closed = recentlyClosed.first else { return }
        recentlyClosed.removeFirst()
        createTab(in: closed.workspaceID, url: closed.url, pinned: closed.isPinned)
    }

    func selectTab(_ tabID: BrowserTab.ID) {
        guard tabs[tabID] != nil else {
            return
        }

        // Reactivate stub tabs
        if tabs[tabID]?.isStub == true, let designatedURL = tabs[tabID]?.designatedURL {
            tabs[tabID]?.isStub = false
            tabs[tabID]?.lastAccessedAt = Date()
            activeTabID = tabID
            webViewPool.load(designatedURL, in: tabID)
            persist()
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

    // MARK: - Pinned Tab Designated URL

    func setDesignatedURL(_ url: URL, for tabID: BrowserTab.ID) {
        guard tabs[tabID] != nil else { return }
        tabs[tabID]?.designatedURL = url
        persist()
    }

    func clearDesignatedURL(for tabID: BrowserTab.ID) {
        guard tabs[tabID] != nil else { return }
        tabs[tabID]?.designatedURL = nil
        tabs[tabID]?.isStub = false
        persist()
    }

    func resetToDesignatedURL(_ tabID: BrowserTab.ID) {
        guard let tab = tabs[tabID], let designatedURL = tab.designatedURL else { return }
        tabs[tabID]?.isStub = false
        tabs[tabID]?.url = designatedURL
        tabs[tabID]?.title = designatedURL.host() ?? designatedURL.absoluteString
        tabs[tabID]?.lastAccessedAt = Date()
        webViewPool.load(designatedURL, in: tabID)
        persist()
    }

    func isPinnedWithDesignatedURL(_ tabID: BrowserTab.ID) -> Bool {
        guard let tab = tabs[tabID] else { return false }
        return tab.isPinned && tab.designatedURL != nil
    }

    func setTheme(_ themeID: BrowserTheme.ID, for workspaceID: Workspace.ID) {
        guard themes.contains(where: { $0.id == themeID }),
              let index = workspaces.firstIndex(where: { $0.id == workspaceID }) else {
            return
        }

        workspaces[index].themeID = themeID
        persist()
    }

    // MARK: - Theme CRUD

    func createTheme(name: String, primary: BrowserTheme.Stop, secondary: BrowserTheme.Stop, accent: BrowserTheme.Stop) {
        let theme = BrowserTheme(name: name, primary: primary, secondary: secondary, accent: accent)
        themes.append(theme)
        persist()
    }

    func editTheme(_ themeID: BrowserTheme.ID, name: String, primary: BrowserTheme.Stop, secondary: BrowserTheme.Stop, accent: BrowserTheme.Stop) {
        guard let index = themes.firstIndex(where: { $0.id == themeID }), !themes[index].isBuiltIn else { return }
        themes[index].name = name
        themes[index].primary = primary
        themes[index].secondary = secondary
        themes[index].accent = accent
        persist()
    }

    func deleteTheme(_ themeID: BrowserTheme.ID) {
        guard let theme = themes.first(where: { $0.id == themeID }), !theme.isBuiltIn else { return }
        for index in workspaces.indices {
            if workspaces[index].themeID == themeID {
                workspaces[index].themeID = BrowserTheme.builtIns[0].id
            }
        }
        themes.removeAll { $0.id == themeID }
        persist()
    }

    // MARK: - Workspace CRUD

    func createWorkspace(name: String) {
        // Assign the next theme that isn't already in use, cycling through builtIns
        let usedThemeIDs = Set(workspaces.map(\.themeID))
        let availableTheme = themes.first(where: { !usedThemeIDs.contains($0.id) }) ?? themes[0]
        let workspace = Workspace(name: name, themeID: availableTheme.id)
        workspaces.append(workspace)
        activeWorkspaceID = workspace.id
        activeTabID = nil
        persist()
    }

    func renameWorkspace(_ workspaceID: Workspace.ID, name: String) {
        guard let index = workspaces.firstIndex(where: { $0.id == workspaceID }) else { return }
        workspaces[index].name = name
        persist()
    }

    func deleteWorkspace(_ workspaceID: Workspace.ID) {
        guard workspaces.count > 1 else { return } // Can't delete last workspace
        guard let index = workspaces.firstIndex(where: { $0.id == workspaceID }) else { return }

        // Remove all tabs belonging to this workspace
        let tabIDs = workspaces[index].tabIDs
        for tabID in tabIDs {
            tabs.removeValue(forKey: tabID)
            webViewPool.remove(tabID: tabID)
        }

        workspaces.remove(at: index)

        // If we deleted the active workspace, switch to another
        if activeWorkspaceID == workspaceID {
            activeWorkspaceID = workspaces[0].id
            activeTabID = workspaces[0].tabIDs.first
        }

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

    func moveTab(_ tabID: BrowserTab.ID, toSectionIndex targetIndex: Int, sectionTabIDs: [BrowserTab.ID]) {
        guard sectionTabIDs.contains(tabID),
              targetIndex >= 0,
              targetIndex < sectionTabIDs.count else { return }

        var reorderedSection = sectionTabIDs
        guard let currentIndex = reorderedSection.firstIndex(of: tabID), currentIndex != targetIndex else { return }
        reorderedSection.remove(at: currentIndex)
        reorderedSection.insert(tabID, at: targetIndex)

        if let wsIndex = workspaces.firstIndex(where: { $0.tabIDs.contains(tabID) }) {
            let originalIDs = workspaces[wsIndex].tabIDs
            let sectionSet = Set(sectionTabIDs)
            var replacementIndex = 0
            workspaces[wsIndex].tabIDs = originalIDs.map { id in
                guard sectionSet.contains(id), replacementIndex < reorderedSection.count else { return id }
                defer { replacementIndex += 1 }
                return reorderedSection[replacementIndex]
            }
        }

        if let groupIndex = tabGroups.firstIndex(where: { $0.tabIDs.contains(tabID) }) {
            let originalIDs = tabGroups[groupIndex].tabIDs
            let sectionSet = Set(sectionTabIDs)
            guard sectionSet.isSubset(of: Set(originalIDs)) else {
                persist()
                return
            }
            var replacementIndex = 0
            tabGroups[groupIndex].tabIDs = originalIDs.map { id in
                guard sectionSet.contains(id), replacementIndex < reorderedSection.count else { return id }
                defer { replacementIndex += 1 }
                return reorderedSection[replacementIndex]
            }
        }

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

    // MARK: - Navigation

    func goBack() {
        guard let tabID = activeTabID else { return }
        webViewPool.goBack(tabID: tabID)
    }

    func goForward() {
        guard let tabID = activeTabID else { return }
        webViewPool.goForward(tabID: tabID)
    }

    func reload() {
        guard let tabID = activeTabID else { return }
        if tabs[tabID]?.isLoading == true {
            webViewPool.stopLoading(tabID: tabID)
        } else {
            webViewPool.reload(tabID: tabID)
        }
    }

    // MARK: - Tab Selection by Index

    func selectTabByIndex(_ index: Int) {
        guard let workspace = activeWorkspace else { return }
        let tabIDs = workspace.tabIDs
        guard index >= 0, index < tabIDs.count else { return }
        selectTab(tabIDs[index])
    }

    // MARK: - Zoom

    func zoomIn() {
        guard let tabID = activeTabID, var tab = tabs[tabID] else { return }
        tab.zoomLevel = min(tab.zoomLevel + 0.1, 3.0)
        tabs[tabID] = tab
        webViewPool.setZoom(tab.zoomLevel, tabID: tabID)
    }

    func zoomOut() {
        guard let tabID = activeTabID, var tab = tabs[tabID] else { return }
        tab.zoomLevel = max(tab.zoomLevel - 0.1, 0.3)
        tabs[tabID] = tab
        webViewPool.setZoom(tab.zoomLevel, tabID: tabID)
    }

    func zoomReset() {
        guard let tabID = activeTabID else { return }
        tabs[tabID]?.zoomLevel = 1.0
        webViewPool.setZoom(1.0, tabID: tabID)
    }

    // MARK: - Find in Page

    func toggleFindBar() {
        isFindBarVisible.toggle()
        if !isFindBarVisible {
            findText = ""
            if let tabID = activeTabID {
                webViewPool.clearFind(tabID: tabID)
            }
        }
    }

    func findInPage(_ text: String) {
        findText = text
        guard let tabID = activeTabID else { return }
        // Store the find text in JS for next/previous
        if let pool = webViewPool as? WebViewPool {
            let escaped = text.replacingOccurrences(of: "'", with: "\\'")
            let webView = pool.webView(for: tabID)
            webView.evaluateJavaScript("window.__velaFindText = '\(escaped)'") { _, _ in }
        }
        webViewPool.findInPage(text, tabID: tabID)
    }

    func findNext() {
        guard let tabID = activeTabID else { return }
        webViewPool.findNext(tabID: tabID)
    }

    func findPrevious() {
        guard let tabID = activeTabID else { return }
        webViewPool.findPrevious(tabID: tabID)
    }

    // MARK: - Tab Groups

    func createTabGroup(name: String) {
        let group = TabGroup(name: name)
        tabGroups.append(group)
        persist()
    }

    func renameTabGroup(_ groupID: TabGroup.ID, name: String) {
        guard let index = tabGroups.firstIndex(where: { $0.id == groupID }) else { return }
        tabGroups[index].name = name
        persist()
    }

    func deleteTabGroup(_ groupID: TabGroup.ID) {
        tabGroups.removeAll { $0.id == groupID }
        // Tabs in the group stay in workspace.tabIDs — they just become ungrouped
        persist()
    }

    func moveTabToGroup(_ tabID: BrowserTab.ID, groupID: TabGroup.ID?) {
        // Remove from all groups first
        for index in tabGroups.indices {
            tabGroups[index].tabIDs.removeAll { $0 == tabID }
        }
        // Add to target group
        if let groupID, let index = tabGroups.firstIndex(where: { $0.id == groupID }) {
            tabGroups[index].tabIDs.append(tabID)
        }
        persist()
    }

    func toggleGroupCollapse(_ groupID: TabGroup.ID) {
        guard let index = tabGroups.firstIndex(where: { $0.id == groupID }) else { return }
        tabGroups[index].isCollapsed.toggle()
        persist()
    }

    func ungroupedTabIDs(in workspace: Workspace) -> [BrowserTab.ID] {
        let groupedIDs = Set(tabGroups.flatMap(\.tabIDs))
        return workspace.tabIDs.filter { id in
            !(tabs[id]?.isPinned ?? false) && !groupedIDs.contains(id)
        }
    }

    // MARK: - Boosts

    func boostsForHost(_ host: String) -> [Boost] {
        boosts.filter { $0.isEnabled && $0.matches(host: host) }
    }

    func addBoost(_ boost: Boost) {
        boosts.append(boost)
        persistBoosts()
    }

    func removeBoost(_ id: Boost.ID) {
        boosts.removeAll { $0.id == id }
        persistBoosts()
    }

    func toggleBoost(_ id: Boost.ID) {
        guard let index = boosts.firstIndex(where: { $0.id == id }) else { return }
        boosts[index].isEnabled.toggle()
        persistBoosts()
    }

    func updateBoost(_ boost: Boost) {
        guard let index = boosts.firstIndex(where: { $0.id == boost.id }) else { return }
        boosts[index] = boost
        persistBoosts()
    }

    private func persistBoosts() {
        let directory = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appending(path: "Vela", directoryHint: .isDirectory)
        let url = directory.appending(path: "boosts.json")
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try? JSONEncoder().encode(boosts).write(to: url, options: [.atomic])
    }

    func loadBoosts() {
        let directory = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appending(path: "Vela", directoryHint: .isDirectory)
        let url = directory.appending(path: "boosts.json")
        guard let data = try? Data(contentsOf: url),
              let entries = try? JSONDecoder().decode([Boost].self, from: data) else { return }
        boosts = entries
    }

    // MARK: - Extensions

    func installExtension(from url: URL) {
        Task {
            guard let webExtension = try? await WKWebExtension(resourceBaseURL: url) else { return }
            let context = WKWebExtensionContext(for: webExtension)
            try? extensionController.load(context)

            let name = webExtension.displayName ?? url.lastPathComponent
            let version = webExtension.version ?? "0.0.0"

            let extensionsDir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
                .appending(path: "Vela", directoryHint: .isDirectory)
                .appending(path: "Extensions", directoryHint: .isDirectory)
            try? FileManager.default.createDirectory(at: extensionsDir, withIntermediateDirectories: true)

            let destDir = extensionsDir.appending(path: url.lastPathComponent)
            if !FileManager.default.fileExists(atPath: destDir.path) {
                try? FileManager.default.copyItem(at: url, to: destDir)
            }

            let installed = InstalledExtension(
                name: name,
                version: version,
                extensionBundlePath: "Extensions/\(url.lastPathComponent)"
            )
            installedExtensions.append(installed)
            persistExtensions()
        }
    }

    func removeExtension(id: InstalledExtension.ID) {
        guard let index = installedExtensions.firstIndex(where: { $0.id == id }) else { return }
        let ext = installedExtensions[index]

        for context in extensionController.extensionContexts {
            if context.webExtension.displayName == ext.name {
                try? extensionController.unload(context)
                break
            }
        }

        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appending(path: "Vela", directoryHint: .isDirectory)
        let extPath = base.appending(path: ext.extensionBundlePath)
        try? FileManager.default.removeItem(at: extPath)

        installedExtensions.remove(at: index)
        persistExtensions()
    }

    func toggleExtension(_ id: InstalledExtension.ID) {
        guard let index = installedExtensions.firstIndex(where: { $0.id == id }) else { return }
        installedExtensions[index].isEnabled.toggle()
        persistExtensions()
    }

    func setExtensionPrivateBrowsing(_ id: InstalledExtension.ID, allowed: Bool) {
        guard let index = installedExtensions.firstIndex(where: { $0.id == id }) else { return }
        installedExtensions[index].allowInPrivateBrowsing = allowed
        persistExtensions()
    }

    private func persistExtensions() {
        let directory = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appending(path: "Vela", directoryHint: .isDirectory)
        let url = directory.appending(path: "extensions.json")
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try? JSONEncoder().encode(installedExtensions).write(to: url, options: [.atomic])
    }

    func loadExtensions() {
        let directory = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appending(path: "Vela", directoryHint: .isDirectory)
        let url = directory.appending(path: "extensions.json")
        guard let data = try? Data(contentsOf: url),
              let entries = try? JSONDecoder().decode([InstalledExtension].self, from: data) else { return }
        installedExtensions = entries

        for ext in installedExtensions where ext.isEnabled {
            let extURL = directory.appending(path: ext.extensionBundlePath)
            guard FileManager.default.fileExists(atPath: extURL.path) else { continue }
            Task {
                guard let webExtension = try? await WKWebExtension(resourceBaseURL: extURL) else { return }
                let context = WKWebExtensionContext(for: webExtension)
                try? extensionController.load(context)
            }
        }
    }

    // MARK: - Favorites

    func addFavorite(_ tabID: BrowserTab.ID) {
        guard tabs[tabID] != nil,
              !favoriteTabIDs.contains(tabID),
              favoriteTabIDs.count < 8 else { return }
        favoriteTabIDs.append(tabID)
        persist()
    }

    func removeFavorite(_ tabID: BrowserTab.ID) {
        favoriteTabIDs.removeAll { $0 == tabID }
        persist()
    }

    func reorderFavorites(from fromIndex: Int, to toIndex: Int) {
        guard fromIndex >= 0, fromIndex < favoriteTabIDs.count,
              toIndex >= 0, toIndex < favoriteTabIDs.count,
              fromIndex != toIndex else { return }
        let id = favoriteTabIDs.remove(at: fromIndex)
        favoriteTabIDs.insert(id, at: toIndex)
        persist()
    }

    func isFavorite(_ tabID: BrowserTab.ID) -> Bool {
        favoriteTabIDs.contains(tabID)
    }

    var favoriteTabsWithWorkspace: [(tab: BrowserTab, workspaceID: Workspace.ID)] {
        favoriteTabIDs.compactMap { id in
            guard let tab = tabs[id],
                  let wsID = workspaces.first(where: { $0.tabIDs.contains(id) })?.id else { return nil }
            return (tab: tab, workspaceID: wsID)
        }
    }

    // MARK: - Profiles

    var defaultProfile: Profile {
        profiles.first(where: { $0.dataStoreIdentifier == nil }) ?? profiles[0]
    }

    func profileForWorkspace(_ workspaceID: Workspace.ID) -> Profile {
        guard let workspace = workspaces.first(where: { $0.id == workspaceID }),
              let profileID = workspace.profileID,
              let profile = profiles.first(where: { $0.id == profileID }) else {
            return defaultProfile
        }
        return profile
    }

    func createProfile(name: String) {
        let profile = Profile(name: name)
        profiles.append(profile)
        persist()
    }

    func renameProfile(_ profileID: Profile.ID, name: String) {
        guard let index = profiles.firstIndex(where: { $0.id == profileID }) else { return }
        profiles[index].name = name
        persist()
    }

    func deleteProfile(_ profileID: Profile.ID) {
        guard profiles.count > 1 else { return }
        guard let profile = profiles.first(where: { $0.id == profileID }) else { return }
        // Don't delete the default profile
        guard profile.dataStoreIdentifier != nil else { return }

        // Revert workspaces using this profile to default
        for index in workspaces.indices {
            if workspaces[index].profileID == profileID {
                workspaces[index].profileID = nil
            }
        }

        profiles.removeAll { $0.id == profileID }

        // Remove the data store
        if let identifier = profile.dataStoreIdentifier {
            Task {
                try? await WKWebsiteDataStore.remove(forIdentifier: identifier)
            }
        }

        persist()
    }

    func assignProfile(_ profileID: Profile.ID?, to workspaceID: Workspace.ID) {
        guard let index = workspaces.firstIndex(where: { $0.id == workspaceID }) else { return }
        let oldProfileID = workspaces[index].profileID
        workspaces[index].profileID = profileID

        // If profile changed, need to recreate web views for tabs in this workspace
        if oldProfileID != profileID {
            let tabIDs = workspaces[index].tabIDs
            for tabID in tabIDs {
                webViewPool.remove(tabID: tabID)
            }
        }

        persist()
    }

    // MARK: - Zap Mode

    func toggleZapMode() {
        isZapModeActive.toggle()
        guard let tabID = activeTabID else { return }
        if isZapModeActive {
            let injectJS = """
            (function() {
                if (window.__velaZapActive) return;
                window.__velaZapActive = true;
                var overlay = null;
                document.addEventListener('mouseover', function(e) {
                    if (overlay) overlay.remove();
                    var el = e.target;
                    var rect = el.getBoundingClientRect();
                    overlay = document.createElement('div');
                    overlay.id = '__velaZapOverlay';
                    overlay.style.cssText = 'position:fixed;top:'+rect.top+'px;left:'+rect.left+'px;width:'+rect.width+'px;height:'+rect.height+'px;background:rgba(255,0,0,0.2);border:2px solid red;pointer-events:none;z-index:999999;';
                    document.body.appendChild(overlay);
                }, true);
                document.addEventListener('click', function(e) {
                    if (!window.__velaZapActive) return;
                    e.preventDefault();
                    e.stopPropagation();
                    var el = e.target;
                    var selector = '';
                    if (el.id) { selector = '#' + el.id; }
                    else {
                        var path = [];
                        while (el && el !== document.body) {
                            var tag = el.tagName.toLowerCase();
                            if (el.className && typeof el.className === 'string') {
                                var cls = el.className.trim().split(/\\s+/).filter(function(c){return c.length > 0 && c.length < 40;}).slice(0,2).join('.');
                                if (cls) tag += '.' + cls;
                            }
                            path.unshift(tag);
                            el = el.parentElement;
                        }
                        selector = path.join(' > ');
                    }
                    window.webkit.messageHandlers.velaZap.postMessage(selector);
                }, true);
            })()
            """
            if let pool = webViewPool as? WebViewPool {
                pool.webView(for: tabID).evaluateJavaScript(injectJS) { _, _ in }
            }
        } else {
            let cleanupJS = """
            window.__velaZapActive = false;
            var overlay = document.getElementById('__velaZapOverlay');
            if (overlay) overlay.remove();
            """
            if let pool = webViewPool as? WebViewPool {
                pool.webView(for: tabID).evaluateJavaScript(cleanupJS) { _, _ in }
            }
        }
    }

    func createZapBoost(selector: String) {
        guard let host = activeTab?.url?.host() else { return }
        isZapModeActive = false
        let css = "\(selector) { display: none !important; }"
        if let existingIndex = boosts.firstIndex(where: { $0.hostPattern == host }) {
            boosts[existingIndex].css += "\n\(css)"
            persistBoosts()
        } else {
            addBoost(Boost(hostPattern: host, css: css))
        }
        if let tabID = activeTabID, let pool = webViewPool as? WebViewPool {
            let cleanupJS = "window.__velaZapActive = false; var o = document.getElementById('__velaZapOverlay'); if(o) o.remove();"
            pool.webView(for: tabID).evaluateJavaScript(cleanupJS) { _, _ in }
        }
    }

    // MARK: - Content Blocking

    func initContentBlocking() {
        let isEnabled = UserDefaults.standard.object(forKey: "contentBlockingEnabled") as? Bool ?? true
        guard isEnabled else { return }
        loadContentBlockingExceptions()
        Task {
            await contentBlocker.compileDefaultList()
            await contentBlocker.compileExceptionList(hosts: contentBlockingExceptions)
        }
    }

    func setContentBlockingEnabled(_ enabled: Bool) {
        UserDefaults.standard.set(enabled, forKey: "contentBlockingEnabled")
        if enabled {
            Task {
                await contentBlocker.compileDefaultList()
                await contentBlocker.compileExceptionList(hosts: contentBlockingExceptions)
                (webViewPool as? WebViewPool)?.reapplyContentBlockingRules()
            }
        } else {
            (webViewPool as? WebViewPool)?.reapplyContentBlockingRules()
        }
    }

    func toggleContentBlockingException(host: String) {
        if contentBlockingExceptions.contains(host) {
            contentBlockingExceptions.remove(host)
        } else {
            contentBlockingExceptions.insert(host)
        }
        persistContentBlockingExceptions()
        Task {
            await contentBlocker.compileExceptionList(hosts: contentBlockingExceptions)
            (webViewPool as? WebViewPool)?.reapplyContentBlockingRules()
        }
    }

    func isContentBlockingDisabled(for host: String) -> Bool {
        contentBlockingExceptions.contains(host)
    }

    private func persistContentBlockingExceptions() {
        let directory = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appending(path: "Vela", directoryHint: .isDirectory)
        let url = directory.appending(path: "content-blocking-exceptions.json")
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try? JSONEncoder().encode(Array(contentBlockingExceptions)).write(to: url, options: [.atomic])
    }

    private func loadContentBlockingExceptions() {
        let directory = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appending(path: "Vela", directoryHint: .isDirectory)
        let url = directory.appending(path: "content-blocking-exceptions.json")
        guard let data = try? Data(contentsOf: url),
              let hosts = try? JSONDecoder().decode([String].self, from: data) else { return }
        contentBlockingExceptions = Set(hosts)
    }

    // MARK: - Air Traffic Control

    var routingRules: [RoutingRule] = []

    func addRoutingRule(_ rule: RoutingRule) {
        routingRules.append(rule)
        persistRoutingRules()
    }

    func removeRoutingRule(_ ruleID: RoutingRule.ID) {
        routingRules.removeAll { $0.id == ruleID }
        persistRoutingRules()
    }

    func updateRoutingRule(_ rule: RoutingRule) {
        guard let index = routingRules.firstIndex(where: { $0.id == rule.id }) else { return }
        routingRules[index] = rule
        persistRoutingRules()
    }

    func evaluateRoutingRules(for url: URL) -> Workspace.ID? {
        routingRules.first(where: { $0.matches(url) })?.targetWorkspaceID
    }

    func routeExternalURL(_ url: URL) {
        if let targetWSID = evaluateRoutingRules(for: url),
           workspaces.contains(where: { $0.id == targetWSID }) {
            switchWorkspace(targetWSID)
            createTab(in: targetWSID, url: url)
        } else {
            createTab(url: url)
        }
    }

    private func persistRoutingRules() {
        let directory = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appending(path: "Vela", directoryHint: .isDirectory)
        let url = directory.appending(path: "routing-rules.json")
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try? JSONEncoder().encode(routingRules).write(to: url, options: [.atomic])
    }

    func loadRoutingRules() {
        let directory = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appending(path: "Vela", directoryHint: .isDirectory)
        let url = directory.appending(path: "routing-rules.json")
        guard let data = try? Data(contentsOf: url),
              let rules = try? JSONDecoder().decode([RoutingRule].self, from: data) else { return }
        routingRules = rules
    }

    // MARK: - Downloads

    func persistDownloads() {
        let directory = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appending(path: "Vela", directoryHint: .isDirectory)
        let url = directory.appending(path: "downloads.json")
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let terminal = downloads.filter { $0.state != .downloading }
        let capped = Array(terminal.prefix(Self.maxDownloadEntries))
        try? JSONEncoder().encode(capped).write(to: url, options: [.atomic])
    }

    func loadDownloads() {
        let directory = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appending(path: "Vela", directoryHint: .isDirectory)
        let url = directory.appending(path: "downloads.json")
        guard let data = try? Data(contentsOf: url),
              let entries = try? JSONDecoder().decode([DownloadItem].self, from: data) else { return }
        downloads = entries
    }

    func clearCompletedDownloads() {
        downloads.removeAll { $0.state != .downloading }
        persistDownloads()
    }

    // MARK: - Tab URL Restoration

    func restorePersistedTabURLs() {
        for workspace in workspaces {
            for tabID in workspace.tabIDs {
                guard let tab = tabs[tabID], let url = tab.url, !tab.isStub else { continue }
                webViewPool.load(url, in: tabID)
            }
        }
    }

    // MARK: - Auto-Archive

    func archiveStaleTabsIfNeeded() {
        let thresholdDays = UserDefaults.standard.integer(forKey: "archiveThresholdDays")
        let days = thresholdDays > 0 ? thresholdDays : 7
        let cutoff = Date().addingTimeInterval(-Double(days * 86400))

        for wsIndex in workspaces.indices {
            var toArchive: [BrowserTab.ID] = []
            for tabID in workspaces[wsIndex].tabIDs {
                guard let tab = tabs[tabID],
                      tab.lastAccessedAt < cutoff,
                      tabID != activeTabID,
                      !tab.isPinned else { continue }
                toArchive.append(tabID)
            }
            for tabID in toArchive {
                workspaces[wsIndex].tabIDs.removeAll { $0 == tabID }
                workspaces[wsIndex].archivedTabIDs.append(tabID)
            }
        }
        if workspaces.contains(where: { !$0.archivedTabIDs.isEmpty }) {
            persist()
        }
    }

    func restoreArchivedTab(_ tabID: BrowserTab.ID) {
        for wsIndex in workspaces.indices {
            if workspaces[wsIndex].archivedTabIDs.contains(tabID) {
                workspaces[wsIndex].archivedTabIDs.removeAll { $0 == tabID }
                workspaces[wsIndex].tabIDs.append(tabID)
                selectTab(tabID)
                persist()
                return
            }
        }
    }

    // MARK: - Split View

    func openInSplit(_ tabID: BrowserTab.ID) {
        guard tabs[tabID] != nil, tabID != activeTabID else { return }
        splitTabID = tabID
    }

    func closeSplit() {
        splitTabID = nil
    }

    // MARK: - Error Handling

    func setTabError(_ tabID: BrowserTab.ID, description: String, code: Int) {
        tabs[tabID]?.errorDescription = description
        tabs[tabID]?.errorCode = code
    }

    func clearTabError(_ tabID: BrowserTab.ID) {
        tabs[tabID]?.errorDescription = nil
        tabs[tabID]?.errorCode = nil
    }

    func proceedDespiteSSL(host: String) {
        sslExceptions.insert(host)
        if let tabID = activeTabID {
            clearTabError(tabID)
            reload()
        }
    }

    // MARK: - Bookmarks

    func isBookmarked(_ url: URL) -> Bool {
        bookmarks.contains { $0.url == url }
    }

    func toggleBookmark() {
        guard let tab = activeTab, let url = tab.url else { return }
        if let index = bookmarks.firstIndex(where: { $0.url == url }) {
            bookmarks.remove(at: index)
        } else {
            let bookmark = Bookmark(title: tab.title, url: url)
            bookmarks.insert(bookmark, at: 0)
        }
        persistBookmarks()
    }

    func removeBookmark(_ id: Bookmark.ID) {
        bookmarks.removeAll { $0.id == id }
        persistBookmarks()
    }

    @discardableResult
    func importBookmarks(from fileURL: URL) throws -> Int {
        let imported = try BookmarkImportService().importBookmarks(from: fileURL)
        var seenURLs = Set(bookmarks.map { normalizedBookmarkURL($0.url) })
        let newBookmarks = imported.filter { bookmark in
            let normalized = normalizedBookmarkURL(bookmark.url)
            guard !seenURLs.contains(normalized) else { return false }
            seenURLs.insert(normalized)
            return true
        }
        guard !newBookmarks.isEmpty else { return 0 }
        bookmarks.insert(contentsOf: newBookmarks, at: 0)
        persistBookmarks()
        return newBookmarks.count
    }

    private func normalizedBookmarkURL(_ url: URL) -> String {
        var components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        components?.fragment = nil
        return (components?.url ?? url).absoluteString.lowercased()
    }

    private func persistBookmarks() {
        let directory = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appending(path: "Vela", directoryHint: .isDirectory)
        let bookmarksURL = directory.appending(path: "bookmarks.json")
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let data = try? JSONEncoder().encode(bookmarks)
        try? data?.write(to: bookmarksURL, options: [.atomic])
    }

    func loadBookmarks() {
        let directory = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appending(path: "Vela", directoryHint: .isDirectory)
        let bookmarksURL = directory.appending(path: "bookmarks.json")
        guard let data = try? Data(contentsOf: bookmarksURL),
              let entries = try? JSONDecoder().decode([Bookmark].self, from: data) else { return }
        bookmarks = entries
    }

    // MARK: - Reader Mode

    func toggleReaderMode() {
        guard let tabID = activeTabID else { return }
        let newState = !(tabs[tabID]?.isReaderMode ?? false)
        tabs[tabID]?.isReaderMode = newState
        webViewPool.toggleReaderMode(tabID: tabID, enable: newState)
    }

    // MARK: - Audio

    func toggleMute(_ tabID: BrowserTab.ID) {
        guard var tab = tabs[tabID] else { return }
        tab.isMuted.toggle()
        tabs[tabID] = tab
        webViewPool.setMuted(tab.isMuted, tabID: tabID)
    }

    func updateAudioState(_ tabID: BrowserTab.ID, isPlaying: Bool) {
        tabs[tabID]?.isPlayingAudio = isPlaying
    }

    // MARK: - Print

    func printPage() {
        guard let tabID = activeTabID else { return }
        webViewPool.printPage(tabID: tabID)
    }

    func destination(for input: String) -> URL {
        navigationService.destination(for: input)
    }

    func autocompleteSuggestions(for input: String, limit: Int = 6) -> [AutocompleteSuggestion] {
        let query = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return [] }
        let lowered = query.lowercased()
        var results: [AutocompleteSuggestion] = []

        let matchingTabs = tabs.values
            .filter { !isTransientTab($0.id) }
            .filter { tab in
                tab.title.lowercased().contains(lowered) ||
                (tab.url?.absoluteString.lowercased().contains(lowered) ?? false)
            }
            .sorted { $0.lastAccessedAt > $1.lastAccessedAt }
            .prefix(3)

        results.append(contentsOf: matchingTabs.map { tab in
            AutocompleteSuggestion(
                kind: .tab,
                title: tab.title,
                subtitle: tab.url?.absoluteString ?? "Open tab",
                completionText: tab.url?.absoluteString ?? tab.title,
                url: tab.url,
                tabID: tab.id
            )
        })

        let openURLs = Set(tabs.values
            .filter { !isTransientTab($0.id) }
            .compactMap(\.url?.absoluteString))
        results.append(contentsOf: bookmarks
            .filter { bookmark in
                !openURLs.contains(bookmark.url.absoluteString) &&
                (bookmark.title.lowercased().contains(lowered) || bookmark.url.absoluteString.lowercased().contains(lowered))
            }
            .prefix(3)
            .map { bookmark in
                AutocompleteSuggestion(
                    kind: .bookmark,
                    title: bookmark.title,
                    subtitle: bookmark.url.absoluteString,
                    completionText: bookmark.url.absoluteString,
                    url: bookmark.url
                )
            })

        results.append(contentsOf: history
            .filter { entry in
                !openURLs.contains(entry.url.absoluteString) &&
                (entry.title.lowercased().contains(lowered) || entry.url.absoluteString.lowercased().contains(lowered))
            }
            .prefix(3)
            .map { entry in
                AutocompleteSuggestion(
                    kind: .history,
                    title: entry.title,
                    subtitle: entry.url.absoluteString,
                    completionText: entry.url.absoluteString,
                    url: entry.url
                )
            })

        let destination = navigationService.destination(for: query)
        let directKind: AutocompleteSuggestion.Kind = destination.host()?.localizedCaseInsensitiveContains(query) == true ? .url : .search
        results.append(AutocompleteSuggestion(
            kind: directKind,
            title: directKind == .search ? "Search for “\(query)”" : destination.absoluteString,
            subtitle: directKind == .search ? destination.host() ?? "Search" : "Open URL",
            completionText: destination.absoluteString,
            url: destination
        ))

        var seen = Set<String>()
        return results.filter { suggestion in
            guard !seen.contains(suggestion.completionText) else { return false }
            seen.insert(suggestion.completionText)
            return true
        }.prefix(limit).map { $0 }
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
        if !isTransientTab(tabID) {
            persist()
        }
    }

    func updateNavState(_ tabID: BrowserTab.ID, canGoBack: Bool?, canGoForward: Bool?) {
        guard tabs[tabID] != nil else { return }
        if let canGoBack {
            tabs[tabID]?.canGoBack = canGoBack
        }
        if let canGoForward {
            tabs[tabID]?.canGoForward = canGoForward
        }
    }

    func updateTab(_ tabID: BrowserTab.ID, title: String?, url: URL?, isLoading: Bool, estimatedProgress: Double? = nil) {
        guard var tab = tabs[tabID] else {
            return
        }

        let wasLoading = tab.isLoading

        if let title, !title.isEmpty {
            tab.title = title
        }
        tab.url = url ?? tab.url
        tab.isLoading = isLoading
        if let estimatedProgress {
            tab.estimatedProgress = estimatedProgress
        }
        tabs[tabID] = tab

        // Record history when page finishes loading. Private browsing never writes history.
        if !isPrivateTab(tabID), wasLoading && !isLoading, let pageURL = tab.url {
            recordHistory(title: tab.title, url: pageURL)
        }

        if !isTransientTab(tabID) {
            persist()
        }
    }

    private func recordHistory(title: String, url: URL) {
        // Skip about: pages and duplicates within 2 seconds
        guard url.scheme == "http" || url.scheme == "https" else { return }
        if let last = history.first, last.url == url,
           Date().timeIntervalSince(last.visitedAt) < 2 { return }

        let entry = HistoryEntry(title: title, url: url)
        history.insert(entry, at: 0)

        // Cap history size
        if history.count > Self.maxHistoryEntries {
            history = Array(history.prefix(Self.maxHistoryEntries))
        }

        persistHistory()
    }

    private func persistHistory() {
        // History saved alongside browser state
        let directory = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appending(path: "Vela", directoryHint: .isDirectory)
        let historyURL = directory.appending(path: "history.json")
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let data = try? JSONEncoder().encode(history)
        try? data?.write(to: historyURL, options: [.atomic])
    }

    func loadHistory() {
        let directory = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appending(path: "Vela", directoryHint: .isDirectory)
        let historyURL = directory.appending(path: "history.json")
        guard let data = try? Data(contentsOf: historyURL),
              let entries = try? JSONDecoder().decode([HistoryEntry].self, from: data) else { return }
        history = entries
    }

    func clearHistory() {
        history.removeAll()
        persistHistory()
    }

    func deleteHistoryEntry(_ id: HistoryEntry.ID) {
        history.removeAll { $0.id == id }
        persistHistory()
    }

    private func persist() {
        let transientIDs = Set(transientTabs.keys)
        let workspaceTabIDs = Set(workspaces.flatMap { $0.tabIDs + $0.archivedTabIDs })
        let persistentTabs = tabs.values.filter { tab in
            workspaceTabIDs.contains(tab.id) && !transientIDs.contains(tab.id)
        }
        let persistentWorkspaces = workspaces.map { workspace in
            var sanitized = workspace
            sanitized.tabIDs = workspace.tabIDs.filter { !transientIDs.contains($0) }
            sanitized.archivedTabIDs = workspace.archivedTabIDs.filter { !transientIDs.contains($0) }
            return sanitized
        }
        let persistentGroups = tabGroups.map { group in
            var sanitized = group
            sanitized.tabIDs = group.tabIDs.filter { !transientIDs.contains($0) && workspaceTabIDs.contains($0) }
            return sanitized
        }
        let persistentActiveTabID = activeTabID.flatMap { tabID in
            transientIDs.contains(tabID) ? nil : tabID
        }

        let persistentFavorites = favoriteTabIDs.filter { !transientIDs.contains($0) }

        let snapshot = BrowserStateSnapshot(
            schemaVersion: 3,
            activeWorkspaceID: activeWorkspaceID,
            activeTabID: persistentActiveTabID,
            workspaces: persistentWorkspaces,
            tabs: persistentTabs,
            themes: themes,
            tabGroups: persistentGroups,
            favoriteTabIDs: persistentFavorites,
            profiles: profiles
        )
        try? persistence.save(snapshot)
    }
}
