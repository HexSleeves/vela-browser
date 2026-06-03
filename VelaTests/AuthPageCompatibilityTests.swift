import Foundation
import Testing
@testable import Vela

@Suite("Auth page compatibility")
struct AuthPageCompatibilityTests {
    @Test("disables peek previews on Google account challenge pages")
    func disablesPeekPreviewsOnGoogleAccountChallengePages() throws {
        let url = try #require(URL(string: "https://accounts.google.com/v3/signin/challenge/selection"))

        #expect(AuthPageCompatibility.disablesPeekPreviews(for: url))
    }

    @Test("disables peek previews on common auth hosts")
    func disablesPeekPreviewsOnCommonAuthHosts() throws {
        let urls = [
            try #require(URL(string: "https://login.example.com/session")),
            try #require(URL(string: "https://signin.example.com/")),
            try #require(URL(string: "https://auth.example.com/oauth/authorize"))
        ]

        for url in urls {
            #expect(AuthPageCompatibility.disablesPeekPreviews(for: url))
        }
    }

    @Test("keeps peek previews enabled on ordinary pages")
    func keepsPeekPreviewsEnabledOnOrdinaryPages() throws {
        let urls = [
            try #require(URL(string: "https://www.google.com/search?q=vela")),
            try #require(URL(string: "https://example.com/articles/signin-history")),
            try #require(URL(string: "https://developer.apple.com/documentation/webkit"))
        ]

        for url in urls {
            #expect(!AuthPageCompatibility.disablesPeekPreviews(for: url))
        }
    }
}
