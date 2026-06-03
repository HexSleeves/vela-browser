import Foundation

enum AuthPageCompatibility {
    static func disablesPeekPreviews(for url: URL) -> Bool {
        guard url.scheme == "https" || url.scheme == "http",
              let host = url.host()?.lowercased() else {
            return false
        }

        if host == "accounts.google.com" {
            return true
        }

        if host.hasPrefix("login.") || host.hasPrefix("signin.") || host.hasPrefix("auth.") {
            return true
        }

        let pathComponents = url.path
            .lowercased()
            .split(separator: "/")
            .map(String.init)

        return pathComponents.contains { component in
            component == "login" ||
            component == "signin" ||
            component == "sign-in" ||
            component == "oauth" ||
            component == "authorize" ||
            component == "sso"
        }
    }
}
