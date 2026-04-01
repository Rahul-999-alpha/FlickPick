import SwiftUI

/// Settings panel for managing watched folders and preferences.
struct SettingsView: View {
    @StateObject private var viewModel = SettingsViewModel()
    @ObservedObject var library: LibraryManager

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("Settings")
                    .font(FP.titleFont)
                    .foregroundStyle(FP.textPrimary)
                    .padding(.horizontal, FP.sectionPadding)
                    .padding(.top, 20)

                // Watched Folders
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("Watched Folders")
                            .font(FP.subtitleFont)
                            .foregroundStyle(FP.textPrimary)
                        Spacer()
                        Button(action: viewModel.addFolder) {
                            Label("Add Folder", systemImage: "plus")
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(FP.accent)
                        .controlSize(.small)
                    }

                    if viewModel.watchedFolders.isEmpty {
                        Text("No folders added yet. Add a folder to start scanning for media.")
                            .font(FP.bodyFont)
                            .foregroundStyle(FP.textSecondary)
                            .padding(.vertical, 12)
                    } else {
                        ForEach(viewModel.watchedFolders, id: \.path) { folder in
                            HStack {
                                Image(systemName: "folder.fill")
                                    .foregroundStyle(FP.textSecondary)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(folder.path)
                                        .font(.system(size: 13, design: .monospaced))
                                        .foregroundStyle(FP.textPrimary)
                                        .lineLimit(1)
                                    Text("Last scanned: \(folder.lastScannedAt.formatted())")
                                        .font(.system(size: 11))
                                        .foregroundStyle(FP.textSecondary)
                                }
                                Spacer()
                                Button(role: .destructive) {
                                    viewModel.removeFolder(folder.path)
                                } label: {
                                    Image(systemName: "trash")
                                        .font(.system(size: 13))
                                }
                                .buttonStyle(.plain)
                                .foregroundStyle(.red.opacity(0.8))
                            }
                            .padding(.vertical, 6)
                            .padding(.horizontal, 12)
                            .background(FP.surface, in: RoundedRectangle(cornerRadius: 8))
                        }
                    }
                }
                .padding(.horizontal, FP.sectionPadding)

                // Actions
                VStack(alignment: .leading, spacing: 12) {
                    Text("Library")
                        .font(FP.subtitleFont)
                        .foregroundStyle(FP.textPrimary)

                    HStack(spacing: 12) {
                        Button("Rescan All Folders") {
                            viewModel.rescanAll()
                        }
                        .buttonStyle(.bordered)

                        if library.isScanning {
                            ProgressView()
                                .scaleEffect(0.7)
                            Text("Scanning...")
                                .font(FP.captionFont)
                                .foregroundStyle(FP.textSecondary)
                        }
                    }
                }
                .padding(.horizontal, FP.sectionPadding)

                Spacer()
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(FP.background)
    }
}
