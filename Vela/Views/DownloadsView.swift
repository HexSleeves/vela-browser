import SwiftUI

struct DownloadsView: View {
    @Environment(BrowserStore.self) private var store

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("Downloads")
                    .font(.headline)

                Spacer()

                if !store.downloads.isEmpty {
                    Button("Clear") {
                        VelaAnimation.withMicro {
                            store.downloads.removeAll { $0.state != .downloading }
                        }
                    }
                    .buttonStyle(.plain)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)

            Divider()

            if store.downloads.isEmpty {
                VStack {
                    Spacer()
                    Text("No downloads")
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                    Spacer()
                }
                .frame(minHeight: 80)
            } else {
                ScrollView {
                    VStack(spacing: 2) {
                        ForEach(store.downloads) { item in
                            DownloadRowView(item: item)
                        }
                    }
                    .padding(6)
                }
                .frame(maxHeight: 300)
            }
        }
        .frame(width: 320)
        .background(.ultraThickMaterial, in: RoundedRectangle(cornerRadius: 10))
    }
}

private struct DownloadRowView: View {
    let item: DownloadItem

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: iconName)
                .foregroundStyle(iconColor)
                .frame(width: 20)

            VStack(alignment: .leading, spacing: 4) {
                Text(item.filename)
                    .lineLimit(1)
                    .font(.body)

                if item.state == .downloading {
                    ProgressView(value: item.progress)
                        .progressViewStyle(.linear)

                    Text(progressText)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                } else if item.state == .failed {
                    Text(item.error ?? "Download failed")
                        .font(.caption2)
                        .foregroundStyle(.red)
                } else if item.state == .completed {
                    Text("Completed")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            if item.state == .completed, let url = item.destinationURL {
                Button {
                    NSWorkspace.shared.activateFileViewerSelecting([url])
                } label: {
                    Image(systemName: "folder")
                        .font(.caption)
                }
                .buttonStyle(.plain)
                .help("Show in Finder")
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
    }

    private var iconName: String {
        switch item.state {
        case .downloading: return "arrow.down.circle"
        case .completed: return "checkmark.circle.fill"
        case .failed: return "xmark.circle.fill"
        case .cancelled: return "minus.circle"
        }
    }

    private var iconColor: Color {
        switch item.state {
        case .downloading: return .accentColor
        case .completed: return .green
        case .failed: return .red
        case .cancelled: return .secondary
        }
    }

    private var progressText: String {
        if item.totalBytes > 0 {
            let received = ByteCountFormatter.string(fromByteCount: item.bytesReceived, countStyle: .file)
            let total = ByteCountFormatter.string(fromByteCount: item.totalBytes, countStyle: .file)
            return "\(received) of \(total)"
        }
        return "\(ByteCountFormatter.string(fromByteCount: item.bytesReceived, countStyle: .file))"
    }
}
