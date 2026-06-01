import SwiftUI
import WebKit

struct SettingsView: View {
    @Environment(BrowserStore.self) private var store
    @AppStorage("searchEngine") private var searchEngine: String = "google"
    @AppStorage("blockPopups") private var blockPopups: Bool = true
    @AppStorage("archiveThresholdDays") private var archiveThresholdDays: Int = 7

    private enum Tab: String {
        case general, appearance, about
    }

    @State private var selectedTab: Tab = .general

    var body: some View {
        TabView(selection: $selectedTab) {
            generalTab
                .tabItem {
                    Label("General", systemImage: "gearshape")
                }
                .tag(Tab.general)

            appearanceTab
                .tabItem {
                    Label("Appearance", systemImage: "paintbrush")
                }
                .tag(Tab.appearance)

            aboutTab
                .tabItem {
                    Label("About", systemImage: "info.circle")
                }
                .tag(Tab.about)
        }
        .frame(width: 480, height: 320)
    }

    // MARK: - General

    private var generalTab: some View {
        Form {
            Section("Search") {
                Picker("Search Engine", selection: $searchEngine) {
                    ForEach(SearchEngine.allCases) { engine in
                        Text(engine.displayName).tag(engine.rawValue)
                    }
                }
            }

            Section("Downloads") {
                HStack {
                    Text("Download Location")
                    Spacer()
                    Text("~/Downloads")
                        .foregroundStyle(.secondary)
                }
            }

            Section("Pop-ups") {
                Toggle("Block Pop-up Windows", isOn: $blockPopups)
            }

            Section("Tab Archive") {
                Stepper("Archive after \(archiveThresholdDays) days", value: $archiveThresholdDays, in: 1...90)

                Text("Tabs not accessed within this period move to the Archive section.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Privacy") {
                ClearDataView()
            }

            defaultBrowserSection
        }
        .formStyle(.grouped)
        .padding()
    }

    // MARK: - Appearance

    private var appearanceTab: some View {
        Form {
            Section("Theme") {
                Picker("Active Theme", selection: activeThemeBinding) {
                    ForEach(store.themes) { theme in
                        Text(theme.name).tag(theme.id)
                    }
                }

                Text("Theme applies to the active workspace.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .padding()
    }

    // MARK: - About

    private var aboutTab: some View {
        VStack(spacing: 16) {
            Spacer()

            Text("Vela")
                .font(.system(size: 28, weight: .bold, design: .rounded))

            Text("A modern browser for macOS")
                .foregroundStyle(.secondary)

            Text("Version 0.1.0")
                .font(.caption)
                .foregroundStyle(.tertiary)

            Spacer()

            Text("Built with SwiftUI and WebKit")
                .font(.caption2)
                .foregroundStyle(.quaternary)
                .padding(.bottom, 12)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Default Browser

    private var defaultBrowserSection: some View {
        Section("Default Browser") {
            Button("Set Vela as Default Browser") {
                setAsDefaultBrowser()
            }

            Text("Requires macOS to recognize Vela as a browser.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private func setAsDefaultBrowser() {
        // LSSetDefaultHandlerForURLScheme requires CoreServices
        if let bundleID = Bundle.main.bundleIdentifier as CFString? {
            LSSetDefaultHandlerForURLScheme("http" as CFString, bundleID)
            LSSetDefaultHandlerForURLScheme("https" as CFString, bundleID)
        }
    }

    private var activeThemeBinding: Binding<BrowserTheme.ID> {
        Binding {
            store.activeWorkspace?.themeID ?? BrowserTheme.builtIns[0].id
        } set: { themeID in
            store.setTheme(themeID, for: store.activeWorkspaceID)
        }
    }
}

// MARK: - Clear Browsing Data

private struct ClearDataView: View {
    @Environment(BrowserStore.self) private var store
    @State private var clearHistory = true
    @State private var clearCookies = false
    @State private var clearCache = false
    @State private var showingConfirmation = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Toggle("Browsing History", isOn: $clearHistory)
            Toggle("Cookies & Site Data", isOn: $clearCookies)
            Toggle("Cached Files", isOn: $clearCache)

            Button("Clear Data…") {
                showingConfirmation = true
            }
            .disabled(!clearHistory && !clearCookies && !clearCache)
            .alert("Clear Browsing Data?", isPresented: $showingConfirmation) {
                Button("Cancel", role: .cancel) {}
                Button("Clear", role: .destructive) {
                    performClear()
                }
            } message: {
                Text("This action cannot be undone.")
            }
        }
    }

    private func performClear() {
        if clearHistory {
            store.history.removeAll()
            // Also persist the empty history
            let directory = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
                .appending(path: "Vela", directoryHint: .isDirectory)
            let historyURL = directory.appending(path: "history.json")
            try? "[]".data(using: .utf8)?.write(to: historyURL, options: [.atomic])
        }

        var dataTypes: Set<String> = []
        if clearCookies {
            dataTypes.insert(WKWebsiteDataStore.allWebsiteDataTypes().first(where: { $0.contains("cookie") }) ?? WKWebsiteDataTypeCookies)
            dataTypes.insert(WKWebsiteDataTypeLocalStorage)
            dataTypes.insert(WKWebsiteDataTypeSessionStorage)
        }
        if clearCache {
            dataTypes.insert(WKWebsiteDataTypeDiskCache)
            dataTypes.insert(WKWebsiteDataTypeMemoryCache)
        }

        if !dataTypes.isEmpty {
            WKWebsiteDataStore.default().removeData(
                ofTypes: dataTypes,
                modifiedSince: .distantPast
            ) {}
        }
    }
}
