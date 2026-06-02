import Foundation
import WebKit

@MainActor
final class ContentBlockerService {
    private var compiledRuleList: WKContentRuleList?
    private var compiledExceptionList: WKContentRuleList?

    private static let cacheDirectory: URL = {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appending(path: "Vela/ContentBlocker", directoryHint: .isDirectory)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }()

    static let defaultFilterListURL = "https://easylist.to/easylist/easylist.txt"

    func compileDefaultList() async {
        let cachedJSON = Self.cacheDirectory.appending(path: "compiled-rules.json")
        let cachedList = Self.cacheDirectory.appending(path: "easylist.txt")

        var jsonString: String?

        if let cached = try? String(contentsOf: cachedJSON, encoding: .utf8) {
            jsonString = cached
        } else {
            let filterText: String
            if let cached = try? String(contentsOf: cachedList, encoding: .utf8) {
                filterText = cached
            } else if let url = URL(string: Self.defaultFilterListURL),
                      let (data, _) = try? await URLSession.shared.data(from: url),
                      let text = String(data: data, encoding: .utf8) {
                filterText = text
                try? text.write(to: cachedList, atomically: true, encoding: .utf8)
            } else {
                return
            }

            let rules = parseEasyList(filterText)
            guard !rules.isEmpty else { return }
            if let data = try? JSONSerialization.data(withJSONObject: rules),
               let str = String(data: data, encoding: .utf8) {
                jsonString = str
                try? str.write(to: cachedJSON, atomically: true, encoding: .utf8)
            }
        }

        guard let jsonString else { return }
        compiledRuleList = try? await WKContentRuleListStore.default()
            .compileContentRuleList(forIdentifier: "vela-easylist", encodedContentRuleList: jsonString)
    }

    func compileExceptionList(hosts: Set<String>) async {
        guard !hosts.isEmpty else {
            compiledExceptionList = nil
            return
        }
        var rules: [[String: Any]] = []
        for host in hosts {
            rules.append([
                "trigger": ["url-filter": ".*", "if-domain": ["*\(host)"]],
                "action": ["type": "ignore-previous-rules"]
            ])
        }
        guard let data = try? JSONSerialization.data(withJSONObject: rules),
              let str = String(data: data, encoding: .utf8) else { return }
        compiledExceptionList = try? await WKContentRuleListStore.default()
            .compileContentRuleList(forIdentifier: "vela-exceptions", encodedContentRuleList: str)
    }

    func applyRules(to configuration: WKWebViewConfiguration) {
        if let list = compiledRuleList {
            configuration.userContentController.add(list)
        }
        if let exList = compiledExceptionList {
            configuration.userContentController.add(exList)
        }
    }

    func parseEasyList(_ text: String) -> [[String: Any]] {
        let lines = text.components(separatedBy: .newlines)
        var rules: [[String: Any]] = []
        let maxRules = 50000

        for line in lines {
            guard rules.count < maxRules else { break }
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty || trimmed.hasPrefix("!") || trimmed.hasPrefix("[") { continue }

            if trimmed.hasPrefix("##") {
                if let cssRule = parseCSSHidingRule(trimmed) {
                    rules.append(cssRule)
                }
            } else if trimmed.hasPrefix("||") && trimmed.hasSuffix("^") {
                if let domainRule = parseDomainBlockRule(trimmed) {
                    rules.append(domainRule)
                }
            } else if trimmed.hasPrefix("@@||") {
                if let exceptionRule = parseExceptionRule(trimmed) {
                    rules.append(exceptionRule)
                }
            } else if !trimmed.contains("#") && !trimmed.contains("$") {
                if let urlRule = parseURLPatternRule(trimmed) {
                    rules.append(urlRule)
                }
            }
        }

        return rules
    }

    private func parseDomainBlockRule(_ line: String) -> [String: Any]? {
        var domain = String(line.dropFirst(2))
        if domain.hasSuffix("^") { domain = String(domain.dropLast()) }
        guard !domain.isEmpty, domain.contains(".") else { return nil }
        let escaped = NSRegularExpression.escapedPattern(for: domain)
            .replacingOccurrences(of: "\\.", with: "\\.")
        return [
            "trigger": ["url-filter": "^https?://([^/]*\\.)?\(escaped)", "resource-type": ["image", "style-sheet", "script", "raw", "font", "media", "popup"]],
            "action": ["type": "block"]
        ]
    }

    private func parseCSSHidingRule(_ line: String) -> [String: Any]? {
        let selector = String(line.dropFirst(2))
        guard !selector.isEmpty, selector.count < 200 else { return nil }
        return [
            "trigger": ["url-filter": ".*"],
            "action": ["type": "css-display-none", "selector": selector]
        ]
    }

    private func parseExceptionRule(_ line: String) -> [String: Any]? {
        var domain = String(line.dropFirst(4))
        if domain.hasSuffix("^") { domain = String(domain.dropLast()) }
        guard !domain.isEmpty, domain.contains(".") else { return nil }
        let escaped = NSRegularExpression.escapedPattern(for: domain)
            .replacingOccurrences(of: "\\.", with: "\\.")
        return [
            "trigger": ["url-filter": "^https?://([^/]*\\.)?\(escaped)"],
            "action": ["type": "ignore-previous-rules"]
        ]
    }

    private func parseURLPatternRule(_ line: String) -> [String: Any]? {
        let pattern = line.trimmingCharacters(in: CharacterSet(charactersIn: "*|"))
        guard pattern.count >= 5, !pattern.contains(" ") else { return nil }
        let escaped = NSRegularExpression.escapedPattern(for: pattern)
        return [
            "trigger": ["url-filter": escaped, "resource-type": ["image", "script", "raw"]],
            "action": ["type": "block"]
        ]
    }
}
