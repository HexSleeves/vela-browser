import SwiftUI

struct FindBarView: View {
    @Environment(BrowserStore.self) private var store
    @FocusState private var isFocused: Bool

    var body: some View {
        @Bindable var store = store

        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
                .font(.caption)

            TextField("Find on page", text: $store.findText)
                .textFieldStyle(.plain)
                .focused($isFocused)
                .onSubmit {
                    store.findNext()
                }
                .onChange(of: store.findText) {
                    store.findInPage(store.findText)
                }

            Button {
                store.findPrevious()
            } label: {
                Image(systemName: "chevron.up")
                    .font(.caption.weight(.semibold))
            }
            .buttonStyle(.plain)
            .help("Previous Match (⌘⇧G)")

            Button {
                store.findNext()
            } label: {
                Image(systemName: "chevron.down")
                    .font(.caption.weight(.semibold))
            }
            .buttonStyle(.plain)
            .help("Next Match (⌘G)")

            Button {
                VelaAnimation.withMicro {
                    store.toggleFindBar()
                }
            } label: {
                Image(systemName: "xmark")
                    .font(.caption)
            }
            .buttonStyle(.plain)
            .help("Close (Escape)")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 8))
        .padding(.horizontal, 10)
        .onAppear {
            isFocused = true
        }
        .onKeyPress(.escape) {
            VelaAnimation.withMicro {
                store.toggleFindBar()
            }
            return .handled
        }
    }
}
