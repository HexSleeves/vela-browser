import SwiftUI

struct AddressBar: View {
    @Binding var text: String
    var isFocused: Bool
    var isLoading: Bool = false
    var estimatedProgress: Double = 0
    var accentColor: Color = .accentColor
    var onSubmit: () -> Void

    @State private var submitTrigger = false

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)

            TextField("Search or enter website", text: $text)
                .textFieldStyle(.plain)
                .onSubmit {
                    submitTrigger.toggle()
                    onSubmit()
                }
        }
        .padding(.horizontal, 12)
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
