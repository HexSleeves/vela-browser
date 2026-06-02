import SwiftUI

struct FavoritesSectionView: View {
    @Environment(BrowserStore.self) private var store
    @State private var draggedID: BrowserTab.ID?

    var body: some View {
        let favorites = store.favoriteTabsWithWorkspace
        guard !favorites.isEmpty else { return AnyView(EmptyView()) }

        return AnyView(
            VStack(alignment: .leading, spacing: 6) {
                Text("FAVORITES")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)

                HStack(spacing: 8) {
                    ForEach(favorites, id: \.tab.id) { item in
                        favoriteButton(item.tab, workspaceID: item.workspaceID)
                    }
                }
            }
        )
    }

    private func favoriteButton(_ tab: BrowserTab, workspaceID: Workspace.ID) -> some View {
        Button {
            VelaAnimation.withEmphasis {
                store.switchWorkspace(workspaceID)
                store.selectTab(tab.id)
            }
        } label: {
            FaviconView(url: tab.url, size: 20)
                .frame(width: 28, height: 28)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(tab.id == store.activeTabID ? Color.primary.opacity(0.1) : Color.clear)
                )
        }
        .buttonStyle(.plain)
        .help(tab.title)
        .contextMenu {
            Button("Remove from Favorites") {
                VelaAnimation.withMicro {
                    store.removeFavorite(tab.id)
                }
            }
        }
        .draggable(tab.id.uuidString) {
            FaviconView(url: tab.url, size: 20)
                .frame(width: 28, height: 28)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 6))
        }
        .dropDestination(for: String.self) { items, _ in
            guard let droppedString = items.first,
                  let droppedID = UUID(uuidString: droppedString),
                  let fromIndex = store.favoriteTabIDs.firstIndex(of: droppedID),
                  let toIndex = store.favoriteTabIDs.firstIndex(of: tab.id),
                  fromIndex != toIndex else { return false }
            VelaAnimation.withLayout {
                store.reorderFavorites(from: fromIndex, to: toIndex)
            }
            return true
        }
    }
}
