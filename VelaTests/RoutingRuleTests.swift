import Foundation
import Testing
import WebKit
@testable import Vela

@MainActor
@Suite("Routing Rules (ATC)")
struct RoutingRuleTests {
    @Test("add routing rule appends to array")
    func addRuleAppendsToArray() {
        let store = makeStore()
        let rule = RoutingRule(urlPattern: "github.com", matchType: .domain, targetWorkspaceID: store.activeWorkspaceID)

        store.addRoutingRule(rule)

        #expect(store.routingRules.count == 1)
        #expect(store.routingRules[0].urlPattern == "github.com")
    }

    @Test("remove routing rule removes by ID")
    func removeRuleRemovesByID() {
        let store = makeStore()
        let rule = RoutingRule(urlPattern: "github.com", matchType: .domain, targetWorkspaceID: store.activeWorkspaceID)
        store.addRoutingRule(rule)

        store.removeRoutingRule(rule.id)

        #expect(store.routingRules.isEmpty)
    }

    @Test("update routing rule modifies existing")
    func updateRuleModifiesExisting() {
        let store = makeStore()
        var rule = RoutingRule(urlPattern: "github.com", matchType: .domain, targetWorkspaceID: store.activeWorkspaceID)
        store.addRoutingRule(rule)

        rule.urlPattern = "gitlab.com"
        store.updateRoutingRule(rule)

        #expect(store.routingRules[0].urlPattern == "gitlab.com")
    }

    @Test("evaluate domain match")
    func evaluateDomainMatch() throws {
        let store = makeStore()
        let wsID = store.activeWorkspaceID
        store.addRoutingRule(RoutingRule(urlPattern: "github.com", matchType: .domain, targetWorkspaceID: wsID))

        let url = try #require(URL(string: "https://github.com/anthropics"))
        #expect(store.evaluateRoutingRules(for: url) == wsID)
    }

    @Test("evaluate domain match includes subdomains")
    func evaluateDomainMatchSubdomains() throws {
        let store = makeStore()
        let wsID = store.activeWorkspaceID
        store.addRoutingRule(RoutingRule(urlPattern: "github.com", matchType: .domain, targetWorkspaceID: wsID))

        let url = try #require(URL(string: "https://gist.github.com/something"))
        #expect(store.evaluateRoutingRules(for: url) == wsID)
    }

    @Test("evaluate contains match")
    func evaluateContainsMatch() throws {
        let store = makeStore()
        let wsID = store.activeWorkspaceID
        store.addRoutingRule(RoutingRule(urlPattern: "jira", matchType: .contains, targetWorkspaceID: wsID))

        let url = try #require(URL(string: "https://mycompany.atlassian.net/jira/board"))
        #expect(store.evaluateRoutingRules(for: url) == wsID)
    }

    @Test("evaluate prefix match")
    func evaluatePrefixMatch() throws {
        let store = makeStore()
        let wsID = store.activeWorkspaceID
        store.addRoutingRule(RoutingRule(urlPattern: "https://docs.google.com", matchType: .prefix, targetWorkspaceID: wsID))

        let url = try #require(URL(string: "https://docs.google.com/spreadsheet/123"))
        #expect(store.evaluateRoutingRules(for: url) == wsID)
    }

    @Test("disabled rule does not match")
    func disabledRuleDoesNotMatch() throws {
        let store = makeStore()
        store.addRoutingRule(RoutingRule(urlPattern: "github.com", matchType: .domain, targetWorkspaceID: store.activeWorkspaceID, isEnabled: false))

        let url = try #require(URL(string: "https://github.com"))
        #expect(store.evaluateRoutingRules(for: url) == nil)
    }

    @Test("no matching rule returns nil")
    func noMatchReturnsNil() throws {
        let store = makeStore()
        store.addRoutingRule(RoutingRule(urlPattern: "github.com", matchType: .domain, targetWorkspaceID: store.activeWorkspaceID))

        let url = try #require(URL(string: "https://google.com"))
        #expect(store.evaluateRoutingRules(for: url) == nil)
    }

    @Test("RoutingRule domain matches case-insensitively")
    func domainMatchesCaseInsensitive() throws {
        let rule = RoutingRule(urlPattern: "GitHub.com", matchType: .domain, targetWorkspaceID: UUID())
        let url = try #require(URL(string: "https://github.com/repo"))
        #expect(rule.matches(url) == true)
    }

    private final class StubWebViewPool: WebViewPooling {
        func load(_ url: URL, in tabID: BrowserTab.ID) {}
        func remove(tabID: BrowserTab.ID) {}
        func goBack(tabID: BrowserTab.ID) {}
        func goForward(tabID: BrowserTab.ID) {}
        func reload(tabID: BrowserTab.ID) {}
        func stopLoading(tabID: BrowserTab.ID) {}
        func setZoom(_ level: Double, tabID: BrowserTab.ID) {}
        func findInPage(_ text: String, tabID: BrowserTab.ID) {}
        func findNext(tabID: BrowserTab.ID) {}
        func findPrevious(tabID: BrowserTab.ID) {}
        func clearFind(tabID: BrowserTab.ID) {}
        func printPage(tabID: BrowserTab.ID) {}
        func setMuted(_ muted: Bool, tabID: BrowserTab.ID) {}
        func toggleReaderMode(tabID: BrowserTab.ID, enable: Bool) {}
    }

    private func makeStore() -> BrowserStore {
        let theme = BrowserTheme.builtIns[0]
        let workspace = Workspace(name: "Work", themeID: theme.id)
        let snapshot = BrowserStateSnapshot(
            schemaVersion: 3,
            activeWorkspaceID: workspace.id,
            activeTabID: nil,
            workspaces: [workspace],
            tabs: [],
            themes: BrowserTheme.builtIns
        )
        return BrowserStore(
            snapshot: snapshot,
            persistence: BrowserPersistence(applicationSupportDirectory: FileManager.default.temporaryDirectory.appending(path: "VelaRoutingTests-\(UUID().uuidString)", directoryHint: .isDirectory)),
            webViewPool: StubWebViewPool()
        )
    }
}
