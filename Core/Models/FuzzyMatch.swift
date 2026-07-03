import Foundation

/// Case-insensitive subsequence matcher with palette-style ranking:
/// exact prefix > word-boundary start > contiguous substring > scattered.
enum FuzzyMatch {
    /// Characters that start a new "word" in a candidate for boundary bonuses.
    private static let boundaries: Set<Character> = [" ", "-", "_", "/", ".", ":"]

    /// Scores `query` against `candidate`; `nil` when the query is not a
    /// subsequence. Empty queries match everything with a score of 0.
    /// Matching is greedy left-to-right — cheap and good enough for a palette.
    static func score(_ query: String, in candidate: String) -> Int? {
        guard !query.isEmpty else { return 0 }
        let query = Array(query.lowercased())
        let original = Array(candidate)
        let lowered = Array(candidate.lowercased())
        guard lowered.count == original.count else {
            // Locale edge case where lowercasing changes length; fall back to
            // a plain containment check.
            return candidate.lowercased().contains(String(query)) ? 1 : nil
        }

        var score = 0
        var queryIndex = 0
        var previousMatch: Int? = nil
        for index in lowered.indices where queryIndex < query.count {
            guard lowered[index] == query[queryIndex] else { continue }
            if index == 0 {
                score += 100
            } else if boundaries.contains(lowered[index - 1]) {
                score += 30
            } else if original[index].isUppercase && original[index - 1].isLowercase {
                score += 30  // camelCase boundary
            }
            if let previous = previousMatch {
                if index == previous + 1 {
                    score += 20  // contiguous run
                } else {
                    score -= min(15, index - previous - 1)  // scattered-gap penalty
                }
            } else {
                score -= min(15, index)  // unmatched-prefix penalty
            }
            previousMatch = index
            queryIndex += 1
        }
        return queryIndex == query.count ? score : nil
    }
}
