import SwiftUI

struct AddressBar: View {
    @Binding var text: String
    var isFocused: Bool
    var isLoading: Bool = false
    var estimatedProgress: Double = 0
    var canGoBack: Bool = false
    var canGoForward: Bool = false
    var isSecure: Bool = false
    var accentColor: Color = .accentColor
    var isBookmarked: Bool = false
    var isReaderMode: Bool = false
    var hasActiveBoosts: Bool = false
    var blockedCount: Int = 0
    var isContentBlockingDisabled: Bool = false
    var isZapActive: Bool = false
    var onToggleContentBlocking: () -> Void = {}
    var onToggleZap: () -> Void = {}
    var suggestions: [AutocompleteSuggestion] = []
    var onSubmit: () -> Void
    var onBack: () -> Void = {}
    var onForward: () -> Void = {}
    var onReload: () -> Void = {}
    var onToggleBookmark: () -> Void = {}
    var onToggleReader: () -> Void = {}
    var onSelectSuggestion: (AutocompleteSuggestion) -> Void = { _ in }

    @State private var submitTrigger = false

    var body: some View {
        VStack(spacing: 6) {
            bar

            if shouldShowSuggestions {
                suggestionsView
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .phaseAnimator([false, true], trigger: submitTrigger) { content, phase in
            content
                .scaleEffect(phase ? 0.97 : 1.0)
                .shadow(
                    color: phase ? accentColor.opacity(0.5) : .clear,
                    radius: phase ? 10 : 0
                )
        } animation: { phase in
            phase ? VelaAnimation.popSqueeze : VelaAnimation.emphasis
        }
        .shadow(
            color: isFocused ? accentColor.opacity(0.2) : .clear,
            radius: isFocused ? 6 : 0
        )
        .animation(VelaAnimation.micro, value: isFocused)
        .animation(VelaAnimation.micro, value: shouldShowSuggestions)
    }

    private var bar: some View {
        HStack(spacing: 6) {
            navigationButtons

            Image(systemName: isSecure ? "lock.fill" : "magnifyingglass")
                .foregroundStyle(isSecure ? .green : .secondary)
                .font(.caption)
                .frame(width: 16)

            TextField("Search or enter website", text: $text)
                .textFieldStyle(.plain)
                .onSubmit {
                    submitTrigger.toggle()
                    onSubmit()
                }

            Button {
                onToggleReader()
            } label: {
                Image(systemName: isReaderMode ? "book.fill" : "book")
                    .font(.caption)
                    .foregroundStyle(isReaderMode ? Color.accentColor : .secondary)
                    .frame(width: 16, height: 16)
            }
            .buttonStyle(.plain)
            .help(isReaderMode ? "Exit Reader Mode" : "Reader Mode")

            if hasActiveBoosts {
                Image(systemName: "bolt.fill")
                    .font(.caption)
                    .foregroundStyle(.yellow)
                    .frame(width: 16, height: 16)
                    .help("Boosts active on this site")
            }

            Button {
                onToggleContentBlocking()
            } label: {
                HStack(spacing: 2) {
                    Image(systemName: isContentBlockingDisabled ? "shield.slash" : "shield.lefthalf.filled")
                        .font(.caption)
                        .foregroundStyle(isContentBlockingDisabled ? Color.secondary : Color.green)
                    if blockedCount > 0 {
                        Text("\(blockedCount)")
                            .font(.system(size: 9, weight: .medium))
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(height: 16)
            }
            .buttonStyle(.plain)
            .help(isContentBlockingDisabled ? "Content blocking disabled for this site" : "Content blocking active — \(blockedCount) blocked")

            Button {
                onToggleZap()
            } label: {
                Image(systemName: isZapActive ? "bolt.circle.fill" : "bolt.circle")
                    .font(.caption)
                    .foregroundStyle(isZapActive ? Color.orange : Color.secondary)
                    .frame(width: 16, height: 16)
            }
            .buttonStyle(.plain)
            .help(isZapActive ? "Exit Zap Mode" : "Zap Element — click to hide")

            Button {
                onToggleBookmark()
            } label: {
                Image(systemName: isBookmarked ? "star.fill" : "star")
                    .font(.caption)
                    .foregroundStyle(isBookmarked ? .yellow : .secondary)
                    .frame(width: 16, height: 16)
            }
            .buttonStyle(.plain)
            .help(isBookmarked ? "Remove Bookmark" : "Add Bookmark")
            .animation(VelaAnimation.micro, value: isBookmarked)

            Button {
                onReload()
            } label: {
                Image(systemName: isLoading ? "xmark" : "arrow.clockwise")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(width: 16, height: 16)
            }
            .buttonStyle(.plain)
            .help(isLoading ? "Stop Loading" : "Reload")
        }
        .padding(.horizontal, 10)
        .padding(.vertical, isFocused ? 10 : 8)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 8))
        .overlay(progressBar, alignment: .bottom)
    }

    private var shouldShowSuggestions: Bool {
        isFocused && !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !suggestions.isEmpty
    }

    private var suggestionsView: some View {
        VStack(alignment: .leading, spacing: 2) {
            ForEach(suggestions) { suggestion in
                Button {
                    onSelectSuggestion(suggestion)
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: suggestion.iconName)
                            .font(.caption)
                            .foregroundStyle(iconColor(for: suggestion.kind))
                            .frame(width: 18)

                        VStack(alignment: .leading, spacing: 1) {
                            Text(suggestion.title)
                                .lineLimit(1)
                                .font(.callout)
                            Text(suggestion.subtitle)
                                .lineLimit(1)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        Spacer()

                        Text(suggestion.kind.rawValue.capitalized)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 7)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(6)
        .background(.ultraThickMaterial, in: RoundedRectangle(cornerRadius: 10))
        .shadow(color: .black.opacity(0.14), radius: 14, y: 6)
    }

    private func iconColor(for kind: AutocompleteSuggestion.Kind) -> Color {
        switch kind {
        case .bookmark: .yellow
        case .tab: .accentColor
        case .history: .secondary
        case .search: .secondary
        case .url: .secondary
        }
    }

    private var navigationButtons: some View {
        HStack(spacing: 2) {
            Button {
                onBack()
            } label: {
                Image(systemName: "chevron.left")
                    .font(.caption.weight(.semibold))
                    .frame(width: 20, height: 20)
            }
            .buttonStyle(.plain)
            .disabled(!canGoBack)
            .opacity(canGoBack ? 1 : 0.3)
            .help("Back (⌘[)")

            Button {
                onForward()
            } label: {
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .frame(width: 20, height: 20)
            }
            .buttonStyle(.plain)
            .disabled(!canGoForward)
            .opacity(canGoForward ? 1 : 0.3)
            .help("Forward (⌘])")
        }
    }

    @ViewBuilder
    private var progressBar: some View {
        if isLoading && estimatedProgress > 0 {
            GeometryReader { geometry in
                RoundedRectangle(cornerRadius: 1)
                    .fill(accentColor)
                    .frame(width: geometry.size.width * estimatedProgress, height: 2)
                    .animation(VelaAnimation.micro, value: estimatedProgress)
            }
            .frame(height: 2)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .transition(.opacity)
        }
    }
}
