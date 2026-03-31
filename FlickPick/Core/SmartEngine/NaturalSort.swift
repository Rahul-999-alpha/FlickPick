import Foundation

/// Human-friendly sorting: Episode 2 before Episode 10.
enum NaturalSort {

    /// Sort strings using macOS's built-in numeric-aware comparison.
    static func sorted(_ strings: [String]) -> [String] {
        strings.sorted { $0.localizedStandardCompare($1) == .orderedAscending }
    }

    /// Sort AnalysisResults by sequence number, falling back to natural filename sort.
    static func sortResults(_ results: [AnalysisResult]) -> [AnalysisResult] {
        results.sorted { a, b in
            if let seqA = a.sequenceNumber, let seqB = b.sequenceNumber {
                return seqA < seqB
            }
            // Fall back to natural filename sort
            return a.originalFilename.localizedStandardCompare(b.originalFilename) == .orderedAscending
        }
    }

    /// Sort URLs by their filename using natural sort.
    static func sortURLs(_ urls: [URL]) -> [URL] {
        urls.sorted {
            $0.lastPathComponent.localizedStandardCompare($1.lastPathComponent) == .orderedAscending
        }
    }
}
