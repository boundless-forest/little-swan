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
            "Style: Natural. Write fluent, idiomatic English that sounds native and preserves the user's tone, emphasis, and level of detail."
        case .polite:
            "Style: Polite. Use respectful, considerate wording suitable for requests, replies, and support conversations without becoming overly formal or wordy."
        case .casual:
            "Style: Casual. Use relaxed, friendly wording suitable for forums, comments, and chat while keeping the message clear and not overly slangy."
        case .professional:
            "Style: Professional. Use precise, calm, workplace-ready English suitable for email, GitHub issues, support tickets, and product discussions."
        case .concise:
            "Style: Concise. Keep all essential meaning, remove unnecessary wording, and make the result compact without sounding abrupt or losing important context."
        }
    }
}
