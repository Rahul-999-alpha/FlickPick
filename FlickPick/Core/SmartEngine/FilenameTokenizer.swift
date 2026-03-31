import Foundation

/// Normalizes filenames for pattern matching.
enum FilenameTokenizer {

    /// Supported video extensions.
    static let videoExtensions: Set<String> = [
        "mp4", "mkv", "avi", "mov", "wmv", "flv", "webm", "m4v",
        "mpg", "mpeg", "ts", "m2ts", "vob", "3gp", "ogv"
    ]

    /// Strip extension, replace separators with spaces, trim.
    static func tokenize(_ filename: String) -> String {
        var name = filename

        // Strip extension
        let ext = (name as NSString).pathExtension.lowercased()
        if videoExtensions.contains(ext) {
            name = (name as NSString).deletingPathExtension
        }

        // Replace common separators with space
        name = name.replacingOccurrences(of: ".", with: " ")
        name = name.replacingOccurrences(of: "_", with: " ")
        name = name.replacingOccurrences(of: " - ", with: " ")

        // Strip content inside brackets like [720p] or (2002)
        name = name.replacingOccurrences(
            of: "\\[.*?\\]",
            with: "",
            options: .regularExpression
        )

        // Collapse whitespace
        name = name.replacingOccurrences(
            of: "\\s+",
            with: " ",
            options: .regularExpression
        ).trimmingCharacters(in: .whitespaces)

        return name
    }

    /// Check if a file extension is a supported video type.
    static func isVideoFile(_ path: String) -> Bool {
        let ext = (path as NSString).pathExtension.lowercased()
        return videoExtensions.contains(ext)
    }

    /// Extract a year (1900-2099) from a tokenized name if present.
    static func extractYear(_ tokenized: String) -> Int? {
        let regex = try? NSRegularExpression(pattern: "\\b(19\\d{2}|20\\d{2})\\b")
        let range = NSRange(tokenized.startIndex..., in: tokenized)
        guard let match = regex?.firstMatch(in: tokenized, range: range),
              let yearRange = Range(match.range(at: 1), in: tokenized) else {
            return nil
        }
        return Int(tokenized[yearRange])
    }

    /// Strip quality tags, codecs, and source info from tokenized name.
    static func stripTechnicalTags(_ tokenized: String) -> String {
        let tags = [
            "1080p", "720p", "480p", "2160p", "4k", "uhd",
            "bluray", "bdrip", "brrip", "webrip", "web dl", "webdl",
            "hdtv", "dvdrip", "hdrip", "remux",
            "x264", "x265", "h264", "h265", "hevc", "avc",
            "aac", "ac3", "dts", "atmos", "truehd",
            "extended", "directors cut", "unrated", "remastered",
            "proper", "repack"
        ]
        var result = tokenized.lowercased()
        for tag in tags {
            result = result.replacingOccurrences(of: tag, with: "")
        }
        result = result.replacingOccurrences(
            of: "\\s+", with: " ", options: .regularExpression
        ).trimmingCharacters(in: .whitespaces)
        return result
    }
}
