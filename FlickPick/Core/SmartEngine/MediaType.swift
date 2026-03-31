import Foundation

/// Classification of a media file based on filename analysis.
enum MediaType: String, Codable {
    case episode    // Part of a series (S01E03, Episode 5, etc.)
    case movie      // Standalone film, possibly part of a franchise (HP 2, Dune Part 1)
    case standalone // No sequence detected — solo file
}

/// Result of analyzing a single filename.
struct AnalysisResult {
    let originalFilename: String
    let baseName: String
    let sequenceNumber: Double?
    let season: Int?
    let episode: Int?
    let mediaType: MediaType
    let year: Int?
}
