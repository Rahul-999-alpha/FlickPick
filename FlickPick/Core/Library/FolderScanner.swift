import Foundation

/// Walks a folder tree and finds all video files.
enum FolderScanner {

    /// Recursively scan a folder for video files.
    static func scan(_ folder: URL) -> [URL] {
        guard let enumerator = FileManager.default.enumerator(
            at: folder,
            includingPropertiesForKeys: [.isRegularFileKey, .fileSizeKey, .creationDateKey],
            options: [.skipsHiddenFiles]
        ) else { return [] }

        var videos: [URL] = []
        for case let url as URL in enumerator {
            if FilenameTokenizer.isVideoFile(url.path) {
                videos.append(url)
            }
        }
        return videos
    }

    /// Index a batch of video files: analyze, create records, build collections.
    static func indexFiles(_ urls: [URL]) throws {
        let mediaRepo = MediaFileRepository()
        let collectionRepo = CollectionRepository()

        // Group by folder for collection detection
        let byFolder = Dictionary(grouping: urls) { $0.deletingLastPathComponent() }

        for (_, folderURLs) in byFolder {
            var records: [MediaFileRecord] = []

            for url in folderURLs {
                let analysis = PatternMatcher.analyze(url.lastPathComponent)
                let record = MediaFileRecord.from(url: url, analysis: analysis)
                records.append(record)
            }

            try mediaRepo.upsertBatch(records)

            // Build collections from pattern matches
            let analyzed = folderURLs.compactMap { url -> (URL, AnalysisResult)? in
                guard let result = PatternMatcher.analyze(url.lastPathComponent) else { return nil }
                return (url, result)
            }

            // Group by base name
            let groups = Dictionary(grouping: analyzed) { $0.1.baseName.lowercased() }
            for (_, group) in groups where group.count > 1 {
                let first = group[0].1
                let type = first.mediaType == .episode ? "series" : "franchise"
                let collection = try collectionRepo.findOrCreate(name: first.baseName, type: type)

                guard let collectionId = collection.id else { continue }
                for (url, _) in group {
                    if let file = try mediaRepo.fetchByPath(url.path) {
                        try mediaRepo.setCollection(fileId: file.id!, collectionId: collectionId)
                    }
                }
                try collectionRepo.updateCounts(id: collectionId)
            }
        }
    }
}
