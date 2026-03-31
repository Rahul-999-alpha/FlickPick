import SwiftUI

/// Thumbnail card with progress bar, title, and watched state.
struct MediaCard: View {
    let file: MediaFileRecord
    let watchProgress: Double  // 0...1
    let isCompleted: Bool
    var onTap: () -> Void = {}

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 6) {
                // Thumbnail
                ZStack(alignment: .bottomLeading) {
                    thumbnailView
                        .frame(width: 220, height: 124)
                        .clipShape(RoundedRectangle(cornerRadius: 8))

                    // Progress bar
                    if watchProgress > 0 && !isCompleted {
                        GeometryReader { geo in
                            VStack {
                                Spacer()
                                Rectangle()
                                    .fill(Color.accentColor)
                                    .frame(width: geo.size.width * watchProgress, height: 3)
                            }
                        }
                    }

                    // Completed badge
                    if isCompleted {
                        HStack {
                            Spacer()
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(Color.green)
                                .font(.title3)
                                .padding(6)
                        }
                        .frame(maxHeight: .infinity, alignment: .topTrailing)
                    }
                }

                // Title
                Text(file.baseName ?? file.filename)
                    .font(.caption)
                    .foregroundStyle(.primary)
                    .lineLimit(1)

                // Metadata
                if let duration = file.durationSeconds {
                    Text(formatDuration(duration))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(width: 220)
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var thumbnailView: some View {
        if let thumbPath = file.thumbnailPath,
           let image = NSImage(contentsOfFile: thumbPath) {
            Image(nsImage: image)
                .resizable()
                .aspectRatio(contentMode: .fill)
        } else {
            Rectangle()
                .fill(Color(white: 0.12))
                .overlay {
                    Image(systemName: "film")
                        .font(.largeTitle)
                        .foregroundStyle(.quaternary)
                }
        }
    }

    private func formatDuration(_ seconds: Double) -> String {
        let total = Int(seconds)
        let h = total / 3600
        let m = (total % 3600) / 60
        if h > 0 { return "\(h)h \(m)m" }
        return "\(m)m"
    }
}
