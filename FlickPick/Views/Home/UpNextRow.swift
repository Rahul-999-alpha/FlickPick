import SwiftUI

/// Row showing next unwatched episodes from in-progress series.
struct UpNextRow: View {
    let items: [MediaFileRecord]
    var onSelect: (MediaFileRecord) -> Void

    var body: some View {
        if !items.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                Text("Up Next")
                    .font(.title2.weight(.semibold))
                    .padding(.horizontal, 24)

                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHStack(spacing: 16) {
                        ForEach(items, id: \.path) { file in
                            MediaCard(
                                file: file,
                                watchProgress: 0,
                                isCompleted: false,
                                onTap: { onSelect(file) }
                            )
                        }
                    }
                    .padding(.horizontal, 24)
                }
            }
        }
    }
}
