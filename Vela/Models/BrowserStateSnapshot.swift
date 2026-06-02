import Foundation

struct BrowserStateSnapshot: Codable, Equatable {
    var schemaVersion: Int
    var activeWorkspaceID: Workspace.ID
    var activeTabID: BrowserTab.ID?
    var workspaces: [Workspace]
    var tabs: [BrowserTab]
    var themes: [BrowserTheme]
    var tabGroups: [TabGroup]
    var favoriteTabIDs: [BrowserTab.ID]

    enum CodingKeys: String, CodingKey {
        case schemaVersion, activeWorkspaceID, activeTabID, workspaces, tabs, themes, tabGroups, favoriteTabIDs
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        schemaVersion = try container.decode(Int.self, forKey: .schemaVersion)
        activeWorkspaceID = try container.decode(Workspace.ID.self, forKey: .activeWorkspaceID)
        activeTabID = try container.decodeIfPresent(BrowserTab.ID.self, forKey: .activeTabID)
        workspaces = try container.decode([Workspace].self, forKey: .workspaces)
        tabs = try container.decode([BrowserTab].self, forKey: .tabs)
        themes = try container.decode([BrowserTheme].self, forKey: .themes)
        tabGroups = try container.decodeIfPresent([TabGroup].self, forKey: .tabGroups) ?? []
        favoriteTabIDs = try container.decodeIfPresent([BrowserTab.ID].self, forKey: .favoriteTabIDs) ?? []
    }

    init(
        schemaVersion: Int,
        activeWorkspaceID: Workspace.ID,
        activeTabID: BrowserTab.ID?,
        workspaces: [Workspace],
        tabs: [BrowserTab],
        themes: [BrowserTheme],
        tabGroups: [TabGroup] = [],
        favoriteTabIDs: [BrowserTab.ID] = []
    ) {
        self.schemaVersion = schemaVersion
        self.activeWorkspaceID = activeWorkspaceID
        self.activeTabID = activeTabID
        self.workspaces = workspaces
        self.tabs = tabs
        self.themes = themes
        self.tabGroups = tabGroups
        self.favoriteTabIDs = favoriteTabIDs
    }
}
