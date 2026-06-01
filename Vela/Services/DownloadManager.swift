import Foundation
import WebKit

@MainActor
final class DownloadManager: NSObject, WKDownloadDelegate {
    weak var store: BrowserStore?

    private var downloadMap: [WKDownload: UUID] = [:]

    func startDownload(_ download: WKDownload) {
        let item = DownloadItem(
            filename: "Download",
            url: download.originalRequest?.url ?? URL(string: "about:blank")!
        )
        store?.downloads.insert(item, at: 0)
        downloadMap[download] = item.id
        download.delegate = self
    }

    // MARK: - WKDownloadDelegate

    nonisolated func download(_ download: WKDownload, decideDestinationUsing response: URLResponse, suggestedFilename: String) async -> URL? {
        let downloadsDir = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask)[0]
        let destinationURL = downloadsDir.appending(path: suggestedFilename)

        // Avoid overwriting — append number if needed
        let finalURL = uniqueURL(for: destinationURL)

        await MainActor.run {
            guard let id = downloadMap[download],
                  let index = store?.downloads.firstIndex(where: { $0.id == id }) else { return }
            store?.downloads[index].filename = finalURL.lastPathComponent
            store?.downloads[index].destinationURL = finalURL
        }

        return finalURL
    }

    nonisolated func download(_ download: WKDownload, didReceive data: Int64, totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) {
        Task { @MainActor in
            guard let id = downloadMap[download],
                  let index = store?.downloads.firstIndex(where: { $0.id == id }) else { return }
            store?.downloads[index].bytesReceived = totalBytesWritten
            store?.downloads[index].totalBytes = totalBytesExpectedToWrite
            if totalBytesExpectedToWrite > 0 {
                store?.downloads[index].progress = Double(totalBytesWritten) / Double(totalBytesExpectedToWrite)
            }
        }
    }

    nonisolated func downloadDidFinish(_ download: WKDownload) {
        Task { @MainActor in
            guard let id = downloadMap[download],
                  let index = store?.downloads.firstIndex(where: { $0.id == id }) else { return }
            store?.downloads[index].state = .completed
            store?.downloads[index].progress = 1.0
            downloadMap.removeValue(forKey: download)
        }
    }

    nonisolated func download(_ download: WKDownload, didFailWithError error: Error, resumeData: Data?) {
        Task { @MainActor in
            guard let id = downloadMap[download],
                  let index = store?.downloads.firstIndex(where: { $0.id == id }) else { return }
            store?.downloads[index].state = .failed
            store?.downloads[index].error = error.localizedDescription
            downloadMap.removeValue(forKey: download)
        }
    }

    // MARK: - Helpers

    private nonisolated func uniqueURL(for url: URL) -> URL {
        let fm = FileManager.default
        guard fm.fileExists(atPath: url.path) else { return url }

        let directory = url.deletingLastPathComponent()
        let name = url.deletingPathExtension().lastPathComponent
        let ext = url.pathExtension

        var counter = 1
        var candidate: URL
        repeat {
            let newName = ext.isEmpty ? "\(name) (\(counter))" : "\(name) (\(counter)).\(ext)"
            candidate = directory.appending(path: newName)
            counter += 1
        } while fm.fileExists(atPath: candidate.path)

        return candidate
    }
}
