import SwiftUI

/// Horizontal row of in-progress items.
struct ContinueWatchingRow: View {
    let items: [(MediaFileRecord, WatchRecord)]
    var onSelect: (MediaFileRecord) -> Void

    var body: some View {
        if !items.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                Text("Continue Watching")
                    .font(FP.sectionFont)
                    .foregroundStyle(FP.textPrimary)
                    .padding(.horizontal, FP.sectionPadding)

                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHStack(spacing: FP.cardSpacing) {
                        ForEach(items, id: \.0.path) { file, watch in
                            MediaCard(
                                file: file,
                                watchProgress: file.durationSeconds.map { min(1.0, watch.positionSeconds / max($0, 1)) } ?? 0,
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
