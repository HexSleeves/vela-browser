import SwiftUI

struct SettingsView: View {
    @Environment(BrowserStore.self) private var store

    var body: some View {
        Form {
            Section("Appearance") {
                Picker("Theme", selection: activeThemeBinding) {
                    ForEach(store.themes) { theme in
                        Text(theme.name).tag(theme.id)
                    }
                }
            }

            Section("Browsing") {
                Text("Downloads, permissions, search engines, imports, and privacy controls are planned for beta.")
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .padding()
        .frame(width: 420)
    }

    private var activeThemeBinding: Binding<BrowserTheme.ID> {
        Binding {
            store.activeWorkspace?.themeID ?? BrowserTheme.builtIns[0].id
        } set: { themeID in
            store.setTheme(themeID, for: store.activeWorkspaceID)
        }
    }
}
