import Foundation
import Combine
import AppKit

/// Manages settings and watched folder list.
@MainActor
final class SettingsViewModel: ObservableObject {
    @Published var watchedFolders: [WatchedFolderRecord] = []

    private let library = LibraryManager.shared

    init() {
        loadFolders()
    }

    func addFolder() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.message = "Choose a folder containing your movies or TV shows"

        panel.begin { [weak self] response in
            guard response == .OK, let url = panel.url else { return }
            Task { @MainActor in
                self?.library.addFolder(url.path)
                self?.loadFolders()
            }
        }
    }

    func removeFolder(_ path: String) {
        library.removeFolder(path)
        loadFolders()
    }

    func rescanAll() {
        Task {
            await library.scanAllFolders()
        }
    }

    private func loadFolders() {
        watchedFolders = library.watchedFolders
    }
}
