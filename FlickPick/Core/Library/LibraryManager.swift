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
    private var activeScanCount = 0

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

            // Remove indexed files — use exact prefix with path separator to avoid matching siblings
            let pathPrefix = path.hasSuffix("/") ? path : path + "/"
            try watchedFolderDB.write { db in
                _ = try MediaFileRecord
                    .filter(MediaFileRecord.Columns.folderPath == path ||
                            MediaFileRecord.Columns.folderPath.like("\(pathPrefix)%"))
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
            await scanFolder(folder.path, updateSpinner: false)
        }
        isScanning = false
    }

    func scanFolder(_ path: String, updateSpinner: Bool = true) async {
        if updateSpinner { isScanning = true }
        activeScanCount += 1

        let url = URL(fileURLWithPath: path)
        let videos = FolderScanner.scan(url)

        do {
            try FolderScanner.indexFiles(videos)

            // Generate thumbnails with bounded concurrency
            await withTaskGroup(of: Void.self) { group in
                var launched = 0
                for video in videos {
                    if launched >= 8 { await group.next() }
                    group.addTask {
                        let thumbPath = await ThumbnailGenerator.shared.generate(for: video)
                        if let thumbPath, let file = try? MediaFileRepository().fetchByPath(video.path),
                           let fileId = file.id {
                            try? MediaFileRepository().updateThumbnail(id: fileId, path: thumbPath)
                        }
                    }
                    launched += 1
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

        activeScanCount -= 1
        if updateSpinner && activeScanCount <= 0 {
            isScanning = false
            activeScanCount = 0
        }
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
                let urls = videoChanges.map { URL(fileURLWithPath: $0) }
                do { try FolderScanner.indexFiles(urls) }
                catch { print("[FlickPick] Re-index failed: \(error)") }
            }
        }
        startFileWatching()
    }

    private func startFileWatching() {
        let paths = watchedFolders.map(\.path)
        fileWatcher.watch(paths: paths)
    }
}
