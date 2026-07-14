import Foundation

public enum WritingStyle: String, CaseIterable, Codable, Identifiable, Sendable {
    case natural
    case polite
    case casual
    case professional
    case concise

    public var id: String { rawValue }

    public var label: String {
        switch self {
        case .natural:
            "Natural"
        case .polite:
            "Polite"
        case .casual:
            "Casual"
        case .professional:
            "Professional"
        case .concise:
            "Concise"
        }
    }

    public var instruction: String {
        switch self {
        case .natural:
            """
            Style: Natural.
            Use smooth, idiomatic everyday English that a native speaker would naturally choose in the same context.
            Restructure source-language word order and literal phrasing when needed, while preserving the original tone, emphasis, emotion, and level of detail.
            Use contractions when they fit the context, but do not make formal or serious content artificially casual.
            Avoid stiff translation patterns, unnecessary formality, embellishment, and wording that sounds more polished or expressive than the source.
            """
        case .polite:
            """
            Style: Polite.
            Use warm, respectful, considerate English suitable for requests, replies, and support conversations.
            Soften requests with wording such as "could," "would," or "please" only when appropriate, without weakening requirements or changing the speaker's position.
            Keep the message clear and direct. Do not add greetings, sign-offs, honorifics, apologies, gratitude, or friendliness that is absent from the source.
            Avoid stiff, ceremonial, overly deferential, or needlessly wordy language.
            """
        case .casual:
            """
            Style: Casual.
            Use relaxed, friendly, conversational English suitable for chat, comments, forums, and informal collaboration.
            Prefer natural contractions, straightforward vocabulary, and shorter conversational sentences while preserving the source's meaning and seriousness.
            Preserve humor and emotion when present, but do not invent jokes, slang, emojis, exclamation marks, or internet abbreviations.
            Avoid sounding careless, childish, overly familiar, or insensitive when the subject is serious.
            """
        case .professional:
            """
            Style: Professional.
            Use clear, calm, precise workplace English suitable for email, GitHub issues, support tickets, and product discussions.
            Prefer direct sentences, active voice, logical flow, and explicit actions, ownership, timing, conditions, and risks when they exist in the source.
            Preserve necessary technical terminology, but prefer plain language over corporate jargon, inflated vocabulary, and bureaucratic phrasing.
            Do not add email subjects, greetings, sign-offs, headings, action items, or commitments that are absent from the source.
            """
        case .concise:
            """
            Style: Concise.
            Express the complete message with the fewest natural words by removing repetition, filler, and modifiers that do not change the meaning.
            Combine sentences only when doing so keeps the logic and emphasis clear.
            Always preserve names, numbers, negation, conditions, deadlines, responsibilities, decisions, uncertainty, and other information that affects meaning.
            Keep questions as questions and preserve the source's necessary politeness. Do not create fragments, sound abrupt, or omit context merely to make the output shorter.
            """
        }
    }
}
