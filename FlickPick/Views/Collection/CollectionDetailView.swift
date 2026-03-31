import SwiftUI

/// Expanded view of a collection showing all episodes/movies in a grid.
struct CollectionDetailView: View {
    let collection: CollectionRecord
    var onSelect: (MediaFileRecord) -> Void
    var onBack: () -> Void

    @State private var files: [MediaFileRecord] = []
    private let watchHistory = WatchHistory()
    private let mediaRepo = MediaFileRepository()

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            HStack {
                Button(action: onBack) {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                        Text("Back")
                    }
                }
                .buttonStyle(.plain)

                Spacer()
            }
            .padding(.horizontal, 24)
            .padding(.top, 12)

            HStack(alignment: .bottom) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(collection.name)
                        .font(.largeTitle.weight(.bold))

                    Text("\(collection.totalItems) items · \(collection.watchedItems) watched")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }
            .padding(.horizontal, 24)

            // Grid of files
            ScrollView {
                LazyVGrid(
                    columns: [GridItem(.adaptive(minimum: 220), spacing: 16)],
                    spacing: 16
                ) {
                    ForEach(files, id: \.path) { file in
                        MediaCard(
                            file: file,
                            watchProgress: watchHistory.progress(path: file.path),
                            isCompleted: watchHistory.isCompleted(path: file.path),
                            onTap: { onSelect(file) }
                        )
                    }
                }
                .padding(.horizontal, 24)
            }
        }
        .background(Color(white: 0.04))
        .onAppear { loadFiles() }
    }

    private func loadFiles() {
        guard let id = collection.id else { return }
        files = (try? mediaRepo.fetchByCollection(id)) ?? []
    }
}
