import Foundation

struct BrowserPersistence {
    private let stateURL: URL
    private let fileManager: FileManager

    init(
        applicationSupportDirectory: URL? = nil,
        fileManager: FileManager = .default
    ) {
        self.fileManager = fileManager

        let baseDirectory = applicationSupportDirectory ?? fileManager.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        )[0].appending(path: "Vela", directoryHint: .isDirectory)

        self.stateURL = baseDirectory.appending(path: "browser-state.json")
    }

    func load() throws -> BrowserStateSnapshot? {
        guard fileManager.fileExists(atPath: stateURL.path) else {
            return nil
        }

        let data = try Data(contentsOf: stateURL)
        return try JSONDecoder.browserState.decode(BrowserStateSnapshot.self, from: data)
    }

    func save(_ snapshot: BrowserStateSnapshot) throws {
        let directory = stateURL.deletingLastPathComponent()
        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        let data = try JSONEncoder.browserState.encode(snapshot)
        try data.write(to: stateURL, options: [.atomic])
    }
}

private extension JSONEncoder {
    static var browserState: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .deferredToDate
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return encoder
    }
}

private extension JSONDecoder {
    static var browserState: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .deferredToDate
        return decoder
    }
}
