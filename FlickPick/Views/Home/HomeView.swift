import SwiftUI

/// Netflix-style home screen with carousels.
struct HomeView: View {
    @ObservedObject var libraryVM: LibraryViewModel
    var onSelectFile: (MediaFileRecord) -> Void
    var onSelectCollection: (CollectionRecord) -> Void

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 28) {
                // Header
                HStack {
                    VStack(alignment: .leading) {
                        Text("FlickPick")
                            .font(.largeTitle.weight(.bold))
                        Text("Your Library")
                            .font(.title3)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()

                    SurpriseMeButton {
                        if let file = libraryVM.surpriseMe() {
                            onSelectFile(file)
                        }
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 16)

                // Continue Watching
                ContinueWatchingRow(
                    items: libraryVM.continueWatching,
                    onSelect: onSelectFile
                )

                // Up Next
                UpNextRow(
                    items: libraryVM.upNext,
                    onSelect: onSelectFile
                )

                // Collections
                CollectionsRow(
                    collections: libraryVM.collections,
                    onSelect: onSelectCollection
                )

                // Recently Added
                RecentlyAddedRow(
                    items: libraryVM.recentlyAdded,
                    onSelect: onSelectFile
                )

                // Empty state
                if libraryVM.recentlyAdded.isEmpty && !libraryVM.hasWatchedFolders {
                    emptyState
                }

                Spacer(minLength: 40)
            }
        }
        .background(Color(white: 0.04))
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "film.stack")
                .font(.system(size: 48))
                .foregroundStyle(.quaternary)

            Text("No media yet")
                .font(.title2)
                .foregroundStyle(.secondary)

            Text("Add a folder in Settings or drag a video file to get started.")
                .font(.body)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
    }
}
