import Foundation

public enum PolishedInputAnimation {
    public static let maximumFrameCount = 36

    public struct Frame: Equatable, Sendable {
        public var segments: [Segment]

        public init(segments: [Segment]) {
            self.segments = segments.filter { !$0.text.isEmpty }
        }

        public var plainText: String {
            segments.map(\.text).joined()
        }
    }

    public struct Segment: Equatable, Sendable {
        public enum Kind: Equatable, Sendable {
            case unchanged
            case removed
            case added
        }

        public var text: String
        public var kind: Kind

        public init(text: String, kind: Kind) {
            self.text = text
            self.kind = kind
        }
    }

    public static func frames(original: String, polished: String) -> [String] {
        highlightedFrames(original: original, polished: polished).map(\.plainText)
    }

    public static func highlightedFrames(original: String, polished: String) -> [Frame] {
        guard original != polished else { return [] }

        let originalCharacters = Array(original)
        let polishedCharacters = Array(polished)
        var sharedPrefixCount = commonPrefixCount(originalCharacters, polishedCharacters)
        var sharedSuffixCount = commonSuffixCount(
            originalCharacters,
            polishedCharacters,
            excludingPrefixCount: sharedPrefixCount
        )
        expandChangeRangeToWordBoundaries(
            originalCharacters: originalCharacters,
            polishedCharacters: polishedCharacters,
            prefixCount: &sharedPrefixCount,
            suffixCount: &sharedSuffixCount
        )

        let originalMiddleEnd = originalCharacters.count - sharedSuffixCount
        let polishedMiddleEnd = polishedCharacters.count - sharedSuffixCount
        let prefix = String(polishedCharacters.prefix(sharedPrefixCount))
        let suffix = sharedSuffixCount > 0 ? String(polishedCharacters.suffix(sharedSuffixCount)) : ""
        let originalMiddle = Array(originalCharacters[sharedPrefixCount..<originalMiddleEnd])
        let polishedMiddle = Array(polishedCharacters[sharedPrefixCount..<polishedMiddleEnd])

        var frames: [Frame] = []
        let transitionFrameBudget = max(1, maximumFrameCount - 1)
        let deletionFrameBudget = max(1, transitionFrameBudget / 2)
        let insertionFrameBudget = max(1, transitionFrameBudget - deletionFrameBudget)

        for remainingCount in sampledDeletionCounts(from: originalMiddle.count, maximumSteps: deletionFrameBudget) {
            let removedText = String(originalMiddle.prefix(remainingCount))
            frames.append(
                Frame(segments: [
                    Segment(text: prefix, kind: .unchanged),
                    Segment(text: removedText, kind: .removed),
                    Segment(text: suffix, kind: .unchanged)
                ])
            )
        }

        for visibleCount in sampledInsertionCounts(to: polishedMiddle.count, maximumSteps: insertionFrameBudget) {
            let addedText = String(polishedMiddle.prefix(visibleCount))
            frames.append(
                Frame(segments: [
                    Segment(text: prefix, kind: .unchanged),
                    Segment(text: addedText, kind: .added),
                    Segment(text: suffix, kind: .unchanged)
                ])
            )
        }

        let finalFrame = Frame(segments: [Segment(text: polished, kind: .unchanged)])
        if frames.last?.plainText != polished {
            frames.append(finalFrame)
        } else if frames.last?.segments.contains(where: { $0.kind != .unchanged }) == true {
            frames.append(finalFrame)
        }

        return frames.removingConsecutiveDuplicates()
    }

    private static func commonPrefixCount(_ left: [Character], _ right: [Character]) -> Int {
        let limit = min(left.count, right.count)
        var count = 0

        while count < limit, left[count] == right[count] {
            count += 1
        }

        return count
    }

    private static func commonSuffixCount(
        _ left: [Character],
        _ right: [Character],
        excludingPrefixCount prefixCount: Int
    ) -> Int {
        let limit = min(left.count, right.count) - prefixCount
        var count = 0

        while count < limit,
              left[left.count - count - 1] == right[right.count - count - 1] {
            count += 1
        }

        return count
    }

    private static func expandChangeRangeToWordBoundaries(
        originalCharacters: [Character],
        polishedCharacters: [Character],
        prefixCount: inout Int,
        suffixCount: inout Int
    ) {
        while prefixCount > 0,
              prefixCount < originalCharacters.count - suffixCount,
              prefixCount < polishedCharacters.count - suffixCount,
              !originalCharacters[prefixCount - 1].isWhitespace,
              !polishedCharacters[prefixCount - 1].isWhitespace {
            prefixCount -= 1
        }

        while suffixCount > 0 {
            let originalSuffixStart = originalCharacters.count - suffixCount
            let polishedSuffixStart = polishedCharacters.count - suffixCount
            let originalStartsAtBoundary = originalSuffixStart == 0
                || originalCharacters[originalSuffixStart - 1].isWhitespace
            let polishedStartsAtBoundary = polishedSuffixStart == 0
                || polishedCharacters[polishedSuffixStart - 1].isWhitespace

            guard originalSuffixStart > prefixCount,
                  polishedSuffixStart > prefixCount,
                  (!originalStartsAtBoundary || !polishedStartsAtBoundary) else {
                break
            }

            suffixCount -= 1
        }
    }

    private static func sampledDeletionCounts(from count: Int, maximumSteps: Int) -> [Int] {
        guard count > 0 else { return [] }

        let stepCount = min(count, maximumSteps)
        return (1...stepCount).map { step in
            max(0, count - Int(ceil(Double(step * count) / Double(stepCount))))
        }.removingConsecutiveDuplicates()
    }

    private static func sampledInsertionCounts(to count: Int, maximumSteps: Int) -> [Int] {
        guard count > 0 else { return [] }

        let stepCount = min(count, maximumSteps)
        return (1...stepCount).map { step in
            min(count, Int(ceil(Double(step * count) / Double(stepCount))))
        }.removingConsecutiveDuplicates()
    }
}

private extension Array where Element: Equatable {
    func removingConsecutiveDuplicates() -> [Element] {
        var result: [Element] = []

        for element in self where result.last != element {
            result.append(element)
        }

        return result
    }
}
