import SwiftUI

struct BrowserCommands: Commands {
    @FocusedValue(\.browserCommandSink) private var commandSink

    var body: some Commands {
        // MARK: - File Menu (New Tab, Close Tab)

        CommandGroup(after: .newItem) {
            Button("New Tab") {
                commandSink?(.newTab)
            }
            .keyboardShortcut("t", modifiers: .command)

            Button("Close Tab") {
                commandSink?(.closeTab)
            }
            .keyboardShortcut("w", modifiers: .command)

            Button("Undo Close Tab") {
                commandSink?(.undoCloseTab)
            }
            .keyboardShortcut("z", modifiers: .command)
        }

        // MARK: - View Menu (Zoom, Sidebar)

        CommandGroup(after: .toolbar) {
            Button("Zoom In") {
                commandSink?(.zoomIn)
            }
            .keyboardShortcut("+", modifiers: .command)

            Button("Zoom Out") {
                commandSink?(.zoomOut)
            }
            .keyboardShortcut("-", modifiers: .command)

            Button("Actual Size") {
                commandSink?(.zoomReset)
            }
            .keyboardShortcut("0", modifiers: .command)

            Divider()

            Button("Toggle Sidebar") {
                commandSink?(.toggleSidebar)
            }
            .keyboardShortcut("s", modifiers: [.command, .shift])
        }

        // MARK: - Edit Menu (Find, Address Bar)

        CommandGroup(after: .textEditing) {
            Button("Focus Address Bar") {
                commandSink?(.focusAddressBar)
            }
            .keyboardShortcut("l", modifiers: .command)

            Button("Command Bar") {
                commandSink?(.toggleCommandBar)
            }
            .keyboardShortcut("k", modifiers: .command)

            Divider()

            Button("Find…") {
                commandSink?(.toggleFind)
            }
            .keyboardShortcut("f", modifiers: .command)

            Button("Find Next") {
                commandSink?(.findNext)
            }
            .keyboardShortcut("g", modifiers: .command)

            Button("Find Previous") {
                commandSink?(.findPrevious)
            }
            .keyboardShortcut("g", modifiers: [.command, .shift])
        }

        // MARK: - Navigation (Back, Forward, Reload)

        CommandGroup(after: .pasteboard) {
            Divider()

            Button("Back") {
                commandSink?(.goBack)
            }
            .keyboardShortcut("[", modifiers: .command)

            Button("Forward") {
                commandSink?(.goForward)
            }
            .keyboardShortcut("]", modifiers: .command)

            Button("Reload Page") {
                commandSink?(.reload)
            }
            .keyboardShortcut("r", modifiers: .command)

            Divider()

            Button("Print…") {
                commandSink?(.printPage)
            }
            .keyboardShortcut("p", modifiers: .command)
        }

        // MARK: - Tab Selection (⌘1-9)

        CommandGroup(after: .windowArrangement) {
            ForEach(1...9, id: \.self) { index in
                Button("Tab \(index)") {
                    commandSink?(.selectTabByIndex(index - 1))
                }
                .keyboardShortcut(KeyEquivalent(Character(String(index))), modifiers: .command)
            }
        }
    }
}

enum BrowserCommand {
    case newTab
    case closeTab
    case focusAddressBar
    case toggleSidebar
    case goBack
    case goForward
    case reload
    case zoomIn
    case zoomOut
    case zoomReset
    case selectTabByIndex(Int)
    case toggleFind
    case findNext
    case findPrevious
    case printPage
    case toggleCommandBar
    case undoCloseTab
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
