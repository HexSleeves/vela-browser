import WebKit

@MainActor
protocol ScriptMessageHandlerRegistering: AnyObject {
    func removeScriptMessageHandler(forName name: String)
    func add(_ scriptMessageHandler: any WKScriptMessageHandler, name: String)
}

extension WKUserContentController: ScriptMessageHandlerRegistering {}

@MainActor
enum WebScriptMessageHandlerInstaller {
    static let peekName = "velaPeek"
    static let zapName = "velaZap"

    static func replaceHandler(
        _ handler: any WKScriptMessageHandler,
        name: String,
        in controller: ScriptMessageHandlerRegistering
    ) {
        controller.removeScriptMessageHandler(forName: name)
        controller.add(handler, name: name)
    }
}
