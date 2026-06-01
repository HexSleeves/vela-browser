import Foundation

struct TabGroup: Identifiable, Codable, Equatable {
    var id: UUID
    var name: String
    var tabIDs: [BrowserTab.ID]
    var isCollapsed: Bool

    init(
        id: UUID = UUID(),
        name: String,
        tabIDs: [BrowserTab.ID] = [],
        isCollapsed: Bool = false
    ) {
        self.id = id
        self.name = name
        self.tabIDs = tabIDs
        self.isCollapsed = isCollapsed
    }
}
