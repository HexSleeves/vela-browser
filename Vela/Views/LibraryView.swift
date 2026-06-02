import SwiftUI

struct LibraryView: View {
    @Environment(BrowserStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var searchText = ""
    @AppStorage("librarySelectedSegment") private var selectedSegment = LibrarySegment.downloads

    enum LibrarySegment: String, CaseIterable {
        case downloads = "Downloads"
        case archived = "Archived"
        case bookmarks = "Bookmarks"
        case history = "History"

        var icon: String {
            switch self {
            case .downloads: return "arrow.down.circle"
            case .archived: return "archivebox"
            case .bookmarks: return "star"
            case .history: return "clock"
            }
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            searchBar
            Divider()
            segmentContent
        }
        .frame(minWidth: 420, minHeight: 500)
    }

    private var header: some View {
        HStack {
            Text("Library")
                .font(.title2.weight(.semibold))

            Spacer()

            Picker("", selection: $selectedSegment) {
                ForEach(LibrarySegment.allCases, id: \.self) { segment in
                    Label(segment.rawValue, systemImage: segment.icon)
                        .tag(segment)
                }
            }
            .pickerStyle(.segmented)
            .frame(maxWidth: 320)

            Spacer()

            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
        }
        .padding()
    }

    private var searchBar: some View {
        TextField("Search \(selectedSegment.rawValue.lowercased())…", text: $searchText)
            .textFieldStyle(.roundedBorder)
            .padding(.horizontal)
            .padding(.bottom, 8)
    }

    @ViewBuilder
    private var segmentContent: some View {
        switch selectedSegment {
        case .downloads:
            downloadsSegment
        case .archived:
            archivedSegment
        case .bookmarks:
            bookmarksSegment
        case .history:
            historySegment
        }
    }

    // MARK: - Downloads

    private var filteredDownloads: [DownloadItem] {
        guard !searchText.isEmpty else { return store.downloads }
        let query = searchText.lowercased()
        return store.downloads.filter {
            $0.filename.lowercased().contains(query) ||
            $0.url.absoluteString.lowercased().contains(query)
        }
    }

    private var downloadsSegment: some View {
        Group {
            if filteredDownloads.isEmpty {
                emptyState(title: "No Downloads", icon: "arrow.down.circle", message: searchText.isEmpty ? "Downloads will appear here." : "No results for \"\(searchText)\"")
            } else {
                List {
                    if !searchText.isEmpty || store.downloads.contains(where: { $0.state != .downloading }) {
                        HStack {
                            Spacer()
                            Button("Clear Completed") {
                                VelaAnimation.withMicro {
                                    store.clearCompletedDownloads()
                                }
                            }
                            .buttonStyle(.plain)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        }
                    }

                    ForEach(filteredDownloads) { item in
                        downloadRow(item)
                    }
                }
                .listStyle(.inset)
            }
        }
    }

    private func downloadRow(_ item: DownloadItem) -> some View {
        HStack(spacing: 10) {
            Image(systemName: downloadIcon(item.state))
                .foregroundStyle(downloadColor(item.state))
                .frame(width: 20)

            VStack(alignment: .leading, spacing: 4) {
                Text(item.filename)
                    .lineLimit(1)
                    .font(.body)

                if item.state == .downloading {
                    ProgressView(value: item.progress)
                        .progressViewStyle(.linear)
                    Text(downloadProgressText(item))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                } else if item.state == .failed {
                    Text(item.error ?? "Download failed")
                        .font(.caption2)
                        .foregroundStyle(.red)
                } else if item.state == .completed {
                    Text("Completed")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                } else if item.state == .cancelled {
                    Text("Cancelled")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            if item.state == .completed, let url = item.destinationURL {
                Button {
                    NSWorkspace.shared.activateFileViewerSelecting([url])
                } label: {
                    Image(systemName: "folder")
                        .font(.caption)
                }
                .buttonStyle(.plain)
                .help("Show in Finder")
            }
        }
        .padding(.vertical, 2)
    }

    private func downloadIcon(_ state: DownloadState) -> String {
        switch state {
        case .downloading: return "arrow.down.circle"
        case .completed: return "checkmark.circle.fill"
        case .failed: return "xmark.circle.fill"
        case .cancelled: return "minus.circle"
        }
    }

    private func downloadColor(_ state: DownloadState) -> Color {
        switch state {
        case .downloading: return .accentColor
        case .completed: return .green
        case .failed: return .red
        case .cancelled: return .secondary
        }
    }

    private func downloadProgressText(_ item: DownloadItem) -> String {
        if item.totalBytes > 0 {
            let received = ByteCountFormatter.string(fromByteCount: item.bytesReceived, countStyle: .file)
            let total = ByteCountFormatter.string(fromByteCount: item.totalBytes, countStyle: .file)
            return "\(received) of \(total)"
        }
        return ByteCountFormatter.string(fromByteCount: item.bytesReceived, countStyle: .file)
    }

    // MARK: - Archived

    private var allArchivedTabs: [(tab: BrowserTab, workspaceName: String)] {
        store.workspaces.flatMap { ws in
            ws.archivedTabIDs.compactMap { id in
                guard let tab = store.tabs[id] else { return nil }
                return (tab: tab, workspaceName: ws.name)
            }
        }
    }

    private var filteredArchived: [(tab: BrowserTab, workspaceName: String)] {
        guard !searchText.isEmpty else { return allArchivedTabs }
        let query = searchText.lowercased()
        return allArchivedTabs.filter {
            $0.tab.title.lowercased().contains(query) ||
            ($0.tab.url?.absoluteString.lowercased().contains(query) ?? false)
        }
    }

    private var archivedSegment: some View {
        Group {
            if filteredArchived.isEmpty {
                emptyState(title: "No Archived Tabs", icon: "archivebox", message: searchText.isEmpty ? "Stale tabs will appear here after archiving." : "No results for \"\(searchText)\"")
            } else {
                List {
                    ForEach(filteredArchived, id: \.tab.id) { entry in
                        Button {
                            VelaAnimation.withEmphasis {
                                store.restoreArchivedTab(entry.tab.id)
                            }
                            dismiss()
                        } label: {
                            HStack(spacing: 10) {
                                FaviconView(url: entry.tab.url, size: 16)

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(entry.tab.title)
                                        .lineLimit(1)
                                        .font(.body)

                                    Text(entry.tab.url?.absoluteString ?? "No URL")
                                        .lineLimit(1)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }

                                Spacer()

                                Text(entry.workspaceName)
                                    .font(.caption2)
                                    .foregroundStyle(.tertiary)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(.quaternary, in: Capsule())
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }
                .listStyle(.inset)
            }
        }
    }

    // MARK: - Bookmarks

    private var filteredBookmarks: [Bookmark] {
        guard !searchText.isEmpty else { return store.bookmarks }
        let query = searchText.lowercased()
        return store.bookmarks.filter {
            $0.title.lowercased().contains(query) ||
            $0.url.absoluteString.lowercased().contains(query)
        }
    }

    private var bookmarksSegment: some View {
        Group {
            if filteredBookmarks.isEmpty {
                emptyState(title: "No Bookmarks", icon: "star", message: searchText.isEmpty ? "Bookmarked pages will appear here." : "No results for \"\(searchText)\"")
            } else {
                List {
                    ForEach(filteredBookmarks) { bookmark in
                        Button {
                            store.loadAddressInput(bookmark.url.absoluteString)
                            dismiss()
                        } label: {
                            HStack(spacing: 10) {
                                Image(systemName: "star.fill")
                                    .foregroundStyle(.yellow)
                                    .font(.caption)
                                    .frame(width: 16)

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(bookmark.title)
                                        .lineLimit(1)
                                        .font(.body)

                                    Text(bookmark.url.absoluteString)
                                        .lineLimit(1)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }

                                Spacer()

                                Text(bookmark.createdAt, style: .date)
                                    .font(.caption2)
                                    .foregroundStyle(.tertiary)
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .contextMenu {
                            Button("Copy URL") {
                                NSPasteboard.general.clearContents()
                                NSPasteboard.general.setString(bookmark.url.absoluteString, forType: .string)
                            }
                            Button("Remove Bookmark", role: .destructive) {
                                VelaAnimation.withMicro {
                                    store.removeBookmark(bookmark.id)
                                }
                            }
                        }
                    }
                }
                .listStyle(.inset)
            }
        }
    }

    // MARK: - History

    private var filteredHistory: [HistoryEntry] {
        guard !searchText.isEmpty else { return store.history }
        let query = searchText.lowercased()
        return store.history.filter {
            $0.title.lowercased().contains(query) ||
            $0.url.absoluteString.lowercased().contains(query)
        }
    }

    private var groupedHistory: [(String, [HistoryEntry])] {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none

        var groups: [(String, [HistoryEntry])] = []
        var currentKey = ""
        var currentEntries: [HistoryEntry] = []

        for entry in filteredHistory {
            let key = formatter.string(from: entry.visitedAt)
            if key != currentKey {
                if !currentEntries.isEmpty {
                    groups.append((currentKey, currentEntries))
                }
                currentKey = key
                currentEntries = [entry]
            } else {
                currentEntries.append(entry)
            }
        }
        if !currentEntries.isEmpty {
            groups.append((currentKey, currentEntries))
        }
        return groups
    }

    private var historySegment: some View {
        Group {
            if filteredHistory.isEmpty {
                emptyState(title: "No History", icon: "clock", message: searchText.isEmpty ? "Pages you visit will appear here." : "No results for \"\(searchText)\"")
            } else {
                VStack(spacing: 0) {
                    HStack {
                        Spacer()
                        Button("Clear All", role: .destructive) {
                            store.clearHistory()
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(.red)
                        .font(.caption)
                        .padding(.horizontal)
                        .padding(.vertical, 4)
                    }

                    List {
                        ForEach(groupedHistory, id: \.0) { date, entries in
                            Section(date) {
                                ForEach(entries) { entry in
                                    Button {
                                        store.loadAddressInput(entry.url.absoluteString)
                                        dismiss()
                                    } label: {
                                        HStack(spacing: 10) {
                                            Image(systemName: "clock")
                                                .foregroundStyle(.secondary)
                                                .frame(width: 16)

                                            VStack(alignment: .leading, spacing: 2) {
                                                Text(entry.title)
                                                    .lineLimit(1)
                                                    .font(.body)

                                                Text(entry.url.absoluteString)
                                                    .lineLimit(1)
                                                    .font(.caption)
                                                    .foregroundStyle(.secondary)
                                            }

                                            Spacer()

                                            Text(entry.visitedAt, style: .time)
                                                .font(.caption)
                                                .foregroundStyle(.tertiary)
                                        }
                                        .contentShape(Rectangle())
                                    }
                                    .buttonStyle(.plain)
                                    .contextMenu {
                                        Button("Copy URL") {
                                            NSPasteboard.general.clearContents()
                                            NSPasteboard.general.setString(entry.url.absoluteString, forType: .string)
                                        }
                                        Button("Delete", role: .destructive) {
                                            store.deleteHistoryEntry(entry.id)
                                        }
                                    }
                                }
                            }
                        }
                    }
                    .listStyle(.inset)
                }
            }
        }
    }

    // MARK: - Empty State

    private func emptyState(title: String, icon: String, message: String) -> some View {
        ContentUnavailableView {
            Label(title, systemImage: icon)
        } description: {
            Text(message)
        }
        .frame(maxHeight: .infinity)
    }
}
