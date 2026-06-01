import SwiftUI

struct TabSectionView: View {
    let title: String
    let tabs: [BrowserTab]
    let isPinned: Bool

    @Environment(BrowserStore.self) private var store
    @Namespace private var selectionNamespace

    // MARK: - Drag State

    @State private var draggedTabID: BrowserTab.ID?
    @State private var dragTranslation: CGSize = .zero
    @State private var insertionIndex: Int?

    /// Approximate height of a single tab row including spacing.
    private let rowHeight: CGFloat = 40

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if !title.isEmpty {
                Text(title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
            }

            ForEach(Array(tabs.enumerated()), id: \.element.id) { index, tab in
                if insertionMarkerPosition == index {
                    insertionIndicator
                }

                TabRowView(tab: tab, isDragging: tab.id == draggedTabID, selectionNamespace: selectionNamespace)
                    .opacity(tab.id == draggedTabID ? 0.96 : 1)
                    .offset(offsetForTab(at: index, id: tab.id))
                    .scaleEffect(tab.id == draggedTabID ? 1.045 : 1.0)
                    .rotationEffect(.degrees(tab.id == draggedTabID ? Double(max(min(dragTranslation.width / 90, 2.2), -2.2)) : 0))
                    .shadow(
                        color: tab.id == draggedTabID ? .black.opacity(0.24) : .clear,
                        radius: tab.id == draggedTabID ? 14 : 0,
                        y: tab.id == draggedTabID ? 8 : 0
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

            if insertionMarkerPosition == tabs.count {
                insertionIndicator
            }
        }
        .animation(VelaAnimation.emphasis, value: tabs.map(\.id))
    }

    // MARK: - Drag Gesture

    private func dragGesture(for tab: BrowserTab, at index: Int) -> some Gesture {
        DragGesture(minimumDistance: tabs.count > 1 ? 6 : 10_000)
            .onChanged { value in
                if draggedTabID == nil {
                    withAnimation(VelaAnimation.micro) {
                        draggedTabID = tab.id
                    }
                }

                dragTranslation = value.translation

                let rawIndex = index + Int(round(dragTranslation.height / rowHeight))
                let clamped = max(0, min(tabs.count - 1, rawIndex))
                if clamped != insertionIndex {
                    withAnimation(VelaAnimation.emphasis) {
                        insertionIndex = clamped
                    }
                }
            }
            .onEnded { _ in
                commitReorder(tabID: tab.id, from: index)
            }
    }

    private func commitReorder(tabID: BrowserTab.ID, from originalIndex: Int) {
        guard let targetIndex = insertionIndex else {
            resetDragState()
            return
        }

        if originalIndex != targetIndex {
            VelaAnimation.withEmphasis {
                store.moveTab(tabID, toSectionIndex: targetIndex, sectionTabIDs: tabs.map(\.id))
            }
        }

        resetDragState()
    }

    private func resetDragState() {
        withAnimation(VelaAnimation.emphasis) {
            draggedTabID = nil
            dragTranslation = .zero
            insertionIndex = nil
        }
    }

    // MARK: - Drag Visuals

    private var insertionMarkerPosition: Int? {
        guard let draggedID = draggedTabID,
              let draggedIndex = tabs.firstIndex(where: { $0.id == draggedID }),
              let target = insertionIndex,
              target != draggedIndex else {
            return nil
        }
        return draggedIndex < target ? target + 1 : target
    }

    private var insertionIndicator: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(store.activeTheme.accent.color)
                .frame(width: 5, height: 5)
            Capsule()
                .fill(store.activeTheme.accent.color.opacity(0.75))
                .frame(height: 3)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 2)
        .transition(.opacity.combined(with: .scale(scale: 0.92)))
    }

    /// Returns the offset for a tab at the given index during an active drag.
    private func offsetForTab(at index: Int, id: BrowserTab.ID) -> CGSize {
        if id == draggedTabID {
            return CGSize(width: dragTranslation.width, height: dragTranslation.height)
        }

        guard let draggedIndex = tabs.firstIndex(where: { $0.id == draggedTabID }),
              let target = insertionIndex else {
            return .zero
        }

        if draggedIndex < target, index > draggedIndex && index <= target {
            return CGSize(width: 0, height: -rowHeight)
        }

        if draggedIndex > target, index >= target && index < draggedIndex {
            return CGSize(width: 0, height: rowHeight)
        }

        return .zero
    }
}
