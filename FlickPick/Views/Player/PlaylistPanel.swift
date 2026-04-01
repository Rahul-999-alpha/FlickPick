import SwiftUI

/// Slide-in panel showing the current playlist.
struct PlaylistPanel: View {
    @ObservedObject var viewModel: PlayerViewModel
    @Binding var isVisible: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            headerView
            Divider().overlay(FP.border)
            listView
        }
        .frame(width: 280)
        .background(FP.surface)
    }

    private var headerView: some View {
        HStack {
            Text(viewModel.playlistName.isEmpty ? "Playlist" : viewModel.playlistName)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(FP.textPrimary)
            Spacer()
            Button {
                withAnimation { isVisible = false }
            } label: {
                Image(systemName: "xmark")
                    .foregroundStyle(FP.textSecondary)
            }
            .buttonStyle(.plain)
        }
        .padding(12)
    }

    private var listView: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0) {
                ForEach(Array(viewModel.playlist.enumerated()), id: \.element) { index, url in
                    playlistRow(index: index, url: url)
                }
            }
        }
    }

    private func playlistRow(index: Int, url: URL) -> some View {
        Button {
            viewModel.playAtIndex(index)
        } label: {
            HStack {
                if index == viewModel.currentIndex {
                    Image(systemName: "play.fill")
                        .font(.caption)
                        .foregroundColor(FP.accent)
                        .frame(width: 20)
                } else {
                    Text("\(index + 1)")
                        .font(FP.monoFont)
                        .foregroundStyle(FP.textSecondary)
                        .frame(width: 20)
                }

                Text(url.deletingPathExtension().lastPathComponent)
                    .font(FP.bodyFont)
                    .lineLimit(1)
                    .foregroundStyle(index == viewModel.currentIndex ? FP.textPrimary : FP.textSecondary)

                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                index == viewModel.currentIndex
                ? FP.accentGlow
                : Color.clear
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
