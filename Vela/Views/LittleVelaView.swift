import SwiftUI

/// A compact popup browser window — inspired by Arc's "Little Arc".
/// Opens links in a minimal chrome window for quick browsing without
/// cluttering the main workspace.
struct LittleVelaView: View {
    @Environment(BrowserStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var urlText = ""
    @State private var littleTabID: BrowserTab.ID?
    @FocusState private var isFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            // Compact toolbar
            HStack(spacing: 8) {
                // Back/Forward
                Button { goBack() } label: {
                    Image(systemName: "chevron.left")
                        .font(.caption)
                }
                .buttonStyle(.plain)
                .disabled(!(store.tabs[littleTabID ?? UUID()]?.canGoBack ?? false))

                Button { goForward() } label: {
                    Image(systemName: "chevron.right")
                        .font(.caption)
                }
                .buttonStyle(.plain)
                .disabled(!(store.tabs[littleTabID ?? UUID()]?.canGoForward ?? false))

                // URL field
                TextField("Search or enter URL…", text: $urlText)
                    .textFieldStyle(.plain)
                    .font(.callout)
                    .focused($isFocused)
                    .onSubmit {
                        loadURL()
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 6)
                    .background(.quaternary, in: RoundedRectangle(cornerRadius: 6))

                // Close
                Button { dismiss() } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(.bar)

            Divider()

            // Web content
            if let tabID = littleTabID {
                BrowserWebView(tabID: tabID)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                VStack(spacing: 12) {
                    Image(systemName: "globe")
                        .font(.largeTitle)
                        .foregroundStyle(.quaternary)
                    Text("Enter a URL to browse")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .onAppear {
            isFocused = true
        }
        .onChange(of: littleTabID) { _, newID in
            if let id = newID, let url = store.tabs[id]?.url {
                urlText = url.absoluteString
            }
        }
    }

    private func loadURL() {
        guard !urlText.isEmpty else { return }

        if littleTabID == nil {
            // Create a standalone tab for the little window
            let tab = BrowserTab(url: nil)
            store.tabs[tab.id] = tab
            littleTabID = tab.id
        }

        guard let tabID = littleTabID else { return }

        // Resolve the input to a URL using the same logic as address bar
        let trimmed = urlText.trimmingCharacters(in: .whitespacesAndNewlines)
        let url: URL
        if let parsed = URL(string: trimmed), parsed.scheme != nil {
            url = parsed
        } else if trimmed.contains(".") && !trimmed.contains(" ") {
            url = URL(string: "https://\(trimmed)") ?? URL(string: "https://google.com/search?q=\(trimmed)")!
        } else {
            url = URL(string: "https://google.com/search?q=\(trimmed.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? trimmed)")!
        }

        store.tabs[tabID]?.url = url
        store.tabs[tabID]?.title = url.host() ?? trimmed
        store.webViewPool.load(url, in: tabID)
        urlText = url.absoluteString
    }

    private func goBack() {
        guard let tabID = littleTabID else { return }
        store.webViewPool.goBack(tabID: tabID)
    }

    private func goForward() {
        guard let tabID = littleTabID else { return }
        store.webViewPool.goForward(tabID: tabID)
    }
}
