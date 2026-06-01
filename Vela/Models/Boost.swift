import Foundation

struct Boost: Identifiable, Codable, Equatable {
    var id: UUID
    var hostPattern: String // e.g. "twitter.com", "*.reddit.com"
    var css: String
    var js: String
    var isEnabled: Bool

    init(
        id: UUID = UUID(),
        hostPattern: String,
        css: String = "",
        js: String = "",
        isEnabled: Bool = true
    ) {
        self.id = id
        self.hostPattern = hostPattern
        self.css = css
        self.js = js
        self.isEnabled = isEnabled
    }

    func matches(host: String) -> Bool {
        if hostPattern.hasPrefix("*.") {
            let suffix = String(hostPattern.dropFirst(2))
            return host == suffix || host.hasSuffix("." + suffix)
        }
        return host == hostPattern
    }
}
