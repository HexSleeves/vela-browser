import Foundation

struct BrowserStateSnapshot: Codable, Equatable {
    var schemaVersion: Int
    var activeWorkspaceID: Workspace.ID
    var activeTabID: BrowserTab.ID?
    var workspaces: [Workspace]
    var tabs: [BrowserTab]
    var themes: [BrowserTheme]
}
