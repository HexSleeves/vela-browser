import SwiftUI

/// Full-screen overlay that dims the background and hosts the command bar.
struct CommandBarOverlay: View {
    @Environment(BrowserStore.self) private var store

    var body: some View {
        ZStack {
            Color.black.opacity(0.3)
                .ignoresSafeArea()
                .onTapGesture {
                    dismiss()
                }

            CommandBarView()
                .frame(maxWidth: 560)
                .padding(.bottom, 200)
        }
    }

    private func dismiss() {
        VelaAnimation.withEmphasis {
            store.isCommandBarVisible = false
        }
    }
}

struct CommandBarView: View {
    @Environment(BrowserStore.self) private var store
    @State private var query = ""
    @State private var selectedIndex = 0
    @FocusState private var isFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            // Search field
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)

                TextField("Search tabs, history, or the web…", text: $query)
                    .textFieldStyle(.plain)
                    .font(.title3)
                    .focused($isFocused)
                    .onSubmit {
                        submitSelection()
                    }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)

            if !results.isEmpty {
                Divider()

                ScrollView {
                    VStack(spacing: 2) {
                        ForEach(Array(results.enumerated()), id: \.element.id) { index, result in
                            CommandBarRow(result: result, isSelected: index == selectedIndex)
                                .onTapGesture {
                                    selectResult(result)
                                }
                        }
                    }
                    .padding(6)
                }
                .frame(maxHeight: 320)
            }
        }
        .background(.ultraThickMaterial, in: RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.25), radius: 20, y: 8)
        .onAppear {
            isFocused = true
            query = ""
            selectedIndex = 0
        }
        .onKeyPress(.escape) {
            dismiss()
            return .handled
        }
        .onKeyPress(.downArrow) {
            if selectedIndex < results.count - 1 { selectedIndex += 1 }
            return .handled
        }
        .onKeyPress(.upArrow) {
            if selectedIndex > 0 { selectedIndex -= 1 }
            return .handled
        }
        .onChange(of: query) {
            selectedIndex = 0
        }
    }

    // MARK: - Combined Results

    private var results: [CommandBarResult] {
        let tabResults = filteredTabs.map { CommandBarResult.tab($0) }
        let historyResults = filteredHistory.map { CommandBarResult.history($0) }
        return (tabResults + historyResults).prefix(10).map { $0 }
    }

    private var filteredTabs: [BrowserTab] {
        let allTabs = Array(store.tabs.values)
        guard !query.isEmpty else {
            return allTabs.sorted { $0.lastAccessedAt > $1.lastAccessedAt }.prefix(5).map { $0 }
        }

        let lowered = query.lowercased()
        return allTabs
            .filter { $0.title.lowercased().contains(lowered) || ($0.url?.absoluteString.lowercased().contains(lowered) ?? false) }
            .sorted { $0.lastAccessedAt > $1.lastAccessedAt }
            .prefix(5)
            .map { $0 }
    }

    private var filteredHistory: [HistoryEntry] {
        guard !query.isEmpty else { return [] }
        let lowered = query.lowercased()
        // Exclude URLs that match open tabs (they're already shown)
        let openURLs = Set(store.tabs.values.compactMap(\.url?.absoluteString))
        return store.history
            .filter { entry in
                !openURLs.contains(entry.url.absoluteString) &&
                (entry.title.lowercased().contains(lowered) || entry.url.absoluteString.lowercased().contains(lowered))
            }
            .prefix(5)
            .map { $0 }
    }

    // MARK: - Actions

    private func submitSelection() {
        if !results.isEmpty, selectedIndex < results.count {
            selectResult(results[selectedIndex])
        } else if !query.isEmpty {
            store.loadAddressInput(query)
            dismiss()
        }
    }

    private func selectResult(_ result: CommandBarResult) {
        switch result {
        case .tab(let tab):
            VelaAnimation.withEmphasis {
                store.selectTab(tab.id)
                store.isCommandBarVisible = false
            }
        case .history(let entry):
            store.loadAddressInput(entry.url.absoluteString)
            VelaAnimation.withEmphasis {
                store.isCommandBarVisible = false
            }
        }
    }

    private func dismiss() {
        VelaAnimation.withEmphasis {
            store.isCommandBarVisible = false
        }
    }
}

// MARK: - Result Model

enum CommandBarResult: Identifiable {
    case tab(BrowserTab)
    case history(HistoryEntry)

    var id: String {
        switch self {
        case .tab(let tab): return "tab-\(tab.id)"
        case .history(let entry): return "history-\(entry.id)"
        }
    }
}

// MARK: - Result Row

private struct CommandBarRow: View {
    let result: CommandBarResult
    let isSelected: Bool

    var body: some View {
        HStack(spacing: 10) {
            resultIcon
                .frame(width: 18, height: 18)

            VStack(alignment: .leading, spacing: 2) {
                Text(resultTitle)
                    .lineLimit(1)
                    .font(.body)

                Text(resultURL)
                    .lineLimit(1)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            resultBadge
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(
            isSelected ? Color.accentColor.opacity(0.15) : Color.clear,
            in: RoundedRectangle(cornerRadius: 8)
        )
        .contentShape(Rectangle())
    }

    @ViewBuilder
    private var resultIcon: some View {
        switch result {
        case .tab(let tab):
            if let host = tab.url?.host(),
               let url = URL(string: "https://www.google.com/s2/favicons?domain=\(host)&sz=32") {
                AsyncImage(url: url) { phase in
                    if case .success(let image) = phase {
                        image.resizable().aspectRatio(contentMode: .fit)
                    } else {
                        Image(systemName: "globe").foregroundStyle(.secondary)
                    }
                }
            } else {
                Image(systemName: "globe").foregroundStyle(.secondary)
            }
        case .history:
            Image(systemName: "clock").foregroundStyle(.secondary)
        }
    }

    private var resultTitle: String {
        switch result {
        case .tab(let tab): return tab.title
        case .history(let entry): return entry.title
        }
    }

    private var resultURL: String {
        switch result {
        case .tab(let tab): return tab.url?.absoluteString ?? ""
        case .history(let entry): return entry.url.absoluteString
        }
    }

    @ViewBuilder
    private var resultBadge: some View {
        switch result {
        case .tab:
            Text("Tab")
                .font(.caption2)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(.quaternary, in: RoundedRectangle(cornerRadius: 4))
        case .history:
            Text("History")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(.quaternary, in: RoundedRectangle(cornerRadius: 4))
        }
    }
}
