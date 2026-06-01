import SwiftUI

/// A private browsing window that uses an ephemeral (non-persistent) data store.
/// No history, cookies, or cache persist after the window closes.
struct PrivateWindowView: View {
    @Environment(BrowserStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var urlText = ""
    @State private var privateTabID: BrowserTab.ID?
    @State private var canGoBack = false
    @State private var canGoForward = false
    @FocusState private var isFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            // Dark toolbar indicating private mode
            HStack(spacing: 8) {
                Image(systemName: "eye.slash.fill")
                    .font(.caption)
                    .foregroundStyle(.purple)

                Button { goBack() } label: {
                    Image(systemName: "chevron.left")
                        .font(.caption)
                }
                .buttonStyle(.plain)
                .disabled(!canGoBack)

                Button { goForward() } label: {
                    Image(systemName: "chevron.right")
                        .font(.caption)
                }
                .buttonStyle(.plain)
                .disabled(!canGoForward)

                TextField("Search or enter URL…", text: $urlText)
                    .textFieldStyle(.plain)
                    .font(.callout)
                    .focused($isFocused)
                    .onSubmit { loadURL() }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 6)
                    .background(Color.white.opacity(0.1), in: RoundedRectangle(cornerRadius: 6))

                Text("Private")
                    .font(.caption2.bold())
                    .foregroundStyle(.purple)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(.purple.opacity(0.2), in: RoundedRectangle(cornerRadius: 4))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color(nsColor: .controlBackgroundColor).opacity(0.95))

            Divider()

            // Web content
            if let tabID = privateTabID {
                BrowserWebView(tabID: tabID)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                VStack(spacing: 16) {
                    Image(systemName: "eye.slash.circle")
                        .font(.system(size: 48))
                        .foregroundStyle(.purple.opacity(0.6))

                    Text("Private Browsing")
                        .font(.title2.bold())
                        .foregroundStyle(.primary.opacity(0.8))

                    Text("Pages you visit won't appear in your history.\nCookies and site data will be cleared when you close this window.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: 360)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color(nsColor: .controlBackgroundColor).opacity(0.3))
            }
        }
        .onAppear {
            isFocused = true
        }
    }

    private func loadURL() {
        guard !urlText.isEmpty else { return }

        if privateTabID == nil {
            let tab = BrowserTab(url: nil)
            store.tabs[tab.id] = tab
            privateTabID = tab.id
        }

        guard let tabID = privateTabID else { return }

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
        guard let tabID = privateTabID else { return }
        store.webViewPool.goBack(tabID: tabID)
    }

    private func goForward() {
        guard let tabID = privateTabID else { return }
        store.webViewPool.goForward(tabID: tabID)
    }
}
