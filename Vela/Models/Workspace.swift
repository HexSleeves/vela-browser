import Foundation

struct Workspace: Identifiable, Codable, Equatable {
    var id: UUID
    var name: String
    var themeID: BrowserTheme.ID
    var tabIDs: [BrowserTab.ID]
    var archivedTabIDs: [BrowserTab.ID]

    init(
        id: UUID = UUID(),
        name: String,
        themeID: BrowserTheme.ID,
        tabIDs: [BrowserTab.ID] = [],
        archivedTabIDs: [BrowserTab.ID] = []
    ) {
        self.id = id
        self.name = name
        self.themeID = themeID
        self.tabIDs = tabIDs
        self.archivedTabIDs = archivedTabIDs
    }
}
