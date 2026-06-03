# Repository Guidelines

## Project Overview

Vela is a native macOS browser built with SwiftUI and WebKit. It supports multiple workspaces, per-workspace themes and browser profiles, pinned tabs with designated URLs, tab groups, favorites, split view, a "Little Vela" compact popup window, private browsing, content blocking (EasyList), CSS/JS "Boosts" for per-site customization, a "Zap" element-picker mode, find-in-page, reader mode, and a command palette.

---

## Architecture & Data Flow

```
VelaApp (@main)
  └─ WindowGroup → MainBrowserWindow
       ├─ SidebarView  (workspace list, tab list, favorites, groups)
       └─ BrowserSurfaceView
            ├─ AddressBar  (navigation, autocomplete, bookmarks, boosts, content-blocking toggles)
            ├─ FindBarView
            └─ BrowserWebView (NSViewRepresentable → WKWebView from WebViewPool)

State:  BrowserStore (@Observable, @MainActor) ← injected via .environment(store)
Pool:   WebViewPool (keyed WKWebView cache, one view per BrowserTab.ID)
Persist: BrowserPersistence → ~/Application Support/Vela/browser-state.json
```

**Data flow:** Views read `BrowserStore` properties directly (Observation framework triggers re-renders automatically). Mutations always go through `BrowserStore` methods, which call `persist()` synchronously on every write. `WebViewPool` is the single source of live WKWebViews; `BrowserStore` dispatches all navigation commands through the `WebViewPooling` protocol.

---

## Key Directories

| Path | Purpose |
|---|---|
| `Vela/App/` | Entry point (`VelaApp.swift`), keyboard commands (`BrowserCommands.swift`) |
| `Vela/State/` | `BrowserStore.swift` — the single app-wide state object (1365 lines) |
| `Vela/Models/` | Plain value types (`struct`, `Codable`, `Equatable`): tabs, workspaces, themes, boosts, etc. |
| `Vela/Views/` | SwiftUI views; one type per file |
| `Vela/Web/` | WebKit integration: `WebViewPool`, `BrowserWebView`, script message handlers, compatibility shims |
| `Vela/Services/` | Stateless or weakly-stateful helpers: persistence, navigation resolution, content blocking, downloads, bookmarks, favicons |
| `Vela/Animation/` | `VelaAnimation` — shared spring presets; **all animated transitions must use these tokens** |
| `VelaTests/` | Swift Testing unit tests (`@Suite`, `@Test`, `#expect`) |

---

## Development Commands

Prefix all shell commands with `rtk` in this workspace.

```sh
# Regenerate Xcode project after adding/removing files or changing project.yml
rtk xcodegen generate

# Build
rtk xcodebuild -project Vela.xcodeproj -scheme Vela -configuration Debug build

# Run tests
rtk xcodebuild test -project Vela.xcodeproj -scheme Vela -destination 'platform=macOS'

# Open in Xcode
rtk open Vela.xcodeproj
```

> **`project.yml` is the source of truth** for the Xcode project. `Vela.xcodeproj/` is generated output — never edit it by hand. Add new Swift files to the filesystem and run `xcodegen generate`.

---

## Code Conventions & Common Patterns

### Swift Version & Target
- **Swift 6.0**, **macOS 14.0** minimum (`MACOSX_DEPLOYMENT_TARGET = 14.0`)
- **Bundle ID prefix:** `dev.lecoqjacob`

### Naming
- Types: `UpperCamelCase`, one type per file, filename matches type name
- Properties/methods: `lowerCamelCase`
- Test methods: descriptive behavior phrase, e.g. `createWorkspaceAddsAndSwitches()`
- Script message handler names use the `vela` prefix: `velaPeek`, `velaZap`

### Indentation
4-space indentation throughout.

### State Management
- **Single store pattern.** `BrowserStore` is `@Observable @MainActor final class`; it holds all mutable browser state.
- Injected at the root: `MainBrowserWindow().environment(store)`. Views consume it with `@Environment(BrowserStore.self)`.
- **No `@Published` anywhere** — the project uses the Swift Observation framework (`import Observation`), not Combine.
- `@ObservationIgnored` is used sparingly for properties that must not trigger re-renders (e.g., `contentBlocker`).
- Every mutating method on `BrowserStore` ends with `persist()` (or a feature-specific equivalent like `persistBoosts()`).

### Concurrency
- `BrowserStore`, `WebViewPool`, `ContentBlockerService`, and `WebScriptMessageHandlerInstaller` are all `@MainActor`.
- `Task { @MainActor in … }` is used for fire-and-forget animations/timers (e.g., swipe indicator auto-dismiss).
- Background work (content blocker compilation, WKWebsiteDataStore removal) uses `async/await` via `Task { … }` called from `@MainActor` context.
- `WKWebsiteDataStore.remove(forIdentifier:)` requires `async`; called with `Task { try? await … }`.

### Models
All models are `struct`, `Identifiable`, `Codable`, `Equatable`. UUIDs are used as IDs (`var id: UUID`). Every model implements a manual `init(from decoder:)` using `decodeIfPresent` with safe defaults for fields added after initial schema — this is the migration strategy (no explicit schema migration code).

### WebKit Integration
- `WebViewPool` owns a `[BrowserTab.ID: WKWebView]` dictionary. Views never create WKWebViews; they call `pool.webView(for: tabID)`.
- `BrowserWebView: NSViewRepresentable` retrieves the pooled view in `makeNSView`, sets delegates on the `Coordinator`, and must **not** recreate a new view in `updateNSView`.
- Script message handlers (`velaPeek`, `velaZap`) are installed via `WebScriptMessageHandlerInstaller.replaceHandler` — always remove before re-adding to avoid duplicate registration.
- Private tabs use a non-persistent `WKWebsiteDataStore`; profiled tabs use `WKWebsiteDataStore(forIdentifier: uuid)`.
- Browser compatibility shims (`AuthPageCompatibility`, `GoogleSignInCompatibility`) are pure static functions — no state.

### Commands
`BrowserCommand` is the canonical enum for all keyboard-triggered actions. Commands flow through `FocusedValues` (`\.browserCommandSink`) from `BrowserCommands` (SwiftUI `Commands`) into `MainBrowserWindow.handle(_:)`. Adding a new command requires: adding a case to `BrowserCommand`, registering it in `BrowserCommands`, and handling it in `MainBrowserWindow.handle(_:)`.

### Animation
**Never** hardcode `.spring()` or `.easeInOut` in views. Use `VelaAnimation` tokens:
- `VelaAnimation.layout` — sidebar, workspace switches, reflows
- `VelaAnimation.micro` — hover reveals, small state changes
- `VelaAnimation.emphasis` — address bar, tab open/close
- `VelaAnimation.drag` — drag-to-reorder
- `VelaAnimation.popSqueeze` — validation effects

Convenience wrappers: `VelaAnimation.withLayout { … }`, `.withMicro { … }`, `.withEmphasis { … }`.

### Persistence
- **Primary state** → `~/Application Support/Vela/browser-state.json` (JSON, pretty-printed, sorted keys)
- **Boosts** → `Vela/boosts.json`
- **Content-blocking exceptions** → `Vela/content-blocking-exceptions.json`
- **Bookmarks** → `Vela/bookmarks.json`
- **History** → `Vela/history.json`
- **Downloads** → `Vela/downloads.json`
- **Routing rules** → `Vela/routing-rules.json`
- **Content-blocker cache** → `Vela/ContentBlocker/`

Use `.atomic` writes throughout. `JSONDecoder.browserState` / `JSONEncoder.browserState` are private extensions in `BrowserPersistence.swift`.

### Error Handling
No `throws` or `Result` on store methods — errors are swallowed with `try?`. Only `BrowserPersistence.load()` and `BrowserPersistence.save(_:)` throw, and callers use `try?`. Error state is surfaced to the UI by setting `tab.errorDescription` and `tab.errorCode` (rendered by `ErrorPageView`).

---

## Important Files

| File | Role |
|---|---|
| `Vela/App/VelaApp.swift` | `@main`, window scene configuration, `BrowserStore.bootstrap()`, `openURL` routing |
| `Vela/State/BrowserStore.swift` | **Entire app state.** All mutations live here. ~1365 lines. |
| `Vela/Models/BrowserStateSnapshot.swift` | Serialized form of state (schema version 3). `decodeIfPresent` with defaults on every optional field. |
| `Vela/Web/WebViewPool.swift` | `WebViewPooling` protocol + `WebViewPool` implementation. Test doubles implement the protocol. |
| `Vela/Web/BrowserWebView.swift` | `NSViewRepresentable` wrapper + `Coordinator: WKNavigationDelegate, WKUIDelegate, WKScriptMessageHandler` |
| `Vela/Services/BrowserPersistence.swift` | Load/save `browser-state.json`. Injected into `BrowserStore` for testability. |
| `Vela/Services/NavigationService.swift` | URL-vs-search resolution + `SearchEngine` enum (Google/DDG/Bing/Brave). Reads `UserDefaults["searchEngine"]`. |
| `Vela/Services/ContentBlockerService.swift` | Downloads EasyList, converts to `WKContentRuleList`, manages per-host exception lists. |
| `Vela/Animation/VelaAnimation.swift` | Canonical spring token definitions. |
| `project.yml` | XcodeGen config — edit this, not `.xcodeproj`. |

---

## Runtime / Tooling Preferences

- **Language:** Swift 6.0 (strict concurrency enabled by default)
- **Framework:** SwiftUI + WebKit; no third-party Swift packages
- **Build system:** Xcode + XcodeGen (`project.yml`)
- **Shell prefix:** `rtk` — all shell commands in this repo must be prefixed with `rtk`
- **No SPM dependencies** — `project.yml` declares only `WebKit.framework` as a system SDK dependency
- **Persistence format:** JSON (`Codable`) via `Foundation`; no CoreData, no SQLite

---

## Testing & QA

### Framework
Swift Testing (`import Testing`) — **not** XCTest.

```swift
@MainActor
@Suite("BrowserStore")
struct BrowserStoreTests {
    @Test("create tab adds it to active workspace and selects it")
    func createTabAddsItToActiveWorkspaceAndSelectsIt() throws { … }
}
```

### Patterns
- All test suites and fixtures are `@MainActor` (required for `BrowserStore` interaction).
- Test isolation: each test constructs its own `BrowserStore` via a private `makeStore()` factory that injects a `StubWebViewPool` and an in-memory `BrowserPersistence` (pointed at a temp directory).
- `StubWebViewPool` implements `WebViewPooling` and records calls without creating real `WKWebView`s.
- Assertions: `#expect(…)` for soft checks, `#require(…)` for unwrap-or-fail.
- No mocks for `NavigationService` or `BrowserPersistence` — inject real instances with overridden paths.

### Coverage Areas
Tests exist for: `BrowserStore` tab lifecycle, workspace CRUD, pinned tab/stub behavior, tab reordering, favorites, profiles, bookmark import parsing, autocomplete, download persistence, navigation service URL resolution, `WebViewPool` creation/removal, script message handler installation, auth page compatibility, Google Sign-In compatibility.

### Running Tests
```sh
rtk xcodebuild test -project Vela.xcodeproj -scheme Vela -destination 'platform=macOS'
```

### What Is Not Tested
UI views, animation behavior, actual WebKit navigation, content blocker EasyList parsing end-to-end, and `DownloadManager` delegate callbacks.
