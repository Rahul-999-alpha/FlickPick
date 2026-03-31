import SwiftUI

/// Settings panel for managing watched folders and preferences.
struct SettingsView: View {
    @StateObject private var viewModel = SettingsViewModel()
    @ObservedObject var library: LibraryManager

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Settings")
                .font(.largeTitle.weight(.bold))
                .padding(.horizontal, 24)
                .padding(.top, 16)

            // Watched Folders
            GroupBox {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("Watched Folders")
                            .font(.headline)
                        Spacer()
                        Button(action: viewModel.addFolder) {
                            Label("Add Folder", systemImage: "plus")
                        }
                    }

                    if viewModel.watchedFolders.isEmpty {
                        Text("No folders added yet. Add a folder to start scanning for media.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .padding(.vertical, 8)
                    } else {
                        ForEach(viewModel.watchedFolders, id: \.path) { folder in
                            HStack {
                                Image(systemName: "folder.fill")
                                    .foregroundStyle(.secondary)
                                VStack(alignment: .leading) {
                                    Text(folder.path)
                                        .font(.system(.body, design: .monospaced))
                                        .lineLimit(1)
                                    Text("Last scanned: \(folder.lastScannedAt.formatted())")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                Button(role: .destructive) {
                                    viewModel.removeFolder(folder.path)
                                } label: {
                                    Image(systemName: "trash")
                                }
                                .buttonStyle(.plain)
                                .foregroundStyle(.red)
                            }
                            .padding(.vertical, 4)
                            Divider()
                        }
                    }
                }
                .padding(12)
            }
            .padding(.horizontal, 24)

            // Actions
            GroupBox {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Library")
                        .font(.headline)

                    HStack {
                        Button("Rescan All Folders") {
                            viewModel.rescanAll()
                        }

                        if library.isScanning {
                            ProgressView()
                                .scaleEffect(0.7)
                            Text("Scanning...")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .padding(12)
            }
            .padding(.horizontal, 24)

            Spacer()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(white: 0.04))
    }
}
