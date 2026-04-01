import SwiftUI
import GRDB

/// Cmd+K fuzzy search overlay with debounce.
struct CommandPalette: View {
    @Binding var isPresented: Bool
    @State private var query = ""
    @State private var results: [MediaFileRecord] = []
    @State private var searchTask: Task<Void, Never>?

    var onSelect: (MediaFileRecord) -> Void

    private let mediaRepo = MediaFileRepository()

    var body: some View {
        VStack(spacing: 0) {
            // Search field
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                TextField("Search your library...", text: $query)
                    .textFieldStyle(.plain)
                    .font(.title3)
                    .onSubmit {
                        if let first = results.first {
                            onSelect(first)
                            isPresented = false
                        }
                    }

                if !query.isEmpty {
                    Button {
                        query = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(16)

            Divider()

            // Results
            if results.isEmpty && !query.isEmpty {
                Text("No results")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding(20)
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 0) {
                        ForEach(results.prefix(20), id: \.path) { file in
                            Button {
                                onSelect(file)
                                isPresented = false
                            } label: {
                                HStack {
                                    Image(systemName: "film")
                                        .foregroundStyle(.secondary)
                                    VStack(alignment: .leading) {
                                        Text(file.baseName ?? file.filename)
                                            .font(.body)
                                        Text(file.folderPath)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                            .lineLimit(1)
                                    }
                                    Spacer()
                                }
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            Divider().padding(.leading, 48)
                        }
                    }
                }
                .frame(maxHeight: 300)
            }
        }
        .frame(width: 500)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
        .shadow(radius: 20)
        .onChange(of: query) { _, newValue in
            // Debounce: cancel previous search, wait 200ms
            searchTask?.cancel()
            searchTask = Task {
                try? await Task.sleep(for: .milliseconds(200))
                guard !Task.isCancelled else { return }
                search(newValue)
            }
        }
        .onKeyPress(.escape) {
            isPresented = false
            return .handled
        }
    }

    private func search(_ term: String) {
        guard !term.isEmpty else {
            results = []
            return
        }
        do {
            let pattern = "%\(term)%"
            results = try mediaRepo.db.read { db in
                let sql = """
                    SELECT * FROM media_files
                    WHERE baseName LIKE ? OR filename LIKE ?
                    LIMIT 20
                """
                return try MediaFileRecord.fetchAll(db, sql: sql, arguments: [pattern, pattern])
            }
        } catch {
            results = []
        }
    }
}
