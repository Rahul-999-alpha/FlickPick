import SwiftUI

/// Row showing detected collections (franchises/series).
struct CollectionsRow: View {
    let collections: [CollectionRecord]
    var onSelect: (CollectionRecord) -> Void

    var body: some View {
        if !collections.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                Text("Collections")
                    .font(FP.sectionFont)
                    .foregroundStyle(FP.textPrimary)
                    .padding(.horizontal, FP.sectionPadding)

                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHStack(spacing: FP.cardSpacing) {
                        ForEach(collections, id: \.id) { collection in
                            CollectionCard(collection: collection) {
                                onSelect(collection)
                            }
                        }
                    }
                    .padding(.horizontal, FP.sectionPadding)
                }
            }
        }
    }
}

/// A single collection card with stacked effect.
struct CollectionCard: View {
    let collection: CollectionRecord
    var onTap: () -> Void

    @State private var isHovering = false

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 6) {
                ZStack {
                    // Stacked background card
                    RoundedRectangle(cornerRadius: FP.cardRadius)
                        .fill(FP.surfaceHover)
                        .frame(width: 200, height: 112)
                        .offset(x: 4, y: -4)
                        .opacity(0.5)

                    // Main card
                    RoundedRectangle(cornerRadius: FP.cardRadius)
                        .fill(FP.surface)
                        .frame(width: 200, height: 112)
                        .overlay(
                            RoundedRectangle(cornerRadius: FP.cardRadius)
                                .strokeBorder(isHovering ? FP.border : .clear, lineWidth: 1)
                        )
                        .overlay {
                            VStack(spacing: 6) {
                                Image(systemName: "rectangle.stack.fill")
                                    .font(.title2)
                                    .foregroundStyle(FP.textSecondary.opacity(0.4))
                                Text("\(collection.totalItems) items")
                                    .font(.system(size: 11))
                                    .foregroundStyle(FP.textSecondary)
                            }
                        }
                }

                Text(collection.name)
                    .font(FP.captionFont.weight(.medium))
                    .foregroundStyle(FP.textPrimary)
                    .lineLimit(1)

                Text("\(collection.watchedItems)/\(collection.totalItems) watched")
                    .font(.system(size: 11))
                    .foregroundStyle(FP.textSecondary)
            }
            .frame(width: 200)
        }
        .buttonStyle(.plain)
        .onHover { isHovering = $0 }
        .scaleEffect(isHovering ? 1.03 : 1.0)
        .animation(.easeOut(duration: 0.15), value: isHovering)
    }
}
