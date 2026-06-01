# Repository Guidelines

## Project Structure & Module Organization

Vela is a macOS SwiftUI browser application generated from `project.yml`. App source lives in `Vela/`, organized by responsibility: `App/` for entry points and commands, `Views/` for SwiftUI screens and controls, `State/` for browser state, `Models/` for data types, `Services/` for persistence/navigation/download support, `Web/` for WebKit integration, and `Animation/` for shared animation helpers. Unit tests live in `VelaTests/`. Treat `Vela.xcodeproj/` as generated output; update `project.yml` when project structure changes.

## Build, Test, and Development Commands

Prefix shell commands with `rtk` in this workspace.

- `rtk xcodegen generate`: regenerate `Vela.xcodeproj` from `project.yml` after adding files, targets, or settings.
- `rtk xcodebuild -project Vela.xcodeproj -scheme Vela -configuration Debug build`: build the macOS app.
- `rtk xcodebuild test -project Vela.xcodeproj -scheme Vela -destination 'platform=macOS'`: run the Swift Testing suite.
- `rtk open Vela.xcodeproj`: open the project in Xcode for local UI iteration.

## Coding Style & Naming Conventions

Use Swift 6 and macOS 14 APIs. Follow the existing 4-space indentation, concise SwiftUI composition, and type-per-file organization. Name Swift types in `UpperCamelCase`, properties and methods in `lowerCamelCase`, and test methods as behavior descriptions such as `createWorkspaceAddsAndSwitches()`. Prefer small services or model methods over view-only business logic. Keep comments sparse and useful, especially around non-obvious WebKit, persistence, or concurrency behavior.

## Testing Guidelines

Tests use the Swift Testing framework with `import Testing`, `@Suite`, `@Test`, `#expect`, and `#require`. Add tests in `VelaTests/` next to the behavior being changed, using descriptive test names and focused fixtures. Cover state transitions, parsing, persistence, and navigation edge cases before UI-only polish. Run the full test command before opening a pull request.

## Commit & Pull Request Guidelines

Recent history uses short imperative commit subjects, for example `Add sidebar tab filter search` and `Add private browsing window`. Keep commits focused and avoid mixing generated project churn with unrelated code changes. Pull requests should summarize the user-visible change, list test commands run, mention any `project.yml` or generated project updates, and include screenshots or short screen recordings for visible UI changes.

## Agent-Specific Instructions

Respect this file for the repository root and all child paths. Do not overwrite user changes. Use `rtk` for shell commands, prefer `rg` for search, and keep edits scoped to the requested behavior.
