import SwiftUI

/// Expanded view of a collection showing all episodes/movies in a grid.
struct CollectionDetailView: View {
    let collection: CollectionRecord
    var onSelect: (MediaFileRecord) -> Void
    var onBack: () -> Void

    @State private var files: [MediaFileRecord] = []
    @State private var watchState: [Int64: (progress: Double, completed: Bool)] = [:]
    private let mediaRepo = MediaFileRepository()
    private let watchRepo = WatchRepository()

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            HStack {
                Button(action: onBack) {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                        Text("Back")
                    }
                    .foregroundStyle(FP.textSecondary)
                }
                .buttonStyle(.plain)
                Spacer()
            }
            .padding(.horizontal, FP.sectionPadding)
            .padding(.top, 12)

            HStack(alignment: .bottom) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(collection.name)
                        .font(FP.titleFont)
                        .foregroundStyle(FP.textPrimary)

                    Text("\(collection.totalItems) items · \(collection.watchedItems) watched")
                        .font(FP.bodyFont)
                        .foregroundStyle(FP.textSecondary)
                }
                Spacer()
            }
            .padding(.horizontal, FP.sectionPadding)

            // Grid of files
            ScrollView {
                LazyVGrid(
                    columns: [GridItem(.adaptive(minimum: FP.cardWidth), spacing: FP.cardSpacing)],
                    spacing: FP.cardSpacing
                ) {
                    ForEach(files, id: \.path) { file in
                        let state = file.id.flatMap { watchState[$0] }
                        MediaCard(
                            file: file,
                            watchProgress: state?.progress ?? 0,
                            isCompleted: state?.completed ?? false,
                            onTap: { onSelect(file) }
                        )
                    }
                }
                .padding(.horizontal, FP.sectionPadding)
            }
        }
        .background(FP.background)
        .onAppear { loadFiles() }
    }

    private func loadFiles() {
        guard let id = collection.id else { return }
        files = (try? mediaRepo.fetchByCollection(id)) ?? []

        // Pre-fetch all watch state in one pass
        guard let allWatch = try? watchRepo.fetchAll() else { return }
        let fileIds = Set(files.compactMap(\.id))
        var stateMap: [Int64: (progress: Double, completed: Bool)] = [:]
        for record in allWatch where fileIds.contains(record.mediaFileId) {
            let file = files.first { $0.id == record.mediaFileId }
            let duration = file?.durationSeconds ?? 0
            let progress = duration > 0 ? min(1.0, record.positionSeconds / duration) : 0
            stateMap[record.mediaFileId] = (progress: progress, completed: record.completed)
        }
        watchState = stateMap
    }
}
