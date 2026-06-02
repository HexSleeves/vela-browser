import Foundation

struct RoutingRule: Identifiable, Codable, Equatable {
    var id: UUID
    var urlPattern: String
    var matchType: MatchType
    var targetWorkspaceID: Workspace.ID?
    var isEnabled: Bool

    enum MatchType: String, Codable, CaseIterable {
        case domain
        case contains
        case prefix
    }

    init(
        id: UUID = UUID(),
        urlPattern: String,
        matchType: MatchType = .domain,
        targetWorkspaceID: Workspace.ID? = nil,
        isEnabled: Bool = true
    ) {
        self.id = id
        self.urlPattern = urlPattern
        self.matchType = matchType
        self.targetWorkspaceID = targetWorkspaceID
        self.isEnabled = isEnabled
    }

    func matches(_ url: URL) -> Bool {
        guard isEnabled else { return false }
        let urlString = url.absoluteString.lowercased()
        let pattern = urlPattern.lowercased()

        switch matchType {
        case .domain:
            guard let host = url.host()?.lowercased() else { return false }
            return host == pattern || host.hasSuffix("." + pattern)
        case .contains:
            return urlString.contains(pattern)
        case .prefix:
            return urlString.hasPrefix(pattern)
        }
    }
}
