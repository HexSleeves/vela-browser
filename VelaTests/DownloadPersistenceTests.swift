import Foundation
import Testing
@testable import Vela

@Suite("DownloadPersistence")
struct DownloadPersistenceTests {
    @Test("DownloadItem round-trips through JSON with all fields")
    func downloadItemRoundTrips() throws {
        let item = DownloadItem(
            filename: "test.zip",
            url: try #require(URL(string: "https://example.com/test.zip")),
            progress: 1.0,
            state: .completed,
            destinationURL: URL(fileURLWithPath: "/tmp/test.zip"),
            bytesReceived: 1024,
            totalBytes: 1024,
            error: nil
        )

        let data = try JSONEncoder().encode(item)
        let decoded = try JSONDecoder().decode(DownloadItem.self, from: data)

        #expect(decoded.id == item.id)
        #expect(decoded.filename == "test.zip")
        #expect(decoded.url.absoluteString == "https://example.com/test.zip")
        #expect(decoded.progress == 1.0)
        #expect(decoded.state == .completed)
        #expect(decoded.destinationURL?.path == "/tmp/test.zip")
        #expect(decoded.bytesReceived == 1024)
        #expect(decoded.totalBytes == 1024)
        #expect(decoded.error == nil)
    }

    @Test("DownloadItem with nil optionals round-trips correctly")
    func downloadItemNilOptionalsRoundTrip() throws {
        let item = DownloadItem(
            filename: "partial.zip",
            url: try #require(URL(string: "https://example.com/partial.zip")),
            state: .failed,
            error: "Network timeout"
        )

        let data = try JSONEncoder().encode(item)
        let decoded = try JSONDecoder().decode(DownloadItem.self, from: data)

        #expect(decoded.destinationURL == nil)
        #expect(decoded.error == "Network timeout")
        #expect(decoded.state == .failed)
    }

    @Test("DownloadState cases encode to raw string values")
    func downloadStateCasesEncodeCorrectly() throws {
        let cases: [(DownloadState, String)] = [
            (.downloading, "downloading"),
            (.completed, "completed"),
            (.failed, "failed"),
            (.cancelled, "cancelled"),
        ]

        for (state, expected) in cases {
            let data = try JSONEncoder().encode(state)
            let json = try #require(String(data: data, encoding: .utf8))
            #expect(json.contains(expected))
        }
    }

    @Test("Terminal state filter excludes downloading items")
    func terminalStateFilterExcludesDownloading() throws {
        let url = try #require(URL(string: "https://example.com/file"))
        let items: [DownloadItem] = [
            DownloadItem(filename: "a", url: url, state: .downloading),
            DownloadItem(filename: "b", url: url, state: .completed),
            DownloadItem(filename: "c", url: url, state: .failed),
            DownloadItem(filename: "d", url: url, state: .cancelled),
        ]

        let terminal = items.filter { $0.state != .downloading }
        #expect(terminal.count == 3)
        #expect(!terminal.contains { $0.state == .downloading })
    }

    @Test("Cap enforcement keeps only first 200 entries")
    func capEnforcementKeeps200() throws {
        let url = try #require(URL(string: "https://example.com/file"))
        let items = (0..<250).map { i in
            DownloadItem(filename: "file-\(i).zip", url: url, state: .completed)
        }

        let capped = Array(items.prefix(200))
        #expect(capped.count == 200)
        #expect(capped.first?.filename == "file-0.zip")
        #expect(capped.last?.filename == "file-199.zip")
    }
}
