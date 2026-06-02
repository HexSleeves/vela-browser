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
    var isReaderMode: Bool
    var errorDescription: String?
    var errorCode: Int?
    var lastAccessedAt: Date
    var designatedURL: URL?
    var isStub: Bool

    enum CodingKeys: String, CodingKey {
        case id, title, url, isPinned, isLoading, estimatedProgress, canGoBack, canGoForward
        case zoomLevel, isPlayingAudio, isMuted, isReaderMode, errorDescription, errorCode, lastAccessedAt
        case designatedURL, isStub
    }

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
        isReaderMode: Bool = false,
        lastAccessedAt: Date = Date(),
        designatedURL: URL? = nil,
        isStub: Bool = false
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
        self.isReaderMode = isReaderMode
        self.lastAccessedAt = lastAccessedAt
        self.designatedURL = designatedURL
        self.isStub = isStub
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        title = try container.decode(String.self, forKey: .title)
        url = try container.decodeIfPresent(URL.self, forKey: .url)
        isPinned = try container.decode(Bool.self, forKey: .isPinned)
        isLoading = try container.decode(Bool.self, forKey: .isLoading)
        estimatedProgress = try container.decode(Double.self, forKey: .estimatedProgress)
        canGoBack = try container.decode(Bool.self, forKey: .canGoBack)
        canGoForward = try container.decode(Bool.self, forKey: .canGoForward)
        zoomLevel = try container.decode(Double.self, forKey: .zoomLevel)
        isPlayingAudio = try container.decode(Bool.self, forKey: .isPlayingAudio)
        isMuted = try container.decode(Bool.self, forKey: .isMuted)
        isReaderMode = try container.decode(Bool.self, forKey: .isReaderMode)
        errorDescription = try container.decodeIfPresent(String.self, forKey: .errorDescription)
        errorCode = try container.decodeIfPresent(Int.self, forKey: .errorCode)
        lastAccessedAt = try container.decode(Date.self, forKey: .lastAccessedAt)
        designatedURL = try container.decodeIfPresent(URL.self, forKey: .designatedURL)
        isStub = try container.decodeIfPresent(Bool.self, forKey: .isStub) ?? false
    }
}
