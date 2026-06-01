import SwiftUI

struct SidebarView: View {
    @Environment(BrowserStore.self) private var store

    var body: some View {
        ZStack {
            themeBackground

            VStack(alignment: .leading, spacing: 14) {
                spaceHeader

                if !store.isSidebarCollapsed {
                    tabSections
                }

                Spacer(minLength: 12)
                bottomBar
            }
            .padding(12)
        }
    }

    private var themeBackground: some View {
        LinearGradient(
            colors: [
                store.activeTheme.primary.color.opacity(0.58),
                store.activeTheme.secondary.color.opacity(0.28),
                store.activeTheme.accent.color.opacity(0.22)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .overlay(.regularMaterial.opacity(0.54))
        .ignoresSafeArea()
    }

    private var spaceHeader: some View {
        VStack(alignment: .leading, spacing: 8) {
            if !store.isSidebarCollapsed {
                Text("Vela")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.primary)
            }

            ForEach(Array(store.workspaces.enumerated()), id: \.element.id) { index, workspace in
                Button {
                    store.switchWorkspace(workspace.id)
                } label: {
                    HStack(spacing: 8) {
                        Text("\(index + 1)")
                            .font(.caption.weight(.semibold))
                            .frame(width: 22, height: 22)
                            .background(.thinMaterial, in: Circle())

                        if !store.isSidebarCollapsed {
                            Text(workspace.name)
                                .lineLimit(1)
                            Spacer()
                        }
                    }
                    .padding(.vertical, 4)
                    .padding(.horizontal, 6)
                    .background(workspace.id == store.activeWorkspaceID ? Color.primary.opacity(0.08) : Color.clear, in: RoundedRectangle(cornerRadius: 8))
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var tabSections: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                TabSectionView(title: "Pinned", tabs: activeTabs.filter(\.isPinned))
                TabSectionView(title: "Tabs", tabs: activeTabs.filter { !$0.isPinned })
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var activeTabs: [BrowserTab] {
        (store.activeWorkspace?.tabIDs ?? []).compactMap { store.tabs[$0] }
    }

    private var bottomBar: some View {
        HStack {
            Button {
                store.createTab()
            } label: {
                Image(systemName: "plus")
                    .frame(width: 24, height: 24)
            }
            .help("New Tab")

            Button {
                store.isSidebarCollapsed.toggle()
            } label: {
                Image(systemName: "sidebar.left")
                    .frame(width: 24, height: 24)
            }
            .help("Toggle Sidebar")

            if !store.isSidebarCollapsed {
                Spacer()
            }
        }
        .buttonStyle(.borderless)
    }
}
