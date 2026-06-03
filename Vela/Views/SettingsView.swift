import SwiftUI
import WebKit

struct SettingsView: View {
    @Environment(BrowserStore.self) private var store
    @AppStorage("searchEngine") private var searchEngine: String = "google"
    @AppStorage("blockPopups") private var blockPopups: Bool = true
    @AppStorage("contentBlockingEnabled") private var contentBlockingEnabled: Bool = true
    @AppStorage("archiveThresholdDays") private var archiveThresholdDays: Int = 7

    private enum Tab: String {
        case general, appearance, profiles, routing, about
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

            profilesTab
                .tabItem {
                    Label("Profiles", systemImage: "person.2")
                }
                .tag(Tab.profiles)

            routingTab
                .tabItem {
                    Label("Routing", systemImage: "arrow.triangle.branch")
                }
                .tag(Tab.routing)

            aboutTab
                .tabItem {
                    Label("About", systemImage: "info.circle")
                }
                .tag(Tab.about)
        }
        .frame(width: 520, height: 420)
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

            Section("Content Blocking") {
                Toggle("Block Ads & Trackers", isOn: $contentBlockingEnabled)
                    .onChange(of: contentBlockingEnabled) { _, newValue in
                        store.setContentBlockingEnabled(newValue)
                    }

                if !store.contentBlockingExceptions.isEmpty {
                    ForEach(Array(store.contentBlockingExceptions).sorted(), id: \.self) { host in
                        HStack {
                            Text(host)
                                .font(.caption)
                            Spacer()
                            Button("Remove") {
                                store.toggleContentBlockingException(host: host)
                            }
                            .buttonStyle(.plain)
                            .font(.caption)
                            .foregroundStyle(.red)
                        }
                    }
                }

                Text("Uses EasyList filter rules. Toggle per-site via the shield icon in the address bar.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
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

    @State private var isCreatingTheme = false
    @State private var editingThemeID: String?

    private var appearanceTab: some View {
        Form {
            Section("Active Theme") {
                Picker("Theme", selection: activeThemeBinding) {
                    ForEach(store.themes) { theme in
                        HStack {
                            Circle().fill(theme.primary.color).frame(width: 10, height: 10)
                            Text(theme.name)
                        }.tag(theme.id)
                    }
                }

                Text("Theme applies to the active workspace.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Custom Themes") {
                ForEach(store.themes.filter { !$0.isBuiltIn }) { theme in
                    HStack {
                        themePreviewDots(theme)
                        Text(theme.name)
                        Spacer()
                        Button("Edit") { editingThemeID = theme.id }
                            .buttonStyle(.plain).font(.caption).foregroundStyle(.secondary)
                        Button("Delete", role: .destructive) {
                            VelaAnimation.withMicro { store.deleteTheme(theme.id) }
                        }
                        .buttonStyle(.plain).font(.caption).foregroundStyle(.red)
                    }
                }

                if store.themes.filter({ !$0.isBuiltIn }).isEmpty {
                    Text("No custom themes yet.")
                        .font(.caption).foregroundStyle(.secondary)
                }

                Button("New Theme…") { isCreatingTheme = true }
            }
        }
        .formStyle(.grouped)
        .padding()
        .sheet(isPresented: $isCreatingTheme) {
            ThemeEditorSheet(store: store, existingTheme: nil) { isCreatingTheme = false }
        }
        .sheet(item: editingThemeBinding) { theme in
            ThemeEditorSheet(store: store, existingTheme: theme) { editingThemeID = nil }
        }
    }

    private var editingThemeBinding: Binding<BrowserTheme?> {
        Binding(
            get: { editingThemeID.flatMap { id in store.themes.first { $0.id == id } } },
            set: { editingThemeID = $0?.id }
        )
    }

    private func themePreviewDots(_ theme: BrowserTheme) -> some View {
        HStack(spacing: 3) {
            Circle().fill(theme.primary.color).frame(width: 10, height: 10)
            Circle().fill(theme.secondary.color).frame(width: 10, height: 10)
            Circle().fill(theme.accent.color).frame(width: 10, height: 10)
        }
    }

    // MARK: - Profiles

    private var profilesTab: some View {
        Form {
            Section("Browsing Profiles") {
                ForEach(store.profiles) { profile in
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(profile.name)
                                .font(.body)
                            if profile.dataStoreIdentifier == nil {
                                Text("Default — shared with existing data")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            } else {
                                Text("Isolated cookies, cache & logins")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }

                        Spacer()

                        let wsCount = store.workspaces.filter { $0.profileID == profile.id || ($0.profileID == nil && profile.dataStoreIdentifier == nil) }.count
                        Text("\(wsCount) workspace\(wsCount == 1 ? "" : "s")")
                            .font(.caption)
                            .foregroundStyle(.tertiary)

                        Button("Rename") {
                            promptRenameProfile(profile)
                        }
                        .buttonStyle(.plain)
                        .font(.caption)
                        .foregroundStyle(.secondary)

                        if profile.dataStoreIdentifier != nil {
                            Button("Delete", role: .destructive) {
                                VelaAnimation.withMicro {
                                    store.deleteProfile(profile.id)
                                }
                            }
                            .buttonStyle(.plain)
                            .font(.caption)
                            .foregroundStyle(.red)
                        }
                    }
                }

                Button("New Profile…") {
                    promptCreateProfile()
                }
            }

            Section {
                Text("Each profile has isolated cookies, cache, and login sessions. Assign profiles to workspaces to keep browsing contexts separate.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .padding()
    }

    private func promptCreateProfile() {
        let alert = NSAlert()
        alert.messageText = "New Profile"
        alert.informativeText = "Enter a name for this profile:"
        let field = NSTextField(frame: NSRect(x: 0, y: 0, width: 200, height: 24))
        field.placeholderString = "Profile name"
        alert.accessoryView = field
        alert.addButton(withTitle: "Create")
        alert.addButton(withTitle: "Cancel")
        alert.window.initialFirstResponder = field
        if alert.runModal() == .alertFirstButtonReturn {
            let name = field.stringValue.trimmingCharacters(in: .whitespaces)
            if !name.isEmpty {
                VelaAnimation.withMicro {
                    store.createProfile(name: name)
                }
            }
        }
    }

    private func promptRenameProfile(_ profile: Profile) {
        let alert = NSAlert()
        alert.messageText = "Rename Profile"
        let field = NSTextField(frame: NSRect(x: 0, y: 0, width: 200, height: 24))
        field.stringValue = profile.name
        alert.accessoryView = field
        alert.addButton(withTitle: "Rename")
        alert.addButton(withTitle: "Cancel")
        alert.window.initialFirstResponder = field
        if alert.runModal() == .alertFirstButtonReturn {
            let name = field.stringValue.trimmingCharacters(in: .whitespaces)
            if !name.isEmpty {
                store.renameProfile(profile.id, name: name)
            }
        }
    }

    // MARK: - Routing (Air Traffic Control)

    @State private var isCreatingRule = false

    private var routingTab: some View {
        Form {
            Section("URL Routing Rules") {
                if store.routingRules.isEmpty {
                    Text("No routing rules. External links open in the active workspace.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(store.routingRules) { rule in
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(rule.urlPattern)
                                    .font(.body.weight(.medium))
                                HStack(spacing: 4) {
                                    Text(rule.matchType.rawValue.capitalized)
                                        .font(.caption2)
                                        .padding(.horizontal, 4)
                                        .padding(.vertical, 1)
                                        .background(.quaternary, in: RoundedRectangle(cornerRadius: 3))
                                    if let wsID = rule.targetWorkspaceID,
                                       let ws = store.workspaces.first(where: { $0.id == wsID }) {
                                        Text("→ \(ws.name)")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                            }

                            Spacer()

                            Toggle("", isOn: Binding(
                                get: { rule.isEnabled },
                                set: { newVal in
                                    var updated = rule
                                    updated.isEnabled = newVal
                                    store.updateRoutingRule(updated)
                                }
                            ))
                            .toggleStyle(.switch)
                            .labelsHidden()

                            Button(role: .destructive) {
                                VelaAnimation.withMicro {
                                    store.removeRoutingRule(rule.id)
                                }
                            } label: {
                                Image(systemName: "trash")
                                    .font(.caption)
                            }
                            .buttonStyle(.plain)
                            .foregroundStyle(.red)
                        }
                    }
                }

                Button("Add Rule…") { isCreatingRule = true }
            }

            Section {
                Text("Rules match external links opened via Vela as default browser. First matching rule wins.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .padding()
        .sheet(isPresented: $isCreatingRule) {
            RoutingRuleSheet(store: store) { isCreatingRule = false }
        }
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
            store.clearHistory()
        }

        if clearHistory || clearCache {
            Task {
                await FaviconCache.shared.clear()
            }
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
            let profile = store.profileForWorkspace(store.activeWorkspaceID)
            let dataStore: WKWebsiteDataStore
            if let identifier = profile.dataStoreIdentifier {
                dataStore = WKWebsiteDataStore(forIdentifier: identifier)
            } else {
                dataStore = .default()
            }
            dataStore.removeData(
                ofTypes: dataTypes,
                modifiedSince: .distantPast
            ) {}
        }
    }
}

// MARK: - Theme Editor

private struct ThemeEditorSheet: View {
    let store: BrowserStore
    let existingTheme: BrowserTheme?
    let onDismiss: () -> Void

    @State private var name: String = ""
    @State private var primaryHue: Double = 0.5
    @State private var primarySat: Double = 0.6
    @State private var primaryLight: Double = 0.35
    @State private var secondaryHue: Double = 0.5
    @State private var secondarySat: Double = 0.5
    @State private var secondaryLight: Double = 0.5
    @State private var accentHue: Double = 0.5
    @State private var accentSat: Double = 0.5
    @State private var accentLight: Double = 0.7

    var body: some View {
        VStack(spacing: 16) {
            Text(existingTheme != nil ? "Edit Theme" : "New Theme")
                .font(.title3.weight(.semibold))

            TextField("Theme Name", text: $name)
                .textFieldStyle(.roundedBorder)
                .padding(.horizontal)

            previewGradient
                .frame(height: 60)
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .padding(.horizontal)

            Form {
                Section("Primary") {
                    hslSliders(hue: $primaryHue, saturation: $primarySat, lightness: $primaryLight)
                }
                Section("Secondary") {
                    hslSliders(hue: $secondaryHue, saturation: $secondarySat, lightness: $secondaryLight)
                }
                Section("Accent") {
                    hslSliders(hue: $accentHue, saturation: $accentSat, lightness: $accentLight)
                }
            }
            .formStyle(.grouped)

            HStack {
                Button("Cancel") { onDismiss() }
                    .keyboardShortcut(.cancelAction)
                Spacer()
                Button(existingTheme != nil ? "Save" : "Create") { save() }
                    .keyboardShortcut(.defaultAction)
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            .padding(.horizontal)
            .padding(.bottom)
        }
        .frame(width: 420, height: 520)
        .onAppear {
            if let t = existingTheme {
                name = t.name
            }
        }
    }

    private var previewGradient: some View {
        let p = BrowserTheme.Stop.fromHSL(hue: primaryHue, saturation: primarySat, lightness: primaryLight)
        let s = BrowserTheme.Stop.fromHSL(hue: secondaryHue, saturation: secondarySat, lightness: secondaryLight)
        let a = BrowserTheme.Stop.fromHSL(hue: accentHue, saturation: accentSat, lightness: accentLight)
        return LinearGradient(
            colors: [p.color.opacity(0.58), s.color.opacity(0.28), a.color.opacity(0.22)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private func hslSliders(hue: Binding<Double>, saturation: Binding<Double>, lightness: Binding<Double>) -> some View {
        Group {
            HStack {
                Text("Hue")
                    .frame(width: 70, alignment: .leading)
                    .font(.caption)
                Slider(value: hue, in: 0...1)
                Circle()
                    .fill(BrowserTheme.Stop.fromHSL(hue: hue.wrappedValue, saturation: saturation.wrappedValue, lightness: lightness.wrappedValue).color)
                    .frame(width: 16, height: 16)
            }
            HStack {
                Text("Saturation")
                    .frame(width: 70, alignment: .leading)
                    .font(.caption)
                Slider(value: saturation, in: 0...1)
            }
            HStack {
                Text("Lightness")
                    .frame(width: 70, alignment: .leading)
                    .font(.caption)
                Slider(value: lightness, in: 0...1)
            }
        }
    }

    private func save() {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        let p = BrowserTheme.Stop.fromHSL(hue: primaryHue, saturation: primarySat, lightness: primaryLight)
        let s = BrowserTheme.Stop.fromHSL(hue: secondaryHue, saturation: secondarySat, lightness: secondaryLight)
        let a = BrowserTheme.Stop.fromHSL(hue: accentHue, saturation: accentSat, lightness: accentLight)

        if let existing = existingTheme {
            store.editTheme(existing.id, name: trimmed, primary: p, secondary: s, accent: a)
        } else {
            store.createTheme(name: trimmed, primary: p, secondary: s, accent: a)
        }
        onDismiss()
    }
}

// MARK: - Routing Rule Sheet

private struct RoutingRuleSheet: View {
    let store: BrowserStore
    let onDismiss: () -> Void

    @State private var urlPattern = ""
    @State private var matchType: RoutingRule.MatchType = .domain
    @State private var targetWorkspaceID: Workspace.ID?

    var body: some View {
        VStack(spacing: 16) {
            Text("New Routing Rule")
                .font(.title3.weight(.semibold))

            Form {
                TextField("URL Pattern", text: $urlPattern, prompt: Text("e.g. github.com"))
                    .textFieldStyle(.roundedBorder)

                Picker("Match Type", selection: $matchType) {
                    ForEach(RoutingRule.MatchType.allCases, id: \.self) { type in
                        Text(type.rawValue.capitalized).tag(type)
                    }
                }

                Picker("Route to Workspace", selection: $targetWorkspaceID) {
                    Text("None").tag(nil as Workspace.ID?)
                    ForEach(store.workspaces) { ws in
                        Text(ws.name).tag(ws.id as Workspace.ID?)
                    }
                }
            }
            .padding(.horizontal)

            HStack {
                Button("Cancel") { onDismiss() }
                    .keyboardShortcut(.cancelAction)
                Spacer()
                Button("Add") {
                    let trimmed = urlPattern.trimmingCharacters(in: .whitespaces)
                    guard !trimmed.isEmpty else { return }
                    let rule = RoutingRule(urlPattern: trimmed, matchType: matchType, targetWorkspaceID: targetWorkspaceID)
                    store.addRoutingRule(rule)
                    onDismiss()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(urlPattern.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            .padding()
        }
        .frame(width: 400, height: 280)
    }
}
