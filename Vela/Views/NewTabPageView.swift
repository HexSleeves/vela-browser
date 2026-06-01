import SwiftUI

struct NewTabPageView: View {
    @Environment(BrowserStore.self) private var store
    @State private var searchText = ""
    @FocusState private var isFocused: Bool

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

                // Shortcut hints
                HStack(spacing: 20) {
                    shortcutHint("⌘T", "New Tab")
                    shortcutHint("⌘K", "Command Bar")
                    shortcutHint("⌘L", "Address Bar")
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
