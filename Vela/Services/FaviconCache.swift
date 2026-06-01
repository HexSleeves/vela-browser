import Foundation

actor FaviconCache {
    static let shared = FaviconCache()

    private var memoryCache: [String: Data] = [:]
    private let directory: URL

    init(fileManager: FileManager = .default) {
        directory = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appending(path: "Vela", directoryHint: .isDirectory)
            .appending(path: "Favicons", directoryHint: .isDirectory)
        try? fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    func faviconData(for pageURL: URL?) async -> Data? {
        guard let host = pageURL?.host()?.lowercased(), !host.isEmpty else {
            return nil
        }

        if let cached = memoryCache[host] {
            return cached
        }

        let fileURL = cacheFileURL(for: host)
        if let data = try? Data(contentsOf: fileURL) {
            memoryCache[host] = data
            return data
        }

        guard let remoteURL = URL(string: "https://www.google.com/s2/favicons?domain=\(host)&sz=64") else {
            return nil
        }

        do {
            let (data, response) = try await URLSession.shared.data(from: remoteURL)
            guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode), !data.isEmpty else {
                return nil
            }
            memoryCache[host] = data
            try? data.write(to: fileURL, options: [.atomic])
            return data
        } catch {
            return nil
        }
    }

    func clear() {
        memoryCache.removeAll()
        try? FileManager.default.removeItem(at: directory)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    private func cacheFileURL(for host: String) -> URL {
        let safeHost = host.map { character in
            character.isLetter || character.isNumber || character == "." || character == "-" ? character : "-"
        }
        return directory.appending(path: String(safeHost) + ".png")
    }
}
