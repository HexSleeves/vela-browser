import Foundation

struct NavigationService {
    var searchBaseURL = URL(string: "https://www.google.com/search")!

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

        var components = URLComponents(url: searchBaseURL, resolvingAgainstBaseURL: false)!
        components.queryItems = [URLQueryItem(name: "q", value: trimmed)]
        return components.url!
    }
}
