import Foundation

struct HistoryEntry: Identifiable, Codable, Equatable {
    var id: UUID
    var title: String
    var url: URL
    var visitedAt: Date

    init(
        id: UUID = UUID(),
        title: String,
        url: URL,
        visitedAt: Date = Date()
    ) {
        self.id = id
        self.title = title
        self.url = url
        self.visitedAt = visitedAt
    }
}
