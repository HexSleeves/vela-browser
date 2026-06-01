import Foundation

struct BookmarkImportService {
    enum ImportError: LocalizedError {
        case unreadableFile
        case invalidEncoding
        case fileTooLarge

        var errorDescription: String? {
            switch self {
            case .unreadableFile:
                return "Could not read the bookmark file."
            case .invalidEncoding:
                return "The bookmark file is not valid UTF-8 text."
            case .fileTooLarge:
                return "The bookmark file is too large to import."
            }
        }
    }

    func importBookmarks(from fileURL: URL) throws -> [Bookmark] {
        let values = try fileURL.resourceValues(forKeys: [.isRegularFileKey, .fileSizeKey])
        guard values.isRegularFile == true,
              let fileSize = values.fileSize,
              fileSize <= 10 * 1024 * 1024 else {
            throw ImportError.fileTooLarge
        }

        guard let data = try? Data(contentsOf: fileURL) else {
            throw ImportError.unreadableFile
        }
        guard let html = String(data: data, encoding: .utf8) ?? String(data: data, encoding: .isoLatin1) else {
            throw ImportError.invalidEncoding
        }
        return parseNetscapeBookmarksHTML(html)
    }

    func parseNetscapeBookmarksHTML(_ html: String) -> [Bookmark] {
        let pattern = #"<A\s+[^>]*HREF\s*=\s*[\"']([^\"']+)[\"'][^>]*>(.*?)</A>"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive, .dotMatchesLineSeparators]) else {
            return []
        }

        let nsRange = NSRange(html.startIndex..<html.endIndex, in: html)
        return regex.matches(in: html, range: nsRange).compactMap { match in
            guard match.numberOfRanges >= 3,
                  let hrefRange = Range(match.range(at: 1), in: html),
                  let titleRange = Range(match.range(at: 2), in: html) else {
                return nil
            }

            let href = String(html[hrefRange])
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .htmlDecoded
            let title = String(html[titleRange])
                .replacingOccurrences(of: #"<[^>]+>"#, with: "", options: .regularExpression)
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .htmlDecoded

            guard let url = URL(string: href), ["http", "https"].contains(url.scheme?.lowercased()) else {
                return nil
            }

            return Bookmark(title: title.isEmpty ? (url.host() ?? url.absoluteString) : title, url: url)
        }
    }
}

private extension String {
    var htmlDecoded: String {
        replacingOccurrences(of: "&amp;", with: "&")
            .replacingOccurrences(of: "&quot;", with: "\"")
            .replacingOccurrences(of: "&#39;", with: "'")
            .replacingOccurrences(of: "&lt;", with: "<")
            .replacingOccurrences(of: "&gt;", with: ">")
    }
}
