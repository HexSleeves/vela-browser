import Foundation

enum GoogleSignInCompatibility {
    static func isEmbeddedSignInRejection(_ url: URL) -> Bool {
        guard url.scheme == "https",
              url.host()?.lowercased() == "accounts.google.com" else {
            return false
        }

        return url.path.localizedCaseInsensitiveContains("/signin/rejected")
    }

    static func externalFallbackURL(for url: URL) -> URL {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let continueValue = components.queryItems?.first(where: { $0.name == "continue" })?.value,
              let continueURL = URL(string: continueValue),
              continueURL.scheme == "https" || continueURL.scheme == "http" else {
            return url
        }

        return continueURL
    }
}
