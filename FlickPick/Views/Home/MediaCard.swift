import SwiftUI

/// Thumbnail card with progress bar, title, hover state, and watched indicator.
struct MediaCard: View {
    let file: MediaFileRecord
    let watchProgress: Double  // 0...1
    let isCompleted: Bool
    var onTap: () -> Void = {}

    @State private var isHovering = false
    @State private var cachedImage: NSImage?

    private var clampedProgress: Double {
        min(max(watchProgress, 0), 1)
    }

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 6) {
                // Thumbnail
                ZStack(alignment: .bottomLeading) {
                    thumbnailView
                        .frame(width: FP.cardWidth, height: FP.cardHeight)
                        .clipShape(RoundedRectangle(cornerRadius: FP.cardRadius))

                    // Progress bar
                    if clampedProgress > 0 && !isCompleted {
                        GeometryReader { geo in
                            VStack {
                                Spacer()
                                RoundedRectangle(cornerRadius: 1.5)
                                    .fill(FP.accent)
                                    .frame(width: geo.size.width * clampedProgress, height: 3)
                            }
                        }
                    }

                    // Completed badge
                    if isCompleted {
                        HStack {
                            Spacer()
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(FP.watched)
                                .font(.title3)
                                .padding(6)
                        }
                        .frame(maxHeight: .infinity, alignment: .topTrailing)
                    }
                }
                .overlay(
                    RoundedRectangle(cornerRadius: FP.cardRadius)
                        .strokeBorder(isHovering ? FP.border : .clear, lineWidth: 1)
                )

                // Title
                Text(file.baseName ?? file.filename)
                    .font(FP.captionFont)
                    .foregroundStyle(FP.textPrimary)
                    .lineLimit(1)

                // Metadata
                if let duration = file.durationSeconds {
                    Text(formatDuration(duration))
                        .font(.system(size: 11))
                        .foregroundStyle(FP.textSecondary)
                }
            }
            .frame(width: FP.cardWidth)
        }
        .buttonStyle(.plain)
        .onHover { isHovering = $0 }
        .scaleEffect(isHovering ? 1.03 : 1.0)
        .animation(.easeOut(duration: 0.15), value: isHovering)
        .task { loadImage() }
    }

    @ViewBuilder
    private var thumbnailView: some View {
        if let image = cachedImage {
            Image(nsImage: image)
                .resizable()
                .aspectRatio(contentMode: .fill)
        } else {
            RoundedRectangle(cornerRadius: FP.cardRadius)
                .fill(FP.surface)
                .overlay {
                    Image(systemName: "film")
                        .font(.largeTitle)
                        .foregroundStyle(FP.textSecondary.opacity(0.3))
                }
        }
    }

    private func loadImage() {
        guard cachedImage == nil,
              let thumbPath = file.thumbnailPath else { return }
        cachedImage = NSImage(contentsOfFile: thumbPath)
    }

    private func formatDuration(_ seconds: Double) -> String {
        let total = Int(seconds)
        let h = total / 3600
        let m = (total % 3600) / 60
        if h > 0 { return "\(h)h \(m)m" }
        return "\(m)m"
    }
}
