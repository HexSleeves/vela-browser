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
                canGoBack: store.activeTab?.canGoBack ?? false,
                canGoForward: store.activeTab?.canGoForward ?? false,
                isSecure: store.activeTab?.url?.scheme == "https",
                accentColor: store.activeTheme.accent.color,
                isBookmarked: store.activeTab?.url.flatMap { store.isBookmarked($0) } ?? false,
                onSubmit: { store.loadAddressInput(addressText) },
                onBack: { store.goBack() },
                onForward: { store.goForward() },
                onReload: { store.reload() },
                onToggleBookmark: { store.toggleBookmark() }
            )
            .focused(isAddressFocused)
            .padding(10)

            if store.isFindBarVisible {
                FindBarView()
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .padding(.bottom, 4)
            }

            Divider()

            if let tab = store.activeTab, let errorDesc = tab.errorDescription, let errorCode = tab.errorCode {
                ErrorPageView(
                    errorDescription: errorDesc,
                    errorCode: errorCode,
                    host: tab.url?.host()
                )
            } else if let tabID = store.activeTabID, store.activeTab?.url != nil {
                BrowserWebView(tabID: tabID)
                    .id(tabID)
            } else {
                NewTabPageView()
            }
        }
        .onChange(of: store.activeTabID) {
            addressText = store.activeTab?.url?.absoluteString ?? ""
        }
    }
}
