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
                isReaderMode: store.activeTab?.isReaderMode ?? false,
                hasActiveBoosts: store.activeTab?.url?.host().flatMap { !store.boostsForHost($0).isEmpty } ?? false,
                onSubmit: { store.loadAddressInput(addressText) },
                onBack: { store.goBack() },
                onForward: { store.goForward() },
                onReload: { store.reload() },
                onToggleBookmark: { store.toggleBookmark() },
                onToggleReader: { store.toggleReaderMode() }
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
                if let splitID = store.splitTabID {
                    // Split view: two web views side by side
                    HSplitView {
                        BrowserWebView(tabID: tabID)
                            .id(tabID)

                        BrowserWebView(tabID: splitID)
                            .id(splitID)
                    }
                    .overlay(alignment: .top) {
                        // Close split button at top center
                        Button {
                            VelaAnimation.withLayout {
                                store.closeSplit()
                            }
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.title3)
                                .foregroundStyle(.secondary)
                                .padding(6)
                                .background(.regularMaterial, in: Circle())
                        }
                        .buttonStyle(.plain)
                        .padding(.top, 8)
                        .help("Close Split View")
                    }
                } else {
                    BrowserWebView(tabID: tabID)
                        .id(tabID)
                }
            } else {
                NewTabPageView()
            }
        }
        .onChange(of: store.activeTabID) {
            addressText = store.activeTab?.url?.absoluteString ?? ""
        }
        .onChange(of: store.activeTab?.url) {
            addressText = store.activeTab?.url?.absoluteString ?? ""
        }
    }
}
