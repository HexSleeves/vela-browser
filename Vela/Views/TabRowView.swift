import SwiftUI

struct TabRowView: View {
    let tab: BrowserTab
    var isDragging: Bool = false
    var selectionNamespace: Namespace.ID

    @Environment(BrowserStore.self) private var store
    @State private var isHovered = false

    private var isSelected: Bool {
        tab.id == store.activeTabID
    }

    var body: some View {
        Button {
            if !isDragging {
                VelaAnimation.withEmphasis {
                    store.selectTab(tab.id)
                }
            }
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
                    VelaAnimation.withEmphasis {
                        store.closeTab(tab.id)
                    }
                } label: {
                    Image(systemName: "xmark")
                        .font(.caption)
                }
                .buttonStyle(.plain)
                .opacity(closeButtonOpacity)
                .animation(VelaAnimation.micro, value: isHovered)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 7)
            .background {
                if isSelected {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.primary.opacity(0.08))
                        .matchedGeometryEffect(id: "selection", in: selectionNamespace)
                } else if isHovered && !isDragging {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.primary.opacity(0.04))
                }
            }
            .animation(VelaAnimation.micro, value: isHovered)
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            guard !isDragging else { return }
            isHovered = hovering
        }
        .animation(VelaAnimation.emphasis, value: store.activeTabID)
        .contextMenu {
            Button(tab.isPinned ? "Unpin Tab" : "Pin Tab") {
                store.setPinned(tab.id, isPinned: !tab.isPinned)
            }

            Button("Close Tab") {
                VelaAnimation.withEmphasis {
                    store.closeTab(tab.id)
                }
            }
        }
    }

    /// Close button visibility: always visible when selected, fades in on hover, hidden otherwise.
    private var closeButtonOpacity: Double {
        if isSelected { return 1.0 }
        if isHovered && !isDragging { return 0.8 }
        return 0.0
    }
}
