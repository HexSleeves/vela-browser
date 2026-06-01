import SwiftUI

struct TabSectionView: View {
    let title: String
    let tabs: [BrowserTab]

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)

            ForEach(tabs) { tab in
                TabRowView(tab: tab)
            }
        }
    }
}
