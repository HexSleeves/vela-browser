import Foundation
import Testing
@testable import Vela

@Suite("Google sign-in compatibility")
struct GoogleSignInCompatibilityTests {
    @Test("detects Google embedded sign-in rejection URLs")
    func detectsGoogleEmbeddedSignInRejectionURLs() throws {
        let url = try #require(URL(string: "https://accounts.google.com/v3/signin/rejected?continue=https%3A%2F%2Fwww.google.com%2F"))

        #expect(GoogleSignInCompatibility.isEmbeddedSignInRejection(url))
    }

    @Test("does not classify unrelated Google pages as embedded sign-in rejections")
    func doesNotClassifyUnrelatedGooglePages() throws {
        let url = try #require(URL(string: "https://accounts.google.com/v3/signin/identifier?continue=https%3A%2F%2Fwww.google.com%2F"))

        #expect(!GoogleSignInCompatibility.isEmbeddedSignInRejection(url))
    }

    @Test("uses continue URL as the external fallback when available")
    func usesContinueURLAsExternalFallbackWhenAvailable() throws {
        let url = try #require(URL(string: "https://accounts.google.com/v3/signin/rejected?continue=https%3A%2F%2Fwww.google.com%2F"))

        let fallbackURL = GoogleSignInCompatibility.externalFallbackURL(for: url)

        #expect(fallbackURL.absoluteString == "https://www.google.com/")
    }

    @Test("keeps rejected URL as fallback when continue is not web URL")
    func keepsRejectedURLAsFallbackWhenContinueIsNotWebURL() throws {
        let url = try #require(URL(string: "https://accounts.google.com/v3/signin/rejected?continue=javascript%3Aalert(1)"))

        let fallbackURL = GoogleSignInCompatibility.externalFallbackURL(for: url)

        #expect(fallbackURL == url)
    }
}
