import Foundation

public enum SourceCompletionDefaults {
    public static let debounceMilliseconds = 250
    public static let model = "deepseek-v4-pro"
    public static let betaCompletionsPath = "beta/completions"
    public static let maxTokens = 4
    public static let temperature = 0.25
    public static let stop = ["\n\n"]
    public static let displayedWordLimit = 1
    public static let minimumContextUTF16Length = 8
    public static let maximumDisplayedUTF16Length = 18
    public static let maximumDisplayedCJKScalars = 2
}

public struct FIMCompletionRequest: Encodable, Equatable, Sendable {
    public var model: String
    public var prompt: String
    public var suffix: String?
    public var maxTokens: Int
    public var temperature: Double
    public var stream: Bool
    public var stop: [String]

    public init(
        model: String,
        prompt: String,
        suffix: String? = nil,
        maxTokens: Int = SourceCompletionDefaults.maxTokens,
        temperature: Double = SourceCompletionDefaults.temperature,
        stream: Bool = false,
        stop: [String] = SourceCompletionDefaults.stop
    ) {
        self.model = model
        self.prompt = prompt
        self.suffix = suffix
        self.maxTokens = maxTokens
        self.temperature = temperature
        self.stream = stream
        self.stop = stop
    }

    private enum CodingKeys: String, CodingKey {
        case model
        case prompt
        case suffix
        case maxTokens = "max_tokens"
        case temperature
        case stream
        case stop
    }
}

public enum SourceCompletionInsertion {
    public static func insert(
        suggestion: String,
        into text: String,
        utf16Location: Int
    ) -> (text: String, newUTF16Location: Int) {
        let nsText = text as NSString
        let clampedLocation = min(max(utf16Location, 0), nsText.length)
        let nextText = nsText.replacingCharacters(
            in: NSRange(location: clampedLocation, length: 0),
            with: suggestion
        )
        let newLocation = clampedLocation + (suggestion as NSString).length
        return (nextText, newLocation)
    }

    public static func split(
        text: String,
        utf16Location: Int
    ) -> (prefix: String, suffix: String) {
        let nsText = text as NSString
        let clampedLocation = min(max(utf16Location, 0), nsText.length)
        return (
            nsText.substring(to: clampedLocation),
            nsText.substring(from: clampedLocation)
        )
    }
}

public enum SourceCompletionSanitizer {
    public static func sanitize(_ rawSuggestion: String, maxUTF16Length: Int) -> String {
        let trimmedTrailing = rawSuggestion.trimmingTrailingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTrailing.isEmpty else { return "" }
        guard trimmedTrailing.rangeOfCharacter(from: .newlines) == nil else { return "" }
        guard !trimmedTrailing.containsSentenceEndingPunctuation else { return "" }

        let leadingWhitespace = trimmedTrailing.leadingWhitespacePrefix
        let body = String(trimmedTrailing.dropFirst(leadingWhitespace.count))
        guard !body.isEmpty else { return "" }
        guard !body.startsWithOpenEndedConnector else { return "" }

        let limitedBody = body.conservativeCompletionPrefix(
            maximumWordCount: SourceCompletionDefaults.displayedWordLimit,
            maximumCJKScalars: SourceCompletionDefaults.maximumDisplayedCJKScalars
        )
        let wordLimited = leadingWhitespace + limitedBody

        guard !limitedBody.isEmpty else { return "" }
        guard maxUTF16Length >= 0 else { return wordLimited }

        let effectiveLimit = min(maxUTF16Length, SourceCompletionDefaults.maximumDisplayedUTF16Length)
        let nsSuggestion = wordLimited as NSString
        guard nsSuggestion.length > effectiveLimit else { return wordLimited }

        return nsSuggestion.substring(to: effectiveLimit)
            .trimmingTrailingCharacters(in: .whitespacesAndNewlines)
    }
}

public enum SourceCompletionEligibility {
    public static func shouldRequest(prefix: String, suffix: String) -> Bool {
        guard !prefix.isEmpty || !suffix.isEmpty else { return false }

        let currentLinePrefix = prefix.currentLineFragment
        let currentLineSuffix = suffix.currentLineFragment

        if !currentLineSuffix.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return true
        }

        let trimmedPrefix = currentLinePrefix.trimmingCharacters(in: .whitespacesAndNewlines)
        guard (trimmedPrefix as NSString).length >= SourceCompletionDefaults.minimumContextUTF16Length else {
            return false
        }
        guard !trimmedPrefix.hasTerminalSentencePunctuation else { return false }

        return true
    }
}

public enum SourceCompletionAcceptance {
    public static func acceptedPrefix(from suggestion: String) -> String {
        suggestion
    }
}

private extension String {
    func trimmingTrailingCharacters(in characterSet: CharacterSet) -> String {
        var scalars = unicodeScalars
        while let last = scalars.last, characterSet.contains(last) {
            scalars.removeLast()
        }
        return String(scalars)
    }

    var leadingWhitespacePrefix: String {
        var prefix = ""
        for character in self {
            guard character.unicodeScalars.allSatisfy({ CharacterSet.whitespacesAndNewlines.contains($0) }) else {
                break
            }
            prefix.append(character)
        }
        return prefix
    }

    var currentLineFragment: String {
        if let newline = lastIndex(where: { $0 == "\n" || $0 == "\r" }) {
            return String(self[index(after: newline)...])
        }
        return self
    }

    var hasTerminalSentencePunctuation: Bool {
        guard let last = trimmingCharacters(in: .whitespacesAndNewlines).last else { return false }
        return ".!?。！？…".contains(last)
    }

    var containsSentenceEndingPunctuation: Bool {
        contains { ".!?。！？…".contains($0) }
    }

    var startsWithOpenEndedConnector: Bool {
        let lowercasedBody = trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let openEndedConnectors = [
            "and ", "but ", "or ", "so ", "because ", "while ", "although ", "however ",
            "then ", "also ", "plus ", "which ", "that ", "who ", "where ", "when ",
            "what ", "why ", "how "
        ]
        return openEndedConnectors.contains { lowercasedBody.hasPrefix($0) }
    }

    func conservativeCompletionPrefix(maximumWordCount: Int, maximumCJKScalars: Int) -> String {
        guard maximumWordCount > 0 else { return "" }
        if containsCJKScalar {
            return prefixByCJKScalarCount(maximumCJKScalars)
        }
        return prefixByWordCount(maximumWordCount)
    }

    var containsCJKScalar: Bool {
        unicodeScalars.contains { scalar in
            switch scalar.value {
            case 0x3400...0x4DBF, 0x4E00...0x9FFF, 0xF900...0xFAFF,
                 0x3040...0x309F, 0x30A0...0x30FF, 0xAC00...0xD7AF:
                return true
            default:
                return false
            }
        }
    }

    func prefixByCJKScalarCount(_ maximumScalars: Int) -> String {
        guard maximumScalars > 0 else { return "" }
        var result = ""
        var scalarsSeen = 0

        for scalar in unicodeScalars {
            guard !CharacterSet.whitespacesAndNewlines.contains(scalar) else { break }
            scalarsSeen += 1
            guard scalarsSeen <= maximumScalars else { break }
            result.unicodeScalars.append(scalar)
        }

        return result
    }

    func prefixByWordCount(_ maximumWordCount: Int) -> String {
        guard maximumWordCount > 0 else { return "" }

        var wordsSeen = 0
        var isInsideWord = false
        var lastIncludedWordEnd = startIndex
        var cursor = startIndex

        while cursor < endIndex {
            let character = self[cursor]
            let characterEnd = index(after: cursor)
            let isWhitespace = character.unicodeScalars.allSatisfy {
                CharacterSet.whitespacesAndNewlines.contains($0)
            }

            if isWhitespace {
                isInsideWord = false
            } else {
                if !isInsideWord {
                    wordsSeen += 1
                    guard wordsSeen <= maximumWordCount else { break }
                    isInsideWord = true
                }
                lastIncludedWordEnd = characterEnd
            }

            cursor = characterEnd
        }

        guard lastIncludedWordEnd > startIndex else { return "" }
        return String(self[..<lastIncludedWordEnd])
    }
}
