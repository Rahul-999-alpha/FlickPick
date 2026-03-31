import SwiftUI

/// Horizontal row of in-progress items.
struct ContinueWatchingRow: View {
    let items: [(MediaFileRecord, WatchRecord)]
    var onSelect: (MediaFileRecord) -> Void

    var body: some View {
        if !items.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                Text("Continue Watching")
                    .font(.title2.weight(.semibold))
                    .padding(.horizontal, 24)

                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHStack(spacing: 16) {
                        ForEach(items, id: \.0.path) { file, watch in
                            MediaCard(
                                file: file,
                                watchProgress: file.durationSeconds.map { watch.positionSeconds / $0 } ?? 0,
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
