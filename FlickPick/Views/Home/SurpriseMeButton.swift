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
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(FP.textPrimary)
                    Text("Pick something random")
                        .font(.system(size: 11))
                        .foregroundStyle(FP.textSecondary)
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
            .background(FP.accentGlow, in: RoundedRectangle(cornerRadius: FP.cardRadius))
            .overlay(
                RoundedRectangle(cornerRadius: FP.cardRadius)
                    .strokeBorder(FP.accent.opacity(0.3), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .onHover { isHovering = $0 }
    }
}
