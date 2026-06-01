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
    var isFindBarVisible = false
    var findText = ""
    var isCommandBarVisible = false
    var isDownloadsVisible = false
    var downloads: [DownloadItem] = []
    var bookmarks: [Bookmark] = []
    var recentlyClosed: [ClosedTab] = []
    var history: [HistoryEntry] = []

    struct ClosedTab {
        let title: String
        let url: URL?
        let workspaceID: Workspace.ID
        let isPinned: Bool
    }

    private static let maxRecentlyClosed = 10

    private static let maxHistoryEntries = 500

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
            return store
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
        self.downloadManager = DownloadManager()
        self.downloadManager.store = self
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
        // Save to recently closed before removing
        if let tab = tabs[tabID] {
            let wsID = workspaces.first(where: { $0.tabIDs.contains(tabID) })?.id ?? activeWorkspaceID
            let closed = ClosedTab(title: tab.title, url: tab.url, workspaceID: wsID, isPinned: tab.isPinned)
            recentlyClosed.insert(closed, at: 0)
            if recentlyClosed.count > Self.maxRecentlyClosed {
                recentlyClosed = Array(recentlyClosed.prefix(Self.maxRecentlyClosed))
            }
        }

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

        // Record history when page finishes loading
        if wasLoading && !isLoading, let pageURL = tab.url {
            recordHistory(title: tab.title, url: pageURL)
        }

        persist()
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
