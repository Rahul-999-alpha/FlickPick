import Foundation

/// Tier 1: Regex-based sequence detection from filenames.
enum PatternMatcher {

    /// Attempt to extract base name and sequence info from a filename.
    static func analyze(_ filename: String) -> AnalysisResult? {
        let tokenized = FilenameTokenizer.tokenize(filename)
        let year = FilenameTokenizer.extractYear(tokenized)

        // Try each pattern in priority order
        if let result = matchSxxExx(tokenized, original: filename, year: year) { return result }
        if let result = matchSeasonEpisode(tokenized, original: filename, year: year) { return result }
        if let result = matchEpisode(tokenized, original: filename, year: year) { return result }
        if let result = matchPart(tokenized, original: filename, year: year) { return result }
        if let result = matchVolume(tokenized, original: filename, year: year) { return result }
        if let result = matchTrailingNumber(tokenized, original: filename, year: year) { return result }

        return nil
    }

    // MARK: - Pattern: S01E03

    private static func matchSxxExx(_ tokenized: String, original: String, year: Int?) -> AnalysisResult? {
        let pattern = "(.+?)\\s*[Ss](\\d{1,2})[Ee](\\d{1,3})"
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: tokenized, range: NSRange(tokenized.startIndex..., in: tokenized)) else {
            return nil
        }

        let base = extractGroup(match, group: 1, in: tokenized)
        let season = Int(extractGroup(match, group: 2, in: tokenized)) ?? 0
        let episode = Int(extractGroup(match, group: 3, in: tokenized)) ?? 0
        let seq = Double(season * 1000 + episode)

        return AnalysisResult(
            originalFilename: original,
            baseName: cleanBaseName(base),
            sequenceNumber: seq,
            season: season,
            episode: episode,
            mediaType: .episode,
            year: year
        )
    }

    // MARK: - Pattern: Season 1 Episode 3

    private static func matchSeasonEpisode(_ tokenized: String, original: String, year: Int?) -> AnalysisResult? {
        let pattern = "(.+?)\\s*[Ss]eason\\s*(\\d+).*?[Ee]pisode\\s*(\\d+)"
        guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
              let match = regex.firstMatch(in: tokenized, range: NSRange(tokenized.startIndex..., in: tokenized)) else {
            return nil
        }

        let base = extractGroup(match, group: 1, in: tokenized)
        let season = Int(extractGroup(match, group: 2, in: tokenized)) ?? 0
        let episode = Int(extractGroup(match, group: 3, in: tokenized)) ?? 0
        let seq = Double(season * 1000 + episode)

        return AnalysisResult(
            originalFilename: original,
            baseName: cleanBaseName(base),
            sequenceNumber: seq,
            season: season,
            episode: episode,
            mediaType: .episode,
            year: year
        )
    }

    // MARK: - Pattern: Episode 45 / Ep 45 / Ep45

    private static func matchEpisode(_ tokenized: String, original: String, year: Int?) -> AnalysisResult? {
        let pattern = "(.+?)\\s*[Ee]p(?:isode)?\\s*(\\d+)"
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: tokenized, range: NSRange(tokenized.startIndex..., in: tokenized)) else {
            return nil
        }

        let base = extractGroup(match, group: 1, in: tokenized)
        let episode = Int(extractGroup(match, group: 2, in: tokenized)) ?? 0

        return AnalysisResult(
            originalFilename: original,
            baseName: cleanBaseName(base),
            sequenceNumber: Double(episode),
            season: nil,
            episode: episode,
            mediaType: .episode,
            year: year
        )
    }

    // MARK: - Pattern: Part 2

    private static func matchPart(_ tokenized: String, original: String, year: Int?) -> AnalysisResult? {
        let pattern = "(.+?)\\s*[Pp]art\\s*(\\d+)"
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: tokenized, range: NSRange(tokenized.startIndex..., in: tokenized)) else {
            return nil
        }

        let base = extractGroup(match, group: 1, in: tokenized)
        let seq = Int(extractGroup(match, group: 2, in: tokenized)) ?? 0

        return AnalysisResult(
            originalFilename: original,
            baseName: cleanBaseName(base),
            sequenceNumber: Double(seq),
            season: nil,
            episode: nil,
            mediaType: .movie,
            year: year
        )
    }

    // MARK: - Pattern: Vol 1 / Volume 1

    private static func matchVolume(_ tokenized: String, original: String, year: Int?) -> AnalysisResult? {
        let pattern = "(.+?)\\s*[Vv]ol(?:ume)?\\s*(\\d+)"
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: tokenized, range: NSRange(tokenized.startIndex..., in: tokenized)) else {
            return nil
        }

        let base = extractGroup(match, group: 1, in: tokenized)
        let seq = Int(extractGroup(match, group: 2, in: tokenized)) ?? 0

        return AnalysisResult(
            originalFilename: original,
            baseName: cleanBaseName(base),
            sequenceNumber: Double(seq),
            season: nil,
            episode: nil,
            mediaType: .movie,
            year: year
        )
    }

    // MARK: - Pattern: trailing number (Harry Potter 2 Chamber...)

    private static func matchTrailingNumber(_ tokenized: String, original: String, year: Int?) -> AnalysisResult? {
        // Match: "Title 2 ..." where 2 is a sequence number (not a year)
        let pattern = "^(.+?)\\s+(\\d{1,2})\\s+(.+)$"
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: tokenized, range: NSRange(tokenized.startIndex..., in: tokenized)) else {
            return nil
        }

        let base = extractGroup(match, group: 1, in: tokenized)
        let numStr = extractGroup(match, group: 2, in: tokenized)
        guard let num = Int(numStr), num < 100 else { return nil }

        // Don't match if the number looks like a year
        if num >= 1900 && num <= 2099 { return nil }

        return AnalysisResult(
            originalFilename: original,
            baseName: cleanBaseName(base),
            sequenceNumber: Double(num),
            season: nil,
            episode: nil,
            mediaType: .movie,
            year: year
        )
    }

    // MARK: - Helpers

    private static func extractGroup(_ match: NSTextCheckingResult, group: Int, in string: String) -> String {
        guard let range = Range(match.range(at: group), in: string) else { return "" }
        return String(string[range]).trimmingCharacters(in: .whitespaces)
    }

    private static func cleanBaseName(_ raw: String) -> String {
        var name = FilenameTokenizer.stripTechnicalTags(raw)
        // Capitalize words for display
        name = name.split(separator: " ")
            .map { $0.prefix(1).uppercased() + $0.dropFirst() }
            .joined(separator: " ")
        return name.trimmingCharacters(in: .whitespaces)
    }
}
