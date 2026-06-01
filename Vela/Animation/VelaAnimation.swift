import SwiftUI

/// Shared animation token system for consistent spring physics across all Vela surfaces.
/// Every animated transition in the app should reference these presets — no hardcoded
/// `.spring()` or `.easeInOut` in views.
enum VelaAnimation {

    // MARK: - Spring Presets

    /// Layout-level transitions: sidebar collapse/expand, workspace switching, tab list reflows.
    /// Smooth and controlled — fast enough to feel responsive, damped enough to avoid overshoot.
    static let layout: Animation = .spring(response: 0.35, dampingFraction: 0.8)

    /// Micro-interactions: hover reveals, button feedback, small state changes.
    /// Snappier than layout — these should feel instant but not jarring.
    static let micro: Animation = .spring(response: 0.25, dampingFraction: 0.75)

    /// Emphasis effects: address bar shadow-pop settle, tab open/close, selection highlight glide.
    /// Slightly underdamped for a lively, physical feel.
    static let emphasis: Animation = .spring(response: 0.4, dampingFraction: 0.65)

    /// Drag tracking: tab drag-to-reorder finger-following.
    /// Very responsive with high damping — the dragged element should stick to the pointer.
    static let drag: Animation = .spring(response: 0.18, dampingFraction: 0.9)

    /// Pop squeeze: the fast inward phase of a shadow-pop or validation effect.
    /// Quick and slightly bouncy — meant to precede an emphasis settle.
    static let popSqueeze: Animation = .spring(response: 0.12, dampingFraction: 0.6)

    // MARK: - Fade Durations

    /// Standard fade duration for content appearing/disappearing during layout transitions.
    static let fadeDuration: Double = 0.15

    // MARK: - Convenience

    /// Spring animation scoped to a specific value for `animation(_:value:)` usage.
    static func layout<V: Equatable>(value: V) -> Animation {
        layout
    }

    /// Wraps a state mutation in the layout spring.
    static func withLayout(_ body: () -> Void) {
        withAnimation(layout, body)
    }

    /// Wraps a state mutation in the micro spring.
    static func withMicro(_ body: () -> Void) {
        withAnimation(micro, body)
    }

    /// Wraps a state mutation in the emphasis spring.
    static func withEmphasis(_ body: () -> Void) {
        withAnimation(emphasis, body)
    }
}
