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
    var onSubmit: () -> Void
    var onBack: () -> Void = {}
    var onForward: () -> Void = {}
    var onReload: () -> Void = {}

    @State private var submitTrigger = false

    var body: some View {
        HStack(spacing: 6) {
            // Navigation buttons
            navigationButtons

            // Security / Search icon
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

            // Reload / Stop button
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
