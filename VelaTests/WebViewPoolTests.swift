import Foundation
import Testing
@testable import Vela

@MainActor
@Suite("WebViewPool")
struct WebViewPoolTests {
    @Test("web views use Safari-compatible WebKit user agent")
    func webViewsUseSafariCompatibleWebKitUserAgent() throws {
        UserDefaults.standard.set(true, forKey: "uaClearedV3")
        let pool = WebViewPool()

        let webView = pool.webView(for: UUID())
        let userAgent = try #require(webView.customUserAgent)

        #expect(userAgent.contains("Macintosh"))
        #expect(userAgent.contains("AppleWebKit"))
        #expect(userAgent.contains("Version/"))
        #expect(userAgent.contains("Safari/"))
        #expect(!userAgent.contains("Chrome/"))
        #expect(!userAgent.contains("CriOS/"))
    }
}
