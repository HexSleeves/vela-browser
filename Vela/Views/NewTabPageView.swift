import SwiftUI

struct NewTabPageView: View {
    @Environment(BrowserStore.self) private var store
    @State private var searchText = ""
    @FocusState private var isFocused: Bool

    /// Top sites derived from history (most visited domains)
    private var frequentSites: [(String, URL)] {
        var domainCounts: [String: (count: Int, url: URL, title: String)] = [:]
        for entry in store.history {
            guard let host = entry.url.host() else { continue }
            if let existing = domainCounts[host] {
                domainCounts[host] = (existing.count + 1, existing.url, existing.title)
            } else {
                domainCounts[host] = (1, entry.url, entry.title)
            }
        }
        return domainCounts
            .sorted { $0.value.count > $1.value.count }
            .prefix(8)
            .map { ($0.value.title.isEmpty ? $0.key : $0.value.title, $0.value.url) }
    }

    var body: some View {
        ZStack {
            // Theme gradient background
            LinearGradient(
                colors: [
                    store.activeTheme.primary.color.opacity(0.3),
                    store.activeTheme.secondary.color.opacity(0.15),
                    store.activeTheme.accent.color.opacity(0.1)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 24) {
                Spacer()

                // Branding
                Text("Vela")
                    .font(.system(size: 42, weight: .bold, design: .rounded))
                    .foregroundStyle(.primary.opacity(0.7))

                // Search field
                HStack(spacing: 10) {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(.secondary)

                    TextField("Search or enter URL…", text: $searchText)
                        .textFieldStyle(.plain)
                        .font(.title3)
                        .focused($isFocused)
                        .onSubmit {
                            guard !searchText.isEmpty else { return }
                            store.loadAddressInput(searchText)
                            searchText = ""
                        }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
                .frame(maxWidth: 480)

                // Frequent sites grid
                if !frequentSites.isEmpty {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 16), count: 4), spacing: 12) {
                        ForEach(frequentSites, id: \.1) { title, url in
                            Button {
                                store.loadAddressInput(url.absoluteString)
                            } label: {
                                VStack(spacing: 6) {
                                    FaviconView(url: url, size: 24)

                                    Text(title)
                                        .font(.caption)
                                        .lineLimit(1)
                                        .foregroundStyle(.primary)
                                }
                                .frame(width: 80, height: 60)
                                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 8))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .frame(maxWidth: 400)
                    .padding(.top, 8)
                }

                // Shortcut hints
                HStack(spacing: 20) {
                    shortcutHint("⌘T", "New Tab")
                    shortcutHint("⌘K", "Command Bar")
                    shortcutHint("⌘L", "Address Bar")
                    shortcutHint("⌘Y", "History")
                }
                .padding(.top, 8)

                Spacer()
                Spacer()
            }
            .padding(40)
        }
        .onAppear {
            isFocused = true
        }
    }

    private func shortcutHint(_ key: String, _ label: String) -> some View {
        HStack(spacing: 4) {
            Text(key)
                .font(.caption.monospaced())
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(.quaternary, in: RoundedRectangle(cornerRadius: 4))

            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}
