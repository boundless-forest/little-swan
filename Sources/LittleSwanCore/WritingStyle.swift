import Foundation

public enum WritingStyle: String, CaseIterable, Codable, Identifiable, Sendable {
    case spoken
    case formal

    public var id: String { rawValue }

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let value = try container.decode(String.self)

        switch value {
        case Self.spoken.rawValue, "natural", "polite", "casual":
            self = .spoken
        case Self.formal.rawValue, "professional", "concise":
            self = .formal
        default:
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Unknown writing style: \(value)"
            )
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }

    public var label: String {
        switch self {
        case .spoken:
            "Spoken"
        case .formal:
            "Formal"
        }
    }

    public var instruction: String {
        switch self {
        case .spoken:
            """
            Style: Spoken English.
            Use natural, conversational English suitable for everyday speech, chat, comments, and informal collaboration.
            Prefer familiar vocabulary, idiomatic phrasing, contractions, and sentence rhythms that a native speaker would comfortably say aloud.
            Preserve the source's seriousness and boundaries. Do not invent slang, jokes, emojis, enthusiasm, or familiarity that is absent from the source.
            Keep the message clear and complete rather than making it artificially casual, abrupt, or simplified.
            """
        case .formal:
            """
            Style: Formal English.
            Use clear, composed, professional English suitable for workplace communication, email, documentation, GitHub issues, and support conversations.
            Prefer precise vocabulary, complete sentences, active voice, and a logical flow while keeping necessary technical terminology intact.
            Preserve the source's level of politeness and commitment. Do not add greetings, sign-offs, apologies, gratitude, action items, or promises that are absent from the source.
            Avoid slang, casual phrasing, corporate jargon, inflated vocabulary, ceremonial language, and unnecessary wordiness.
            """
        }
    }
}
