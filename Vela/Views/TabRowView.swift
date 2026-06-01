import SwiftUI

struct TabRowView: View {
    let tab: BrowserTab
    @Environment(BrowserStore.self) private var store

    var body: some View {
        Button {
            store.selectTab(tab.id)
        } label: {
            HStack(spacing: 8) {
                Image(systemName: tab.isPinned ? "pin.fill" : "globe")
                    .foregroundStyle(.secondary)
                    .frame(width: 18)

                Text(tab.title)
                    .lineLimit(1)

                Spacer(minLength: 8)

                if tab.isLoading {
                    ProgressView()
                        .controlSize(.small)
                }

                Button {
                    store.closeTab(tab.id)
                } label: {
                    Image(systemName: "xmark")
                        .font(.caption)
                }
                .buttonStyle(.plain)
                .opacity(tab.id == store.activeTabID ? 1 : 0.55)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 7)
            .background(tab.id == store.activeTabID ? Color.primary.opacity(0.08) : Color.clear, in: RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button(tab.isPinned ? "Unpin Tab" : "Pin Tab") {
                store.setPinned(tab.id, isPinned: !tab.isPinned)
            }

            Button("Close Tab") {
                store.closeTab(tab.id)
            }
        }
    }
}
