import SwiftUI

struct TabSectionView: View {
    let title: String
    let tabs: [BrowserTab]
    let isPinned: Bool

    @Environment(BrowserStore.self) private var store
    @Namespace private var selectionNamespace

    // MARK: - Drag State

    @State private var draggedTabID: BrowserTab.ID?
    @State private var dragOffset: CGFloat = 0
    @State private var insertionIndex: Int?

    /// Approximate height of a single tab row including spacing.
    private let rowHeight: CGFloat = 36

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)

            ForEach(Array(tabs.enumerated()), id: \.element.id) { index, tab in
                TabRowView(tab: tab, isDragging: tab.id == draggedTabID, selectionNamespace: selectionNamespace)
                    .offset(y: offsetForTab(at: index, id: tab.id))
                    .scaleEffect(tab.id == draggedTabID ? 1.03 : 1.0)
                    .shadow(
                        color: tab.id == draggedTabID ? .black.opacity(0.18) : .clear,
                        radius: tab.id == draggedTabID ? 6 : 0,
                        y: tab.id == draggedTabID ? 2 : 0
                    )
                    .zIndex(tab.id == draggedTabID ? 100 : 0)
                    .gesture(dragGesture(for: tab, at: index))
                    .animation(
                        tab.id == draggedTabID ? nil : VelaAnimation.emphasis,
                        value: insertionIndex
                    )
                    .transition(
                        .asymmetric(
                            insertion: .opacity
                                .combined(with: .scale(scale: 0.9, anchor: .top))
                                .combined(with: .offset(y: 8)),
                            removal: .opacity
                                .combined(with: .scale(scale: 0.85, anchor: .top))
                        )
                    )
            }
            .animation(VelaAnimation.emphasis, value: tabs.map(\.id))
        }
    }

    // MARK: - Drag Gesture

    private func dragGesture(for tab: BrowserTab, at index: Int) -> some Gesture {
        DragGesture(minimumDistance: tabs.count > 1 ? 8 : .infinity)
            .onChanged { value in
                if draggedTabID == nil {
                    draggedTabID = tab.id
                }
                dragOffset = value.translation.height

                // Compute insertion index from vertical offset
                let rawIndex = index + Int(round(dragOffset / rowHeight))
                let clamped = max(0, min(tabs.count - 1, rawIndex))
                if clamped != insertionIndex {
                    insertionIndex = clamped
                }
            }
            .onEnded { _ in
                commitReorder(from: index)
            }
    }

    private func commitReorder(from originalIndex: Int) {
        guard let targetIndex = insertionIndex else {
            resetDragState()
            return
        }

        if originalIndex != targetIndex {
            VelaAnimation.withEmphasis {
                store.moveTab(from: originalIndex, to: targetIndex, pinned: isPinned)
            }
        }

        resetDragState()
    }

    private func resetDragState() {
        withAnimation(VelaAnimation.emphasis) {
            draggedTabID = nil
            dragOffset = 0
            insertionIndex = nil
        }
    }

    // MARK: - Offset Computation

    /// Returns the Y offset for a tab at the given index during an active drag.
    private func offsetForTab(at index: Int, id: BrowserTab.ID) -> CGFloat {
        // The dragged tab follows the finger directly
        if id == draggedTabID {
            return dragOffset
        }

        // No active drag — no offset
        guard let draggedIndex = tabs.firstIndex(where: { $0.id == draggedTabID }),
              let target = insertionIndex else {
            return 0
        }

        // Compute how non-dragged tabs shift to create a gap
        if draggedIndex < target {
            // Dragging down: tabs between draggedIndex+1..target shift up
            if index > draggedIndex && index <= target {
                return -rowHeight
            }
        } else if draggedIndex > target {
            // Dragging up: tabs between target..draggedIndex-1 shift down
            if index >= target && index < draggedIndex {
                return rowHeight
            }
        }

        return 0
    }
}
