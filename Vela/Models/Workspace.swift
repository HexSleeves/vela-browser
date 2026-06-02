import Foundation

struct Workspace: Identifiable, Codable, Equatable {
    var id: UUID
    var name: String
    var themeID: BrowserTheme.ID
    var tabIDs: [BrowserTab.ID]
    var archivedTabIDs: [BrowserTab.ID]
    var profileID: Profile.ID?

    enum CodingKeys: String, CodingKey {
        case id, name, themeID, tabIDs, archivedTabIDs, profileID
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        themeID = try container.decode(BrowserTheme.ID.self, forKey: .themeID)
        tabIDs = try container.decode([BrowserTab.ID].self, forKey: .tabIDs)
        archivedTabIDs = try container.decode([BrowserTab.ID].self, forKey: .archivedTabIDs)
        profileID = try container.decodeIfPresent(Profile.ID.self, forKey: .profileID)
    }

    init(
        id: UUID = UUID(),
        name: String,
        themeID: BrowserTheme.ID,
        tabIDs: [BrowserTab.ID] = [],
        archivedTabIDs: [BrowserTab.ID] = [],
        profileID: Profile.ID? = nil
    ) {
        self.id = id
        self.name = name
        self.themeID = themeID
        self.tabIDs = tabIDs
        self.archivedTabIDs = archivedTabIDs
        self.profileID = profileID
    }
}
