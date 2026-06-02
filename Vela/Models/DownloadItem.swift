import Foundation

enum DownloadState: String, Codable {
    case downloading
    case completed
    case failed
    case cancelled
}

struct DownloadItem: Identifiable, Codable, Equatable {
    let id: UUID
    var filename: String
    var url: URL
    var progress: Double // 0.0 - 1.0
    var state: DownloadState
    var destinationURL: URL?
    var bytesReceived: Int64
    var totalBytes: Int64
    var error: String?

    init(
        id: UUID = UUID(),
        filename: String,
        url: URL,
        progress: Double = 0,
        state: DownloadState = .downloading,
        destinationURL: URL? = nil,
        bytesReceived: Int64 = 0,
        totalBytes: Int64 = -1,
        error: String? = nil
    ) {
        self.id = id
        self.filename = filename
        self.url = url
        self.progress = progress
        self.state = state
        self.destinationURL = destinationURL
        self.bytesReceived = bytesReceived
        self.totalBytes = totalBytes
        self.error = error
    }
}
