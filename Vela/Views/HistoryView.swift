import SwiftUI

struct HistoryView: View {
    @Environment(BrowserStore.self) private var store
    @State private var searchText = ""
    @Environment(\.dismiss) private var dismiss

    private var filteredHistory: [HistoryEntry] {
        if searchText.isEmpty {
            return store.history
        }
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

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("History")
                    .font(.title2.weight(.semibold))
                Spacer()
                Button("Clear All", role: .destructive) {
                    store.clearHistory()
                }
                .buttonStyle(.plain)
                .foregroundStyle(.red)
                .font(.callout)

                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding()

            // Search
            TextField("Search history…", text: $searchText)
                .textFieldStyle(.roundedBorder)
                .padding(.horizontal)
                .padding(.bottom, 8)

            Divider()

            // History list
            if filteredHistory.isEmpty {
                ContentUnavailableView {
                    Label("No History", systemImage: "clock")
                } description: {
                    Text(searchText.isEmpty ? "Pages you visit will appear here." : "No results for \"\(searchText)\"")
                }
                .frame(maxHeight: .infinity)
            } else {
                List {
                    ForEach(groupedHistory, id: \.0) { date, entries in
                        Section(date) {
                            ForEach(entries) { entry in
                                historyRow(entry)
                            }
                        }
                    }
                }
                .listStyle(.inset)
            }
        }
        .frame(minWidth: 400, minHeight: 500)
    }

    private func historyRow(_ entry: HistoryEntry) -> some View {
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
