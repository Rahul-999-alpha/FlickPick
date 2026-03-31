import SwiftUI

/// Row showing recently indexed files.
struct RecentlyAddedRow: View {
    let items: [MediaFileRecord]
    var onSelect: (MediaFileRecord) -> Void

    var body: some View {
        if !items.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                Text("Recently Added")
                    .font(.title2.weight(.semibold))
                    .padding(.horizontal, 24)

                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHStack(spacing: 16) {
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
                                    .font(.system(size: 9, weight: .bold))
                                    .foregroundStyle(.black)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Color.orange, in: RoundedRectangle(cornerRadius: 4))
                                    .padding(6)
                            }
                        }
                    }
                    .padding(.horizontal, 24)
                }
            }
        }
    }
}
