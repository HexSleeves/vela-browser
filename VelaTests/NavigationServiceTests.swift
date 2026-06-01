import Foundation
import Testing
@testable import Vela

@Suite("NavigationService")
struct NavigationServiceTests {
    @Test("keeps fully qualified URLs unchanged")
    func keepsFullyQualifiedURLsUnchanged() {
        let service = NavigationService()

        let destination = service.destination(for: "https://example.com/docs?q=vela")

        #expect(destination.absoluteString == "https://example.com/docs?q=vela")
    }

    @Test("adds https scheme to likely domains")
    func addsHTTPSchemeToLikelyDomains() {
        let service = NavigationService()

        let destination = service.destination(for: "example.com")

        #expect(destination.absoluteString == "https://example.com")
    }

    @Test("turns plain text into search URL")
    func turnsPlainTextIntoSearchURL() throws {
        let service = NavigationService()

        let destination = service.destination(for: "coffee shops near me")
        let components = try #require(URLComponents(url: destination, resolvingAgainstBaseURL: false))

        #expect(components.scheme == "https")
        #expect(components.host == "www.google.com")
        #expect(components.path == "/search")
        #expect(components.queryItems?.first(where: { $0.name == "q" })?.value == "coffee shops near me")
    }
}
