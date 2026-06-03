import Foundation

struct InstalledExtension: Identifiable, Codable, Equatable {
    var id: UUID
    var name: String
    var version: String
    var extensionBundlePath: String
    var isEnabled: Bool
    var allowInPrivateBrowsing: Bool
    var grantedPermissions: Set<String>
    var deniedPermissions: Set<String>

    init(
        id: UUID = UUID(),
        name: String,
        version: String,
        extensionBundlePath: String,
        isEnabled: Bool = true,
        allowInPrivateBrowsing: Bool = false,
        grantedPermissions: Set<String> = [],
        deniedPermissions: Set<String> = []
    ) {
        self.id = id
        self.name = name
        self.version = version
        self.extensionBundlePath = extensionBundlePath
        self.isEnabled = isEnabled
        self.allowInPrivateBrowsing = allowInPrivateBrowsing
        self.grantedPermissions = grantedPermissions
        self.deniedPermissions = deniedPermissions
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        name = try container.decodeIfPresent(String.self, forKey: .name) ?? "Unknown"
        version = try container.decodeIfPresent(String.self, forKey: .version) ?? "0.0.0"
        extensionBundlePath = try container.decodeIfPresent(String.self, forKey: .extensionBundlePath) ?? ""
        isEnabled = try container.decodeIfPresent(Bool.self, forKey: .isEnabled) ?? true
        allowInPrivateBrowsing = try container.decodeIfPresent(Bool.self, forKey: .allowInPrivateBrowsing) ?? false
        grantedPermissions = try container.decodeIfPresent(Set<String>.self, forKey: .grantedPermissions) ?? []
        deniedPermissions = try container.decodeIfPresent(Set<String>.self, forKey: .deniedPermissions) ?? []
    }
}
