import SwiftUI

struct BrowserCommands: Commands {
    @FocusedValue(\.browserCommandSink) private var commandSink

    var body: some Commands {
        CommandGroup(after: .newItem) {
            Button("New Tab") {
                commandSink?(.newTab)
            }
            .keyboardShortcut("t", modifiers: .command)
        }

        CommandGroup(after: .textEditing) {
            Button("Focus Address Bar") {
                commandSink?(.focusAddressBar)
            }
            .keyboardShortcut("l", modifiers: .command)

            Button("Toggle Sidebar") {
                commandSink?(.toggleSidebar)
            }
            .keyboardShortcut("l", modifiers: [.command, .shift])
        }
    }
}

enum BrowserCommand {
    case newTab
    case focusAddressBar
    case toggleSidebar
}

private struct BrowserCommandSinkKey: FocusedValueKey {
    typealias Value = (BrowserCommand) -> Void
}

extension FocusedValues {
    var browserCommandSink: ((BrowserCommand) -> Void)? {
        get { self[BrowserCommandSinkKey.self] }
        set { self[BrowserCommandSinkKey.self] = newValue }
    }
}
