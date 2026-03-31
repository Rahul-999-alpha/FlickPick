import Foundation

/// Builds playlists and collections from a target file and its sibling files.
enum CollectionBuilder {

    struct PlaylistResult {
        let baseName: String
        let files: [URL]
        let currentIndex: Int
        let mediaType: MediaType
    }

    /// Given a target file, scan its parent folder and build a smart playlist.
    /// Returns nil if the file is standalone (no related files found).
    static func buildPlaylist(for targetURL: URL) -> PlaylistResult? {
        let folder = targetURL.deletingLastPathComponent()
        let siblings = scanFolder(folder)

        guard siblings.count > 1 else { return nil }

        // Tier 1: Try pattern matching on all siblings
        if let result = buildFromPatterns(target: targetURL, siblings: siblings) {
            return result
        }

        // Tier 2: Try fuzzy grouping
        if let result = buildFromFuzzyGroup(target: targetURL, siblings: siblings) {
            return result
        }

        return nil
    }

    /// Scan a folder for video files (non-recursive).
    static func scanFolder(_ folder: URL) -> [URL] {
        guard let enumerator = FileManager.default.enumerator(
            at: folder,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles, .skipsSubdirectoryDescendants]
        ) else { return [] }

        var videos: [URL] = []
        for case let url as URL in enumerator {
            if FilenameTokenizer.isVideoFile(url.path) {
                videos.append(url)
            }
        }
        return videos
    }

    // MARK: - Tier 1: Pattern-based playlist

    private static func buildFromPatterns(target: URL, siblings: [URL]) -> PlaylistResult? {
        // Analyze target
        guard let targetResult = PatternMatcher.analyze(target.lastPathComponent) else {
            return nil
        }

        // Find all siblings that share the same base name
        var matchedFiles: [(url: URL, result: AnalysisResult)] = []
        for sibling in siblings {
            if let result = PatternMatcher.analyze(sibling.lastPathComponent) {
                if result.baseName.lowercased() == targetResult.baseName.lowercased() {
                    matchedFiles.append((url: sibling, result: result))
                }
            }
        }

        guard matchedFiles.count > 1 else { return nil }

        // Sort by sequence number
        let sorted = matchedFiles.sorted { a, b in
            let seqA = a.result.sequenceNumber ?? 0
            let seqB = b.result.sequenceNumber ?? 0
            return seqA < seqB
        }

        let files = sorted.map(\.url)
        let currentIndex = files.firstIndex(of: target) ?? 0

        return PlaylistResult(
            baseName: targetResult.baseName,
            files: files,
            currentIndex: currentIndex,
            mediaType: targetResult.mediaType
        )
    }

    // MARK: - Tier 2: Fuzzy grouping

    private static func buildFromFuzzyGroup(target: URL, siblings: [URL]) -> PlaylistResult? {
        let groups = FuzzyGrouper.group(siblings)

        for group in groups {
            if group.files.contains(target) {
                let currentIndex = group.files.firstIndex(of: target) ?? 0
                return PlaylistResult(
                    baseName: group.baseName,
                    files: group.files,
                    currentIndex: currentIndex,
                    mediaType: .movie
                )
            }
        }

        return nil
    }
}
