import Foundation

/// Manages resume positions — save every 5s, restore on open.
@MainActor
final class ResumeManager {
    private let watchRepo = WatchRepository()
    private let mediaRepo = MediaFileRepository()
    private var saveTimer: Timer?
    private var currentMediaId: Int64?

    /// Start tracking position for a file.
    func startTracking(path: String, getCurrentTime: @escaping () -> Double) {
        stopTracking()

        guard let file = try? mediaRepo.fetchByPath(path) else { return }
        currentMediaId = file.id

        // Save position every 5 seconds
        saveTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] _ in
            guard let self, let mediaId = self.currentMediaId else { return }
            let time = getCurrentTime()
            guard time > 0 else { return }
            try? self.watchRepo.savePosition(mediaFileId: mediaId, position: time)
        }
    }

    func stopTracking() {
        saveTimer?.invalidate()
        saveTimer = nil
        currentMediaId = nil
    }

    /// Get the saved resume position for a file.
    func getResumePosition(path: String) -> Double? {
        guard let file = try? mediaRepo.fetchByPath(path) else { return nil }
        guard let fileId = file.id else { return nil }
        return try? watchRepo.getPosition(mediaFileId: fileId)
    }

    /// Mark a file as completed (position > 90% of duration).
    func checkAndMarkCompleted(path: String, position: Double, duration: Double) {
        guard duration > 0, position / duration > 0.9 else { return }
        guard let file = try? mediaRepo.fetchByPath(path),
              let fileId = file.id else { return }
        try? watchRepo.markCompleted(mediaFileId: fileId)
    }

    deinit {
        saveTimer?.invalidate()
    }
}
