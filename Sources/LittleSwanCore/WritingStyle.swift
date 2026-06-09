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
            "Style: Natural. Write smooth, everyday English that sounds like something a native speaker would actually say. Keep the user's tone, emphasis, and level of detail."
        case .polite:
            "Style: Polite. Use warm, respectful wording for requests, replies, and support conversations. Keep it clear and avoid sounding stiff or wordy."
        case .casual:
            "Style: Casual. Use relaxed, friendly wording for forums, comments, and chat. Keep it easy to understand and avoid heavy slang."
        case .professional:
            "Style: Professional. Use clear, calm workplace English for email, GitHub issues, support tickets, and product discussions. Prefer plain words over formal jargon."
        case .concise:
            "Style: Concise. Keep the key meaning, remove extra wording, and make the result short without sounding abrupt or losing important context."
        }
    }
}
