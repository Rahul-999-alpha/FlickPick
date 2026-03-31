import Foundation
import Combine
import GRDB

/// Orchestrates scanning, watching, and indexing of media libraries.
@MainActor
final class LibraryManager: ObservableObject {
    static let shared = LibraryManager()

    @Published var isScanning = false
    @Published var watchedFolders: [WatchedFolderRecord] = []

    private let fileWatcher = FileWatcher()
    private let mediaRepo = MediaFileRepository()
    private let watchedFolderDB: DatabaseWriter

    private init() {
        watchedFolderDB = AppDatabase.shared.writer
        loadWatchedFolders()
        setupFileWatcher()
    }

    // MARK: - Folder management

    func addFolder(_ path: String) {
        do {
            try watchedFolderDB.write { db in
                var record = WatchedFolderRecord(
                    path: path,
                    lastScannedAt: Date()
                )
                try record.save(db)
            }
            loadWatchedFolders()
            startFileWatching()

            Task {
                await scanFolder(path)
            }
        } catch {
            print("[FlickPick] Failed to add folder: \(error)")
        }
    }

    func removeFolder(_ path: String) {
        do {
            try watchedFolderDB.write { db in
                _ = try WatchedFolderRecord
                    .filter(WatchedFolderRecord.Columns.path == path)
                    .deleteAll(db)
            }

            // Remove indexed files from this folder
            try watchedFolderDB.write { db in
                _ = try MediaFileRecord
                    .filter(MediaFileRecord.Columns.folderPath.like("\(path)%"))
                    .deleteAll(db)
            }

            loadWatchedFolders()
            startFileWatching()
        } catch {
            print("[FlickPick] Failed to remove folder: \(error)")
        }
    }

    // MARK: - Scanning

    func scanAllFolders() async {
        isScanning = true
        for folder in watchedFolders {
            await scanFolder(folder.path)
        }
        isScanning = false
    }

    func scanFolder(_ path: String) async {
        isScanning = true
        let url = URL(fileURLWithPath: path)
        let videos = FolderScanner.scan(url)

        do {
            try FolderScanner.indexFiles(videos)

            // Generate thumbnails in background
            for video in videos {
                Task.detached {
                    let thumbPath = await ThumbnailGenerator.shared.generate(for: video)
                    if let thumbPath, let file = try? MediaFileRepository().fetchByPath(video.path) {
                        try? MediaFileRepository().updateThumbnail(id: file.id!, path: thumbPath)
                    }
                }
            }

            // Update last scanned timestamp
            try await watchedFolderDB.write { db in
                try db.execute(
                    sql: "UPDATE watched_folders SET lastScannedAt = ? WHERE path = ?",
                    arguments: [Date(), path]
                )
            }
        } catch {
            print("[FlickPick] Scan failed for \(path): \(error)")
        }
        isScanning = false
    }

    // MARK: - Private

    private func loadWatchedFolders() {
        do {
            watchedFolders = try watchedFolderDB.read { db in
                try WatchedFolderRecord.fetchAll(db)
            }
        } catch {
            print("[FlickPick] Failed to load folders: \(error)")
        }
    }

    private func setupFileWatcher() {
        fileWatcher.onChange = { [weak self] changedPaths in
            guard let self else { return }
            let videoChanges = changedPaths.filter { FilenameTokenizer.isVideoFile($0) }
            guard !videoChanges.isEmpty else { return }

            Task { @MainActor in
                // Re-index changed files
                let urls = videoChanges.map { URL(fileURLWithPath: $0) }
                try? FolderScanner.indexFiles(urls)
            }
        }
        startFileWatching()
    }

    private func startFileWatching() {
        let paths = watchedFolders.map(\.path)
        fileWatcher.watch(paths: paths)
    }
}
