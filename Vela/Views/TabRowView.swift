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
                Image(systemName: "line.3.horizontal")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(isDragging ? Color.accentColor : Color.secondary.opacity(0.55))
                    .opacity(isHovered || isDragging ? 1 : 0)
                    .frame(width: 10)
                    .animation(VelaAnimation.micro, value: isHovered || isDragging)

                tabIcon
                    .frame(width: 18, height: 18)

                Text(tab.title)
                    .lineLimit(1)

                Spacer(minLength: 8)

                if tab.isLoading {
                    ProgressView()
                        .controlSize(.small)
                } else if tab.isPlayingAudio || tab.isMuted {
                    Button {
                        VelaAnimation.withMicro {
                            store.toggleMute(tab.id)
                        }
                    } label: {
                        Image(systemName: tab.isMuted ? "speaker.slash.fill" : "speaker.wave.2.fill")
                            .font(.caption2)
                            .foregroundStyle(tab.isMuted ? .secondary : .primary)
                    }
                    .buttonStyle(.plain)
                    .help(tab.isMuted ? "Unmute Tab" : "Mute Tab")
                    .transition(.opacity)
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
                if isDragging {
                    RoundedRectangle(cornerRadius: 9)
                        .fill(.regularMaterial)
                        .overlay(
                            RoundedRectangle(cornerRadius: 9)
                                .stroke(Color.accentColor.opacity(0.35), lineWidth: 1)
                        )
                } else if isSelected {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.primary.opacity(0.08))
                        .matchedGeometryEffect(id: "selection", in: selectionNamespace)
                } else if isHovered && !isDragging {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.primary.opacity(0.04))
                }
            }
            .animation(VelaAnimation.micro, value: isHovered)
            .animation(VelaAnimation.micro, value: isDragging)
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

            if store.isFavorite(tab.id) {
                Button("Remove from Favorites") {
                    VelaAnimation.withMicro { store.removeFavorite(tab.id) }
                }
            } else if store.favoriteTabIDs.count < 8 {
                Button("Add to Favorites") {
                    VelaAnimation.withMicro { store.addFavorite(tab.id) }
                }
            }

            Divider()

            if tab.id != store.activeTabID {
                Button("Open in Split View") {
                    VelaAnimation.withLayout {
                        store.openInSplit(tab.id)
                    }
                }
            }

            if store.splitTabID != nil {
                Button("Close Split View") {
                    VelaAnimation.withLayout {
                        store.closeSplit()
                    }
                }
            }

            if !store.tabGroups.isEmpty {
                Menu("Move to Group") {
                    Button("Ungrouped") {
                        store.moveTabToGroup(tab.id, groupID: nil)
                    }
                    ForEach(store.tabGroups) { group in
                        Button(group.name) {
                            store.moveTabToGroup(tab.id, groupID: group.id)
                        }
                    }
                }
            }

            Button("Move to New Group…") {
                let alert = NSAlert()
                alert.messageText = "New Tab Group"
                let field = NSTextField(frame: NSRect(x: 0, y: 0, width: 200, height: 24))
                field.placeholderString = "Group name"
                alert.accessoryView = field
                alert.addButton(withTitle: "Create")
                alert.addButton(withTitle: "Cancel")
                alert.window.initialFirstResponder = field
                if alert.runModal() == .alertFirstButtonReturn {
                    let name = field.stringValue.trimmingCharacters(in: .whitespaces)
                    if !name.isEmpty {
                        store.createTabGroup(name: name)
                        if let group = store.tabGroups.last {
                            store.moveTabToGroup(tab.id, groupID: group.id)
                        }
                    }
                }
            }

            Button("Duplicate Tab") {
                store.createTab(url: tab.url)
            }

            Button("Copy URL") {
                if let url = tab.url {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(url.absoluteString, forType: .string)
                }
            }

            if store.splitTabID == nil {
                Button("Open in Split View") {
                    VelaAnimation.withLayout {
                        store.openInSplit(tab.id)
                    }
                }
            }

            Divider()

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

    // MARK: - Favicon

    @ViewBuilder
    private var tabIcon: some View {
        if tab.isPinned {
            Image(systemName: "pin.fill")
                .foregroundStyle(.secondary)
                .font(.caption)
        } else {
            FaviconView(url: tab.url, size: 16)
        }
    }
}
