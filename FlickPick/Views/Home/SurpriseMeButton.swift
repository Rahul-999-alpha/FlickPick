import SwiftUI

/// Random unwatched picker button.
struct SurpriseMeButton: View {
    var onPick: () -> Void

    @State private var isHovering = false

    var body: some View {
        Button(action: onPick) {
            HStack(spacing: 10) {
                Image(systemName: "dice.fill")
                    .font(.title2)
                    .symbolEffect(.bounce, value: isHovering)

                VStack(alignment: .leading) {
                    Text("Surprise Me")
                        .font(.headline)
                    Text("Pick something random")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
            .background(Color.accentColor.opacity(0.15), in: RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(Color.accentColor.opacity(0.3), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .onHover { isHovering = $0 }
    }
}
