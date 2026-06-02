import Foundation

struct Profile: Identifiable, Codable, Equatable {
    var id: UUID
    var name: String
    var dataStoreIdentifier: UUID?  // nil = default profile using .default()

    init(id: UUID = UUID(), name: String, dataStoreIdentifier: UUID? = UUID()) {
        self.id = id
        self.name = name
        self.dataStoreIdentifier = dataStoreIdentifier
    }

    static func makeDefault() -> Profile {
        Profile(id: UUID(), name: "Default", dataStoreIdentifier: nil)
    }
}
