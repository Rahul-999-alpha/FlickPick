import SwiftUI

/// Row showing recently indexed files.
struct RecentlyAddedRow: View {
    let items: [MediaFileRecord]
    var onSelect: (MediaFileRecord) -> Void

    var body: some View {
        if !items.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                Text("Recently Added")
                    .font(FP.sectionFont)
                    .foregroundStyle(FP.textPrimary)
                    .padding(.horizontal, FP.sectionPadding)

                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHStack(spacing: FP.cardSpacing) {
                        ForEach(items, id: \.path) { file in
                            ZStack(alignment: .topLeading) {
                                MediaCard(
                                    file: file,
                                    watchProgress: 0,
                                    isCompleted: false,
                                    onTap: { onSelect(file) }
                                )

                                // "NEW" badge
                                Text("NEW")
                                    .font(FP.badgeFont)
                                    .foregroundStyle(.black)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(FP.newBadge, in: RoundedRectangle(cornerRadius: 4))
                                    .padding(8)
                            }
                        }
                    }
                    .padding(.horizontal, FP.sectionPadding)
                }
            }
        }
    }
}
