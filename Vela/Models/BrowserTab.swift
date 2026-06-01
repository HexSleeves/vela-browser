import Foundation

struct BrowserTab: Identifiable, Codable, Equatable {
    var id: UUID
    var title: String
    var url: URL?
    var isPinned: Bool
    var isLoading: Bool
    var estimatedProgress: Double
    var canGoBack: Bool
    var canGoForward: Bool
    var zoomLevel: Double
    var isPlayingAudio: Bool
    var isMuted: Bool
    var lastAccessedAt: Date

    init(
        id: UUID = UUID(),
        title: String = "New Tab",
        url: URL? = nil,
        isPinned: Bool = false,
        isLoading: Bool = false,
        estimatedProgress: Double = 0,
        canGoBack: Bool = false,
        canGoForward: Bool = false,
        zoomLevel: Double = 1.0,
        isPlayingAudio: Bool = false,
        isMuted: Bool = false,
        lastAccessedAt: Date = Date()
    ) {
        self.id = id
        self.title = title
        self.url = url
        self.isPinned = isPinned
        self.isLoading = isLoading
        self.estimatedProgress = estimatedProgress
        self.canGoBack = canGoBack
        self.canGoForward = canGoForward
        self.zoomLevel = zoomLevel
        self.isPlayingAudio = isPlayingAudio
        self.isMuted = isMuted
        self.lastAccessedAt = lastAccessedAt
    }
}
