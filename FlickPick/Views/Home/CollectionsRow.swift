import SwiftUI

/// Row showing detected collections (franchises/series).
struct CollectionsRow: View {
    let collections: [CollectionRecord]
    var onSelect: (CollectionRecord) -> Void

    var body: some View {
        if !collections.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                Text("Collections")
                    .font(.title2.weight(.semibold))
                    .padding(.horizontal, 24)

                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHStack(spacing: 16) {
                        ForEach(collections, id: \.id) { collection in
                            CollectionCard(collection: collection) {
                                onSelect(collection)
                            }
                        }
                    }
                    .padding(.horizontal, 24)
                }
            }
        }
    }
}

/// A single collection card.
struct CollectionCard: View {
    let collection: CollectionRecord
    var onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 6) {
                // Thumbnail placeholder with stacked effect
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color(white: 0.15))
                        .frame(width: 200, height: 112)
                        .offset(x: 4, y: -4)
                        .opacity(0.5)

                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color(white: 0.12))
                        .frame(width: 200, height: 112)
                        .overlay {
                            VStack {
                                Image(systemName: "rectangle.stack.fill")
                                    .font(.title)
                                    .foregroundStyle(.quaternary)
                                Text("\(collection.totalItems) items")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                        }
                }

                Text(collection.name)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.primary)
                    .lineLimit(1)

                Text("\(collection.watchedItems)/\(collection.totalItems) watched")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .frame(width: 200)
        }
        .buttonStyle(.plain)
    }
}
