import SwiftUI

struct FaviconView: View {
    let url: URL?
    var size: CGFloat = 16
    var fallbackSystemImage = "globe"

    @State private var image: NSImage?

    var body: some View {
        Group {
            if let image {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
            } else {
                Image(systemName: fallbackSystemImage)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(width: size, height: size)
        .task(id: url?.host()) {
            image = nil
            guard let data = await FaviconCache.shared.faviconData(for: url),
                  let loadedImage = NSImage(data: data) else {
                image = nil
                return
            }
            image = loadedImage
        }
    }
}
