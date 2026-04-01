import SwiftUI

/// Row showing next unwatched episodes from in-progress series.
struct UpNextRow: View {
    let items: [MediaFileRecord]
    var onSelect: (MediaFileRecord) -> Void

    var body: some View {
        if !items.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                Text("Up Next")
                    .font(FP.sectionFont)
                    .foregroundStyle(FP.textPrimary)
                    .padding(.horizontal, FP.sectionPadding)

                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHStack(spacing: FP.cardSpacing) {
                        ForEach(items, id: \.path) { file in
                            MediaCard(
                                file: file,
                                watchProgress: 0,
                                isCompleted: false,
                                onTap: { onSelect(file) }
                            )
                        }
                    }
                    .padding(.horizontal, FP.sectionPadding)
                }
            }
        }
    }
}
