import Foundation

/// Tier 2: Groups files by longest common prefix when no explicit sequence markers are found.
enum FuzzyGrouper {

    struct FileGroup {
        let baseName: String
        let files: [URL]
    }

    /// Group sibling files by shared prefix. Files sharing >50% of their name
    /// length are considered part of the same group.
    /// Capped at 500 files to prevent O(n^2) freeze on large folders.
    static func group(_ urls: [URL]) -> [FileGroup] {
        guard urls.count > 1, urls.count < 500 else { return [] }

        let tokenized = urls.map { (url: $0, name: FilenameTokenizer.tokenize($0.lastPathComponent)) }
        var assigned = Set<URL>()
        var groups: [FileGroup] = []

        for i in 0..<tokenized.count {
            guard !assigned.contains(tokenized[i].url) else { continue }

            var members: [(url: URL, name: String)] = [tokenized[i]]

            for j in (i + 1)..<tokenized.count {
                guard !assigned.contains(tokenized[j].url) else { continue }

                let prefix = longestCommonPrefix(tokenized[i].name, tokenized[j].name)
                let minLen = min(tokenized[i].name.count, tokenized[j].name.count)

                // >50% overlap threshold
                if minLen > 0 && prefix.count > minLen / 2 && prefix.count >= 3 {
                    members.append(tokenized[j])
                }
            }

            if members.count > 1 {
                let prefix = members.reduce(members[0].name) { longestCommonPrefix($0, $1.name) }
                let baseName = cleanGroupName(prefix)
                let sortedURLs = NaturalSort.sortURLs(members.map(\.url))
                groups.append(FileGroup(baseName: baseName, files: sortedURLs))
                members.forEach { assigned.insert($0.url) }
            }
        }

        return groups
    }

    // MARK: - Helpers

    private static func longestCommonPrefix(_ a: String, _ b: String) -> String {
        let aLower = a.lowercased()
        let bLower = b.lowercased()
        var prefix = ""
        for (ca, cb) in zip(aLower, bLower) {
            if ca == cb {
                prefix.append(ca)
            } else {
                break
            }
        }
        // Trim trailing spaces and separators
        return prefix.trimmingCharacters(in: .whitespaces)
    }

    private static func cleanGroupName(_ prefix: String) -> String {
        var name = prefix.trimmingCharacters(in: .whitespaces)
        // Remove trailing numbers, dashes, colons
        name = name.replacingOccurrences(
            of: "[\\s\\-:]+$",
            with: "",
            options: .regularExpression
        )
        // Capitalize
        name = name.split(separator: " ")
            .map { $0.prefix(1).uppercased() + $0.dropFirst() }
            .joined(separator: " ")
        return name
    }
}
