import AppKit
import SwiftUI

struct ErrorPageView: View {
    let errorDescription: String
    let errorCode: Int
    let host: String?
    let url: URL?
    @Environment(BrowserStore.self) private var store

    private var isGoogleSignInBlocked: Bool {
        errorCode == BrowserErrorCode.googleEmbeddedSignInBlocked
    }

    private var isSSLError: Bool {
        // NSURLErrorServerCertificateUntrusted = -1202
        // NSURLErrorServerCertificateHasBadDate = -1201
        // NSURLErrorServerCertificateHasUnknownRoot = -1203
        // NSURLErrorServerCertificateNotYetValid = -1204
        errorCode >= -1204 && errorCode <= -1200
    }

    private var errorIcon: String {
        if isGoogleSignInBlocked { return "person.crop.circle.badge.exclamationmark" }

        switch errorCode {
        case -1009: return "wifi.slash"          // Not connected
        case -1001: return "clock.badge.xmark"   // Timed out
        case -1003: return "magnifyingglass"     // Cannot find host
        case -1200 ... -1199: return "lock.trianglebadge.exclamationmark"  // SSL
        default:
            if isSSLError { return "lock.trianglebadge.exclamationmark" }
            return "exclamationmark.triangle"
        }
    }

    private var errorTitle: String {
        if isGoogleSignInBlocked { return "Google Sign-In Needs Your Default Browser" }

        switch errorCode {
        case -1009: return "No Internet Connection"
        case -1001: return "Connection Timed Out"
        case -1003: return "Server Not Found"
        default:
            if isSSLError { return "Connection Not Secure" }
            return "Page Failed to Load"
        }
    }

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    store.activeTheme.primary.color.opacity(0.15),
                    store.activeTheme.secondary.color.opacity(0.08)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 20) {
                Spacer()

                Image(systemName: errorIcon)
                    .font(.system(size: 48))
                    .foregroundStyle(.secondary)

                Text(errorTitle)
                    .font(.title2.weight(.semibold))

                Text(errorDescription)
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 400)

                HStack(spacing: 12) {
                    if isGoogleSignInBlocked, let url {
                        Button("Open in Default Browser") {
                            NSWorkspace.shared.open(GoogleSignInCompatibility.externalFallbackURL(for: url))
                        }
                        .buttonStyle(.borderedProminent)
                    }

                    if isGoogleSignInBlocked {
                        Button("Try Again") {
                            if let tabID = store.activeTabID {
                                store.clearTabError(tabID)
                            }
                            store.reload()
                        }
                        .buttonStyle(.bordered)
                    } else {
                        Button("Try Again") {
                            if let tabID = store.activeTabID {
                                store.clearTabError(tabID)
                            }
                            store.reload()
                        }
                        .buttonStyle(.borderedProminent)
                    }

                    if isSSLError, let host {
                        Button("Proceed Anyway") {
                            store.proceedDespiteSSL(host: host)
                        }
                        .buttonStyle(.bordered)
                        .foregroundStyle(.red)
                    }
                }

                Spacer()
                Spacer()
            }
            .padding(40)
        }
    }
}
