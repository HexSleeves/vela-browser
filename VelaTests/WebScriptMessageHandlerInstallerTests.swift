import Testing
import WebKit
@testable import Vela

@MainActor
@Suite("Web script message handler installer")
struct WebScriptMessageHandlerInstallerTests {
    @Test("uses stable script message handler names")
    func usesStableScriptMessageHandlerNames() {
        #expect(WebScriptMessageHandlerInstaller.peekName == "velaPeek")
        #expect(WebScriptMessageHandlerInstaller.zapName == "velaZap")
    }

    @Test("removes an existing handler before adding the new handler")
    func removesExistingHandlerBeforeAddingNewHandler() {
        let controller = RecordingScriptMessageHandlerController()
        let handler = NoopScriptMessageHandler()

        WebScriptMessageHandlerInstaller.replaceHandler(
            handler,
            name: WebScriptMessageHandlerInstaller.peekName,
            in: controller
        )

        #expect(controller.events == ["remove:velaPeek", "add:velaPeek"])
    }

    @Test("can replace a real WebKit handler repeatedly")
    func canReplaceRealWebKitHandlerRepeatedly() {
        let controller = WKUserContentController()

        WebScriptMessageHandlerInstaller.replaceHandler(
            NoopScriptMessageHandler(),
            name: WebScriptMessageHandlerInstaller.peekName,
            in: controller
        )
        WebScriptMessageHandlerInstaller.replaceHandler(
            NoopScriptMessageHandler(),
            name: WebScriptMessageHandlerInstaller.peekName,
            in: controller
        )
    }
}

private final class RecordingScriptMessageHandlerController: ScriptMessageHandlerRegistering {
    var events: [String] = []

    func removeScriptMessageHandler(forName name: String) {
        events.append("remove:\(name)")
    }

    func add(_ scriptMessageHandler: any WKScriptMessageHandler, name: String) {
        events.append("add:\(name)")
    }
}

private final class NoopScriptMessageHandler: NSObject, WKScriptMessageHandler {
    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {}
}
