import Foundation

/// Convenience facade over WatchRepository for common operations.
struct WatchHistory {
    private let repo = WatchRepository()
    private let mediaRepo = MediaFileRepository()

    func savePosition(path: String, position: Double) {
        guard let file = try? mediaRepo.fetchByPath(path),
              let fileId = file.id else { return }
        try? repo.savePosition(mediaFileId: fileId, position: position)
    }

    func getPosition(path: String) -> Double {
        guard let file = try? mediaRepo.fetchByPath(path),
              let fileId = file.id else { return 0 }
        return (try? repo.getPosition(mediaFileId: fileId)) ?? 0
    }

    func markCompleted(path: String) {
        guard let file = try? mediaRepo.fetchByPath(path),
              let fileId = file.id else { return }
        try? repo.markCompleted(mediaFileId: fileId)
    }

    func isCompleted(path: String) -> Bool {
        guard let file = try? mediaRepo.fetchByPath(path),
              let fileId = file.id else { return false }
        return (try? repo.isCompleted(mediaFileId: fileId)) ?? false
    }

    func progress(path: String) -> Double {
        guard let file = try? mediaRepo.fetchByPath(path),
              let fileId = file.id,
              let pos = try? repo.getPosition(mediaFileId: fileId),
              let dur = file.durationSeconds,
              dur > 0 else { return 0 }
        return pos / dur
    }
}
