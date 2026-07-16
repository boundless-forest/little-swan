import CoreGraphics
import Foundation

public struct ScreenContext: Codable, Equatable, Sendable {
    public var sourceApp: String
    public var windowTitle: String?
    public var recognizedText: String
    public var capturedAt: Date
    public var observationCount: Int

    public init(
        sourceApp: String,
        windowTitle: String? = nil,
        recognizedText: String,
        capturedAt: Date = Date(),
        observationCount: Int
    ) {
        self.sourceApp = sourceApp
        self.windowTitle = windowTitle
        self.recognizedText = recognizedText
        self.capturedAt = capturedAt
        self.observationCount = observationCount
    }

    public var displayTitle: String {
        guard let windowTitle = windowTitle?.trimmingCharacters(in: .whitespacesAndNewlines),
              !windowTitle.isEmpty else {
            return sourceApp
        }
        return "\(sourceApp) — \(windowTitle)"
    }
}

public struct ScreenTextObservation: Sendable {
    public var text: String
    public var confidence: Float
    public var boundingBox: CGRect

    public init(text: String, confidence: Float, boundingBox: CGRect) {
        self.text = text
        self.confidence = confidence
        self.boundingBox = boundingBox
    }
}

public enum ScreenContextReducer {
    public static let maximumContextLength = 12_000
    public static let minimumConfidence: Float = 0.35

    public static func makeContext(
        sourceApp: String,
        windowTitle: String?,
        observations: [ScreenTextObservation],
        sourceText: String,
        capturedAt: Date = Date()
    ) -> ScreenContext? {
        let sourceTerms = relevantTerms(in: sourceText)
        var seen = Set<String>()

        let candidates = observations.enumerated().compactMap { index, observation -> Candidate? in
            let text = normalizedLine(observation.text)
            guard observation.confidence >= minimumConfidence, !text.isEmpty else { return nil }

            let deduplicationKey = text.lowercased()
            guard seen.insert(deduplicationKey).inserted else { return nil }

            return Candidate(
                text: text,
                boundingBox: observation.boundingBox,
                sourceOrder: index,
                score: relevanceScore(
                    text: text,
                    confidence: observation.confidence,
                    boundingBox: observation.boundingBox,
                    sourceTerms: sourceTerms
                )
            )
        }

        guard !candidates.isEmpty else { return nil }

        var selected: [Candidate] = []
        var selectedLength = 0
        for candidate in candidates.sorted(by: candidatePriority) {
            let additionalLength = candidate.text.count + (selected.isEmpty ? 0 : 1)
            guard selectedLength + additionalLength <= maximumContextLength else { continue }
            selected.append(candidate)
            selectedLength += additionalLength
        }

        let recognizedText = selected
            .sorted(by: readingOrder)
            .map(\.text)
            .joined(separator: "\n")

        guard !recognizedText.isEmpty else { return nil }
        return ScreenContext(
            sourceApp: sourceApp,
            windowTitle: windowTitle,
            recognizedText: recognizedText,
            capturedAt: capturedAt,
            observationCount: candidates.count
        )
    }

    private struct Candidate {
        var text: String
        var boundingBox: CGRect
        var sourceOrder: Int
        var score: Double
    }

    private static func candidatePriority(_ left: Candidate, _ right: Candidate) -> Bool {
        if left.score != right.score { return left.score > right.score }
        return readingOrder(left, right)
    }

    /// Vision uses a lower-left origin, so larger Y values appear earlier on screen.
    private static func readingOrder(_ left: Candidate, _ right: Candidate) -> Bool {
        let verticalTolerance: CGFloat = 0.012
        if abs(left.boundingBox.midY - right.boundingBox.midY) > verticalTolerance {
            return left.boundingBox.midY > right.boundingBox.midY
        }
        if left.boundingBox.minX != right.boundingBox.minX {
            return left.boundingBox.minX < right.boundingBox.minX
        }
        return left.sourceOrder < right.sourceOrder
    }

    private static func relevanceScore(
        text: String,
        confidence: Float,
        boundingBox: CGRect,
        sourceTerms: Set<String>
    ) -> Double {
        let normalized = text.lowercased()
        let termMatches = sourceTerms.reduce(into: 0) { count, term in
            if normalized.contains(term) { count += 1 }
        }
        let centerDistance = hypot(boundingBox.midX - 0.5, boundingBox.midY - 0.5)
        let centerScore = max(0, 1 - Double(centerDistance / 0.71)) * 25
        let lengthScore = min(Double(text.count), 120) / 4
        let chromePenalty = boundingBox.maxY > 0.94 ? 25.0 : 0

        return Double(confidence) * 30
            + centerScore
            + lengthScore
            + Double(termMatches) * 80
            - chromePenalty
    }

    private static func relevantTerms(in text: String) -> Set<String> {
        Set(
            text.lowercased()
                .split { character in
                    !(character.isLetter || character.isNumber || character == "_")
                }
                .map(String.init)
                .filter { $0.count >= 3 }
        )
    }

    private static func normalizedLine(_ text: String) -> String {
        text
            .split(whereSeparator: \.isWhitespace)
            .joined(separator: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
