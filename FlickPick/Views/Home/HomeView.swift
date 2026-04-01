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
                HStack(alignment: .bottom) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("FlickPick")
                            .font(FP.titleFont)
                            .foregroundStyle(FP.textPrimary)
                        Text("Your Library")
                            .font(FP.bodyFont)
                            .foregroundStyle(FP.textSecondary)
                    }
                    Spacer()

                    SurpriseMeButton {
                        if let file = libraryVM.surpriseMe() {
                            onSelectFile(file)
                        }
                    }
                }
                .padding(.horizontal, FP.sectionPadding)
                .padding(.top, 20)

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
        .background(FP.background)
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "film.stack")
                .font(.system(size: 48))
                .foregroundStyle(FP.textSecondary.opacity(0.3))

            Text("No media yet")
                .font(FP.subtitleFont)
                .foregroundStyle(FP.textSecondary)

            Text("Add a folder in Settings or drag a video file to get started.")
                .font(FP.bodyFont)
                .foregroundStyle(FP.textSecondary.opacity(0.6))
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
    }
}
