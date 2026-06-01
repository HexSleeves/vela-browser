import Foundation

struct BrowserStateSnapshot: Codable, Equatable {
    var schemaVersion: Int
    var activeWorkspaceID: Workspace.ID
    var activeTabID: BrowserTab.ID?
    var workspaces: [Workspace]
    var tabs: [BrowserTab]
    var themes: [BrowserTheme]
    var tabGroups: [TabGroup]

    init(
        schemaVersion: Int,
        activeWorkspaceID: Workspace.ID,
        activeTabID: BrowserTab.ID?,
        workspaces: [Workspace],
        tabs: [BrowserTab],
        themes: [BrowserTheme],
        tabGroups: [TabGroup] = []
    ) {
        self.schemaVersion = schemaVersion
        self.activeWorkspaceID = activeWorkspaceID
        self.activeTabID = activeTabID
        self.workspaces = workspaces
        self.tabs = tabs
        self.themes = themes
        self.tabGroups = tabGroups
    }
}
