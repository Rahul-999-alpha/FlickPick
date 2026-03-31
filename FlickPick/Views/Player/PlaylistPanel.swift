import SwiftUI

/// Slide-in panel showing the current playlist.
struct PlaylistPanel: View {
    @ObservedObject var viewModel: PlayerViewModel
    @Binding var isVisible: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            headerView
            Divider()
            listView
        }
        .frame(width: 280)
        .background(.regularMaterial)
    }

    private var headerView: some View {
        HStack {
            Text(viewModel.playlistName.isEmpty ? "Playlist" : viewModel.playlistName)
                .font(.headline)
            Spacer()
            Button {
                withAnimation { isVisible = false }
            } label: {
                Image(systemName: "xmark")
            }
            .buttonStyle(.plain)
        }
        .padding(12)
    }

    private var listView: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0) {
                ForEach(0..<viewModel.playlist.count, id: \.self) { index in
                    playlistRow(index: index, url: viewModel.playlist[index])
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
                        .foregroundColor(.accentColor)
                        .frame(width: 20)
                } else {
                    Text("\(index + 1)")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                        .frame(width: 20)
                }

                Text(url.deletingPathExtension().lastPathComponent)
                    .lineLimit(1)
                    .foregroundStyle(index == viewModel.currentIndex ? .primary : .secondary)

                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                index == viewModel.currentIndex
                ? Color.accentColor.opacity(0.1)
                : Color.clear
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
