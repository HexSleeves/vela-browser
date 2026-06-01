import Foundation

struct BrowserTab: Identifiable, Codable, Equatable {
    var id: UUID
    var title: String
    var url: URL?
    var isPinned: Bool
    var isLoading: Bool
    var estimatedProgress: Double
    var lastAccessedAt: Date

    init(
        id: UUID = UUID(),
        title: String = "New Tab",
        url: URL? = nil,
        isPinned: Bool = false,
        isLoading: Bool = false,
        estimatedProgress: Double = 0,
        lastAccessedAt: Date = Date()
    ) {
        self.id = id
        self.title = title
        self.url = url
        self.isPinned = isPinned
        self.isLoading = isLoading
        self.estimatedProgress = estimatedProgress
        self.lastAccessedAt = lastAccessedAt
    }
}
