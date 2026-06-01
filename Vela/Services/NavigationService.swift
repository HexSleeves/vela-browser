import Foundation

enum SearchEngine: String, CaseIterable, Identifiable {
    case google = "google"
    case duckduckgo = "duckduckgo"
    case bing = "bing"
    case brave = "brave"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .google: return "Google"
        case .duckduckgo: return "DuckDuckGo"
        case .bing: return "Bing"
        case .brave: return "Brave Search"
        }
    }

    var searchURLTemplate: String {
        switch self {
        case .google: return "https://www.google.com/search?q=%@"
        case .duckduckgo: return "https://duckduckgo.com/?q=%@"
        case .bing: return "https://www.bing.com/search?q=%@"
        case .brave: return "https://search.brave.com/search?q=%@"
        }
    }

    func searchURL(for query: String) -> URL {
        let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query
        let urlString = searchURLTemplate.replacingOccurrences(of: "%@", with: encoded)
        return URL(string: urlString)!
    }
}

struct NavigationService {
    var searchEngine: SearchEngine {
        let stored = UserDefaults.standard.string(forKey: "searchEngine") ?? "google"
        return SearchEngine(rawValue: stored) ?? .google
    }

    func destination(for input: String) -> URL {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)

        if let url = URL(string: trimmed), url.scheme != nil {
            return url
        }

        if trimmed.contains("."),
           !trimmed.contains(" "),
           let url = URL(string: "https://\(trimmed)") {
            return url
        }

        return searchEngine.searchURL(for: trimmed)
    }
}
