import SwiftUI

struct BrowserSurfaceView: View {
    @Binding var addressText: String
    var isAddressFocused: FocusState<Bool>.Binding
    @Environment(BrowserStore.self) private var store

    var body: some View {
        VStack(spacing: 0) {
            AddressBar(
                text: $addressText,
                isFocused: isAddressFocused.wrappedValue,
                isLoading: store.activeTab?.isLoading ?? false,
                estimatedProgress: store.activeTab?.estimatedProgress ?? 0,
                accentColor: store.activeTheme.accent.color
            ) {
                store.loadAddressInput(addressText)
            }
            .focused(isAddressFocused)
            .padding(10)

            Divider()

            if let tabID = store.activeTabID {
                BrowserWebView(tabID: tabID)
                    .id(tabID)
            } else {
                emptyState
            }
        }
        .onChange(of: store.activeTabID) {
            addressText = store.activeTab?.url?.absoluteString ?? ""
        }
    }

    private var emptyState: some View {
        ContentUnavailableView(
            "No Tab Open",
            systemImage: "safari",
            description: Text("Create a tab to start browsing.")
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
