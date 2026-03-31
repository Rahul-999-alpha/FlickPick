import Foundation

/// Determines "what should I watch next?" based on watch history + SmartEngine.
struct OnDeckEngine {
    private let watchRepo = WatchRepository()
    private let mediaRepo = MediaFileRepository()
    private let collectionRepo = CollectionRepository()

    /// Items currently in progress, sorted by most recent.
    func continueWatching() throws -> [(MediaFileRecord, WatchRecord)] {
        try watchRepo.fetchContinueWatching()
    }

    /// For each in-progress series, find the next unwatched episode.
    func upNext() throws -> [MediaFileRecord] {
        let inProgress = try watchRepo.fetchContinueWatching()
        var nextEpisodes: [MediaFileRecord] = []

        for (file, _) in inProgress {
            guard let collectionId = file.collectionId else { continue }

            // Get all files in this collection
            let collectionFiles = try mediaRepo.fetchByCollection(collectionId)

            // Find the current file's position in the collection
            guard let currentIdx = collectionFiles.firstIndex(where: { $0.path == file.path }) else { continue }

            // Find the next unwatched file
            for nextIdx in (currentIdx + 1)..<collectionFiles.count {
                let nextFile = collectionFiles[nextIdx]
                guard let nextId = nextFile.id else { continue }
                let completed = try watchRepo.isCompleted(mediaFileId: nextId)
                if !completed {
                    // Avoid duplicates
                    if !nextEpisodes.contains(where: { $0.path == nextFile.path }) {
                        nextEpisodes.append(nextFile)
                    }
                    break
                }
            }
        }

        return nextEpisodes
    }

    /// Random unwatched file.
    func surpriseMe() throws -> MediaFileRecord? {
        try mediaRepo.randomUnwatched()
    }
}
