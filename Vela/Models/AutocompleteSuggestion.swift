import Foundation

struct AutocompleteSuggestion: Identifiable, Hashable {
    enum Kind: String, Hashable {
        case tab
        case bookmark
        case history
        case search
        case url
    }

    let kind: Kind
    let title: String
    let subtitle: String
    let completionText: String
    let url: URL?
    let tabID: BrowserTab.ID?

    init(kind: Kind, title: String, subtitle: String, completionText: String, url: URL?, tabID: BrowserTab.ID? = nil) {
        self.kind = kind
        self.title = title
        self.subtitle = subtitle
        self.completionText = completionText
        self.url = url
        self.tabID = tabID
    }

    var id: String {
        "\(kind.rawValue)-\(completionText)-\(subtitle)"
    }

    var iconName: String {
        switch kind {
        case .tab: "macwindow"
        case .bookmark: "star.fill"
        case .history: "clock"
        case .search: "magnifyingglass"
        case .url: "globe"
        }
    }
}
